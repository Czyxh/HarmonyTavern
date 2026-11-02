import { ActionButtonStyle, ActionTone, InputFieldStyle } from '../theme/ControlStyles';
import { HeaderAction } from '../components/HeaderAction';
import { OriginMotion } from '../theme/OriginMotion';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { PageSurface } from '../components/PageSurface';
import { PageHeader } from '../components/PageHeader';
import { Radius as UIRadius, Typography as UIType } from '../theme/Tokens';
// P7 步骤 7 ⑦：扩展管理页。
//
// 背景：P6.2 已移植全部扩展命令（get_extensions / install_extension / update_extension /
// delete_extension / get_extension_version / get_extension_branches / switch_extension_branch），
// 但一直没有 UI 入口，真机验收只能靠 hdc 直调 —— 本页补上最小可用闭环：
//   1. 顶部 URL 输入 + 「安装」→ install_extension（git clone，需网络）；
//   2. 列表 get_extensions（名称 + System/Local/Global 类型）；
//   3. 每行「版本」→ get_extension_version（分支/commit/是否最新）、「更新」→ update_extension、
//      「删除」→ 确认弹窗 → delete_extension。
//
// 扩展的启用/停用属于 settings.extension_settings（Webview 侧语义），不在本页范围。
// 对应 DevEco 工程路径：entry/src/main/ets/pages/ExtensionPage.ets
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Backend, BackendError } from '../backend/Backend';
import { ROOT_PATH_STACK } from '../nav/RootNav';
import { GLASS_CARD, glassEffect } from '../theme/Glass';
import {
  Extension,
  ExtensionInstallResult,
  ExtensionUpdateResult,
  ExtensionVersion
} from '../backend/Types';

const DOMAIN: number = 0x0002;
const TAG: string = 'HarmonyTavern';

/** 列表行（只保留展示需要的字段）。 */
interface ExtensionRow {
  name: string;
  type: string;
}

@Component
export struct ExtensionPage {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @State rows: ExtensionRow[] = [];
  @State listText: string = '加载中…';
  @State urlInput: string = '';
  @State statusText: string = '';
  @State errorText: string = '';
  /** 安装/更新/删除进行中：防重入（同一时刻只允许一个会改磁盘的操作）。 */
  @State busy: boolean = false;

  aboutToAppear(): void {
    if (!Backend.isReady()) {
      this.statusText = '后端未就绪，跳回首页初始化…';
      ROOT_PATH_STACK.pop();
      return;
    }
    this.refresh();
  }

  async refresh(): Promise<void> {
    try {
      const list: Extension[] = await Backend.getExtensions();
      const rows: ExtensionRow[] = [];
      for (let i = 0; i < list.length; i++) {
        const item: Extension = list[i];
        rows.push({ name: item.name, type: item.extension_type });
      }
      this.rows = rows;
      this.listText = `共 ${rows.length} 个扩展`;
    } catch (err) {
      const message: string = (err as BackendError).message;
      this.listText = `加载失败：${message}`;
      hilog.error(DOMAIN, TAG, 'get_extensions failed: %{public}s', message);
    }
  }

  /** 安装：git clone 到全局扩展目录（需网络；失败原样上屏）。 */
  async install(): Promise<void> {
    const url: string = this.urlInput.trim();
    if (url === '') {
      this.statusText = '请先填写扩展仓库 URL';
      return;
    }
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.errorText = '';
    this.statusText = '安装中…（git clone，可能需要几十秒）';
    try {
      const result: ExtensionInstallResult = await Backend.installExtension(url, true);
      this.statusText =
        `已安装：${result.display_name} v${result.version}（${result.folder_name}）`;
      this.urlInput = '';
      await this.refresh();
    } catch (err) {
      const message: string = (err as BackendError).message;
      this.statusText = '';
      this.errorText = `安装失败：${message}`;
      hilog.error(DOMAIN, TAG, 'install_extension failed: %{public}s', message);
    } finally {
      this.busy = false;
    }
  }

  /** 版本：读当前分支/commit/是否最新。 */
  async showVersion(name: string): Promise<void> {
    try {
      const version: ExtensionVersion = await Backend.getExtensionVersion(name, true);
      this.statusText =
        `${name}：分支 ${version.current_branch_name} @ ${version.current_commit_hash}` +
        `${version.is_up_to_date ? '（已是最新）' : '（有更新）'}`;
    } catch (err) {
      this.errorText = `读取版本失败：${(err as BackendError).message}`;
    }
  }

