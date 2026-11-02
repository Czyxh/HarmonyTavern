import { SurfaceStyle } from '../theme/SurfaceStyles';
import { iconTint } from '../theme/IconTint';
import { ActionButtonStyle, ActionTone, TextAreaFieldStyle } from '../theme/ControlStyles';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { PageSurface } from '../components/PageSurface';
import { PageHeader } from '../components/PageHeader';
import { Radius as UIRadius, Typography as UIType } from '../theme/Tokens';
// 导入世界书（独立页面）。
//
// 对应 DevEco 工程路径：entry/src/main/ets/pages/WorldImportPage.ets
//
// 和「导入角色卡」分开的理由：
//   角色卡是 PNG 里的 tEXt 块（也可能纯 JSON），走 `import_character`；
//   世界书是另一个仓库对象（worlds/*.json），走 `import_world_info`。
//   把两者塞进同一页时，用户根本分不清"我现在导入的是哪一种"，
//   而且卡片的"替换来源 / 导入会话"跟世界书毫无关系。
//
// 命令契约（native/crates/ttavern/src/presentation/commands/world_info.rs:170）：
//   import_world_info { filePath?: string, originalFilename: string, convertedData?: string } -> 世界书名
// 注意：`filePath` 必须是**沙箱真实路径**，picker 的 URI 核心打不开。
//
// 对应 DevEco 工程路径：entry/src/main/ets/pages/WorldImportPage.ets
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Backend, BackendError } from '../backend/Backend';
import { LibraryEditIntent, ROOT_PATH_STACK } from '../nav/RootNav';
import { Radius, Spacing, Touch, Typography } from '../theme/Tokens';
import { copyToSandbox, fileNameOf, pickDocument, writeTextToSandbox } from '../utils/ImportFiles';
import { staggeredEntrance } from '../theme/Motion';

const DOMAIN: number = 0x0009;
const TAG: string = 'HarmonyTavern';

@Component
export struct WorldImportPage {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  /** 嵌入「管理」页时置 true：隐藏本页的返回头部，由外层统一承载 */
  @Prop embedded: boolean = false;
  @Prop showLibraryList: boolean = true;
  onImported: (name: string) => void = (): void => {};
  @Prop contentBottom: number = 24;
  @State worlds: string[] = [];
  @State pastedJson: string = '';
  @State statusText: string = '';
  @State errorText: string = '';
  @State busy: boolean = false;
  @State lastImportedName: string = '';

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  aboutToAppear(): void {
    this.reload();
  }

  async reload(): Promise<void> {
    try {
      this.worlds = await Backend.listWorldInfos();
    } catch (err) {
      this.errorText = `读取世界书列表失败：${(err as BackendError).message}`;
    }
  }

  /** 从文件选 .json 世界书。 */
  async importFromFile(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.errorText = '';
    this.statusText = '';
    try {
      const uri: string = await pickDocument(this.context(), ['世界书|.json', '全部|.*']);
      if (uri === '') {
        return;
      }
      const original: string = fileNameOf(uri, `world_${Date.now()}.json`);
      const path: string = copyToSandbox(this.context(), uri, original);
      const name: string = await Backend.importWorldInfo(original, path);
      this.statusText = `已导入世界书：${name}`;
      this.lastImportedName = name;
      this.onImported(name);
      await this.reload();
    } catch (err) {
      const message: string = (err as BackendError).message;
      this.errorText = `导入世界书失败：${message}`;
      hilog.error(DOMAIN, TAG, 'import world info failed: %{public}s', message);
    } finally {
      this.busy = false;
    }
  }