  async update(name: string): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.errorText = '';
    this.statusText = `更新 ${name} 中…`;
    try {
      const result: ExtensionUpdateResult = await Backend.updateExtension(name, true);
      this.statusText = result.is_up_to_date
        ? `${name} 已是最新（${result.short_commit_hash}）`
        : `${name} 已更新到 ${result.short_commit_hash}`;
      await this.refresh();
    } catch (err) {
      const message: string = (err as BackendError).message;
      this.statusText = '';
      this.errorText = `更新失败：${message}`;
      hilog.error(DOMAIN, TAG, 'update_extension failed: %{public}s', message);
    } finally {
      this.busy = false;
    }
  }

  /** 删除：先弹确认（不可撤销）。 */
  private confirmDelete(name: string): Promise<boolean> {
    return new Promise<boolean>((resolve: (value: boolean) => void) => {
      this.getUIContext().showAlertDialog({
        title: '删除扩展',
        alignment: DialogAlignment.Center,
        transition: OriginMotion.dialog(this.getUIContext(), 'extension-delete-' + name),
        message: `确定删除扩展「${name}」？\n磁盘上的扩展目录会被移除，不可撤销。`,
        primaryButton: {
          value: '删除',
          action: () => { resolve(true); }
        },
        secondaryButton: {
          value: '取消',
          action: () => { resolve(false); }
        }
      });
    });
  }

  async remove(name: string): Promise<void> {
    if (this.busy) {
      return;
    }
    const confirmed: boolean = await this.confirmDelete(name);
    if (!confirmed) {
      this.statusText = '已取消删除';
      return;
    }
    this.busy = true;
    this.errorText = '';
    this.statusText = `删除 ${name} 中…`;
    try {
      await Backend.deleteExtension(name, true);
      this.statusText = `已删除：${name}`;
      await this.refresh();
    } catch (err) {
      const message: string = (err as BackendError).message;
      this.statusText = '';
      this.errorText = `删除失败：${message}`;
      hilog.error(DOMAIN, TAG, 'delete_extension failed: %{public}s', message);
    } finally {
      this.busy = false;
    }
  }

  @Builder
  pageTopBar() {
    PageHeader({ title: '扩展', subtitle: '为你的酒馆增添可能', onBack: () => ROOT_PATH_STACK.pop() })
  }

  @Builder
  buildSurfaceContent() {
      Column({ space: 8 }) {
        
  
        Text('安装扩展（git 仓库 URL，装到全局扩展目录）')
          .fontSize(UIType.caption)
          .opacity(0.8)
        Row({ space: 6 }) {
          TextInput({ placeholder: 'https://github.com/<owner>/<repo>', text: this.urlInput })
            .fontColor(this.uiColors.textPrimary)
            .placeholderColor(this.uiColors.textTertiary)
            .backgroundColor(this.uiColors.bgSurfaceHigh)
            .borderRadius(UIRadius.sm)
            .fontSize(UIType.caption)
            .layoutWeight(1)
            .onChange((value: string) => {
              this.urlInput = value;
            })
          .attributeModifier(new InputFieldStyle(this.uiColors))
      Button('安装', { type: ButtonType.Normal })
            .fontSize(UIType.caption)
            .constraintSize({ minHeight: 44 })
            .enabled(!this.busy)
            .onClick(() => {
              this.install();
            })
          .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      HeaderAction({ label: '刷新', marker: 'extensionpage-refresh-1', available: !this.busy,
          onAction: async (): Promise<void> => { await this.refresh(); } })
        }
        .width('100%')
  
        Text(this.listText)
          .fontSize(UIType.caption)
          .opacity(0.8)
  
        Column({ space: 6 }) {
          ForEach(this.rows, (row: ExtensionRow) => {
            Column() {
              Column({ space: 4 }) {
                Row({ space: 8 }) {
                  Text(`${row.name}（${row.type}）`)
                    .fontSize(UIType.caption)
                    .fontWeight(FontWeight.Medium)
                    .layoutWeight(1)
                  // System 扩展是随应用内置的（不在 extensions/third-party 下），
                  // git 版本/更新/删除对它不适用，直接禁用避免无意义报错。
                  Button('版本', { type: ButtonType.Normal })
                    .fontSize(UIType.micro)
                    .constraintSize({ minHeight: 44 })
                    .enabled(row.type !== 'System')
                    .onClick(() => {
                      this.showVersion(row.name);
                    })
                  .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button('更新', { type: ButtonType.Normal })
                    .fontSize(UIType.micro)
                    .constraintSize({ minHeight: 44 })
                    .enabled(!this.busy && row.type !== 'System')
                    .onClick(() => {
                      this.update(row.name);
                    })
                  .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button('删除', { type: ButtonType.Normal })
                    .fontSize(UIType.micro)
                    .constraintSize({ minHeight: 44 })
                    .enabled(!this.busy && row.type !== 'System')
                    .id('extension-delete-' + row.name)
                    .onClick(() => {
                      this.remove(row.name);
                    })
                .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Danger))
      }
                .width('100%')
              }
              .width('100%')
              .padding(8)
              .backgroundColor(this.uiColors.bgSurface)
              .border({ width: 1, color: this.uiColors.borderSubtle })
              .borderRadius(UIRadius.sm)
            }
          }, (row: ExtensionRow) => row.name)
        }
        .width('100%')
  
        Text(this.statusText)
          .fontSize(UIType.caption)
          .opacity(0.85)
          .textAlign(TextAlign.Center)
        Text(this.errorText)
          .fontSize(UIType.caption)
          .fontColor(this.uiColors.danger)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
    }

  build() {
    PageSurface({ topBar: () => { this.pageTopBar(); }, content: () => { this.buildSurfaceContent(); } })
  }
}