  /** 粘贴 JSON 导入：先本地 JSON.parse 预检，避免把坏 JSON 交给核心。 */
  async importPasted(): Promise<void> {
    if (this.busy) {
      return;
    }
    const text: string = this.pastedJson.trim();
    if (text === '') {
      this.errorText = '先粘贴世界书 JSON';
      return;
    }
    try {
      JSON.parse(text);
    } catch (err) {
      this.errorText = `JSON 解析失败：${(err as Error).message}`;
      return;
    }
    this.busy = true;
    this.errorText = '';
    this.statusText = '';
    try {
      const name: string = await Backend.importWorldInfo('pasted_world.json', '', text);
      this.statusText = `已导入世界书：${name}`;
      this.lastImportedName = name;
      this.pastedJson = '';
      this.onImported(name);
      await this.reload();
    } catch (err) {
      this.errorText = `导入失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  @Builder
  header() {
    PageHeader({ title: '导入世界书', subtitle: '把收藏带进新的故事', onBack: () => ROOT_PATH_STACK.pop() })
  }

  @Builder
  pageBody() {
    Column() {
      

      Column() {
        Column({ space: Spacing.md }) {
          Text('世界书（lorebook）是独立的设定集，和角色卡分开存储。'
            + '支持 SillyTavern 导出的 worlds/*.json，也可以直接粘贴 JSON。')
            .fontSize(Typography.caption)
            .fontColor(this.uiColors.textTertiary)
            .width('100%')

          Button('从文件选 JSON', { type: ButtonType.Normal })
            .fontSize(Typography.body)
            .height(Touch.minTarget)
            .width('100%')
            .backgroundColor(this.uiColors.accent)
            .fontColor(this.uiColors.textInverse)
            .enabled(!this.busy)
            .onClick(() => {
              this.importFromFile();
            })

          .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Column({ space: Spacing.sm }) {
            Text('粘贴 JSON')
              .fontSize(Typography.body)
              .fontColor(this.uiColors.textPrimary)
              .width('100%')
            TextArea({ text: this.pastedJson, placeholder: '{"entries":{"0":{...}}}' })
              .fontColor(this.uiColors.textPrimary)
              .placeholderColor(this.uiColors.textTertiary)
              .backgroundColor(this.uiColors.bgSurfaceHigh)
              .borderRadius(UIRadius.sm)
              .height(120)
              .fontSize(Typography.caption)
              .backgroundColor(this.uiColors.bgSurfaceHigh)
              .borderRadius(Radius.sm)
              .onChange((value: string) => {
                this.pastedJson = value;
              })
            .attributeModifier(new TextAreaFieldStyle(this.uiColors))
      Button('导入这段 JSON', { type: ButtonType.Normal })
              .fontSize(Typography.caption)
              .height(Touch.minTarget)
              .width('100%')
              .backgroundColor(this.uiColors.bgSurfaceHigh)
              .fontColor(this.uiColors.textPrimary)
              .enabled(!this.busy)
              .onClick(() => {
                this.importPasted();
              })
          .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(Spacing.md)
          .backgroundColor(this.uiColors.bgSurface)
          .borderRadius(Radius.md)
          .attributeModifier(new SurfaceStyle(this.uiColors, Radius.md))
          .border({ width: 1, color: this.uiColors.borderSubtle })

          if (this.statusText !== '') {
            Text(this.statusText)
              .fontSize(Typography.caption)
              .fontColor(this.uiColors.success)
              .width('100%')
          }
          if (this.lastImportedName !== '' && this.showLibraryList) {
            Button('编辑刚导入的世界书').attributeModifier(new ActionButtonStyle(this.uiColors)).width('100%')
              .id('world-import-edit').onClick((): void => { LibraryEditIntent.editWorld(this.lastImportedName); })
          }
          if (this.errorText !== '') {
            Text(this.errorText)
              .fontSize(Typography.caption)
              .fontColor(this.uiColors.danger)
              .width('100%')
          }

          if (this.showLibraryList) {
          Text('已有世界书')
            .fontSize(Typography.body)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.uiColors.textPrimary)
            .width('100%')

          ForEach(this.worlds, (name: string, index: number) => {
            Row({ space: Spacing.sm }) {
              Text(name)
                .fontSize(Typography.body)
                .fontColor(this.uiColors.textPrimary)
                .layoutWeight(1)
              Image($r('app.media.icon_chevron'))
                .width(18).height(18)
                .colorFilter(iconTint(this.uiColors.textTertiary))
            }
            .width('100%')
            .height(Touch.rowHeight)
            .padding({ left: Spacing.md, right: Spacing.md })
            .backgroundColor(this.uiColors.bgSurface)
            .borderRadius(Radius.md)
            .attributeModifier(new SurfaceStyle(this.uiColors, Radius.md))
            .border({ width: 1, color: this.uiColors.borderSubtle })
            .transition(staggeredEntrance(10, index))
            .onClick(() => {
              LibraryEditIntent.editWorld(name);
            })
          }, (name: string) => name)
          }
        }
        .width('100%')
        .padding({ left: Spacing.lg, right: Spacing.lg, bottom: this.embedded ? this.contentBottom : Spacing.xl })
      }
      .width('100%')
    }
    .width('100%')
    .backgroundColor(this.uiColors.bgBase)
  }

  @Builder
  buildSurfaceContent() {
        this.pageBody()
      }

  build() {
    if (this.embedded) {
      this.pageBody()
    } else {
      PageSurface({ topBar: () => { this.header(); }, horizontalInset: 0, content: () => { this.buildSurfaceContent(); } })
    }
  }
}
