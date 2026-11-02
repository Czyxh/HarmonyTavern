import { ActionButtonStyle, ActionTone, InputFieldStyle, TextAreaFieldStyle } from '../theme/ControlStyles';
import { HeaderAction } from '../components/HeaderAction';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { PageSurface } from '../components/PageSurface';
import { Radius as UIRadius, Typography as UIType } from '../theme/Tokens';
import { PageHeader } from '../components/PageHeader';
// Skills 技能管理（P8-7）：对应原项目 src/scripts/extensions/agent-system/SkillManager*。
//
// 原面板能力：技能列表（含 scope/标签/脚本标记）/ 文件浏览 / 文件读取与编辑保存 /
// 导出 / 删除 / 从 URL 导入（预览冲突 → 安装）。
//
// 对应 DevEco 工程路径：entry/src/main/ets/pages/SkillsPage.ets
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Backend, BackendError } from '../backend/Backend';
import {
  SkillExportPayload,
  SkillFileRef,
  SkillImportInput,
  SkillImportPreview,
  SkillIndexEntry,
  SkillInstallRequest,
  SkillInstallResult,
  SkillReadResult,
  SkillScope,
  SkillScopeFilter
} from '../backend/Types';
import { ROOT_PATH_STACK } from '../nav/RootNav';
import { Radius, Spacing, Typography } from '../theme/Tokens';
import { GLASS_CARD, GLASS_HEADER, glassEffect } from '../theme/Glass';
import { EmptyHint, ErrorBannerView, SectionTitle } from '../components/Builders';

const DOMAIN: number = 0x0004;
const TAG: string = 'HarmonyTavern';
const GLOBAL_SCOPE: SkillScope = { kind: 'global' };

@Component
export struct SkillsPage {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @State loading: boolean = true;
  @State busy: boolean = false;
  @State errorText: string = '';
  @State statusText: string = '';
  @State skills: SkillIndexEntry[] = [];
  /** 过滤：'all' | 'global' | 'builtin' */
  @State filterKind: string = 'all';

  // 展开的技能 + 文件
  @State expanded: string = '';
  @State files: SkillFileRef[] = [];
  @State filesNote: string = '';

  // 当前编辑的文件
  @State editPath: string = '';
  @State editContent: string = '';
  @State editSha: string = '';
  @State editNote: string = '';

  // 导出结果展示
  @State exportNote: string = '';

  // 删除确认
  @State deleting: string = '';

  // 导入
  @State importUrl: string = '';
  @State preview: SkillImportPreview | undefined = undefined;
  @State importInput: SkillImportInput | undefined = undefined;

  aboutToAppear(): void {
    if (!Backend.isReady()) {
      this.errorText = '后端未就绪，请从首页进入';
      this.loading = false;
      return;
    }
    this.reload();
  }

  scopeFilter(): SkillScopeFilter {
    if (this.filterKind === 'global') {
      return { kind: 'global' };
    }
    if (this.filterKind === 'builtin') {
      return { kind: 'builtin' };
    }
    return { kind: 'all' };
  }

  async reload(): Promise<void> {
    this.loading = true;
    this.errorText = '';
    try {
      this.skills = await Backend.listSkills(this.scopeFilter());
    } catch (err) {
      this.errorText = `读取技能失败：${(err as BackendError).message}`;
    } finally {
      this.loading = false;
    }
  }

  setFilter(kind: string): void {
    this.filterKind = kind;
    this.expanded = '';
    this.files = [];
    this.editPath = '';
    this.reload();
  }

  async expand(skill: SkillIndexEntry): Promise<void> {
    if (this.expanded === skill.name) {
      this.expanded = '';
      this.files = [];
      this.editPath = '';
      return;
    }
    this.expanded = skill.name;
    this.editPath = '';
    this.editContent = '';
    this.exportNote = '';
    this.filesNote = '读取文件列表…';
    this.busy = true;
    try {
      this.files = await Backend.listSkillFiles(skill.name, skill.scope);
      this.filesNote = `共 ${this.files.length} 个文件`;
    } catch (err) {
      this.files = [];
      this.filesNote = '';
      this.errorText = `读取文件列表失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async openFile(skill: SkillIndexEntry, ref: SkillFileRef): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      const result: SkillReadResult =
        await Backend.readSkillFile(skill.name, ref.path, skill.scope, 1, 400);
      this.editPath = result.path;
      this.editContent = result.content;
      this.editSha = result.sha256;
      const truncated: string = result.lineTruncated ? '（已截断，仅显示前 400 行）' : '';
      this.editNote = `${result.path} · ${result.totalLines} 行 · ${result.totalChars} 字符${truncated}`;
    } catch (err) {
      this.errorText = `读取文件失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async saveFile(skill: SkillIndexEntry): Promise<void> {
    if (this.editPath === '') {
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      const result: SkillReadResult = await Backend.writeSkillFile(
        skill.name, this.editPath, this.editContent, skill.scope, this.editSha);
      this.editSha = result.sha256;
      this.editNote = `${result.path} · 已保存 · ${result.totalLines} 行`;
      this.statusText = `已保存 ${result.path}`;
    } catch (err) {
      this.errorText = `保存失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async exportRow(skill: SkillIndexEntry): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      const payload: SkillExportPayload = await Backend.exportSkill(skill.name, skill.scope);
      const kb: number = Math.round(payload.contentBase64.length / 1024);
      this.exportNote = `导出包：${payload.fileName}（base64 约 ${kb} KB，sha256 ${payload.sha256.substring(0, 12)}…）`;
    } catch (err) {
      this.errorText = `导出失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async doDelete(skill: SkillIndexEntry): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      await Backend.deleteSkill(skill.name, skill.scope);
      this.deleting = '';
      this.expanded = '';
      this.statusText = `已删除 ${skill.name}`;
      await this.reload();
    } catch (err) {
      this.errorText = `删除失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async downloadImport(): Promise<void> {
    const url: string = this.importUrl.trim();
    if (url === '') {
      this.errorText = '先填一个技能包 URL';
      return;
    }
    this.busy = true;
    this.errorText = '';
    this.preview = undefined;
    this.importInput = undefined;
    try {
      const input: SkillImportInput = await Backend.downloadSkillImportUrl(url);
      this.importInput = input;
      const result: SkillImportPreview = await Backend.previewSkillImport(input, GLOBAL_SCOPE);
      this.preview = result;
      this.statusText = `已下载：${result.skill.name}`;
    } catch (err) {
      this.errorText = `下载/预览失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async installImport(strategy: string): Promise<void> {
    if (this.importInput === undefined) {
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      const request: SkillInstallRequest = {
        input: this.importInput,
        targetScope: GLOBAL_SCOPE,
        conflictStrategy: strategy
      };
      const result: SkillInstallResult = await Backend.installSkillImport(request);
      this.statusText = `安装完成：${result.name}（${result.action}）`;
      this.preview = undefined;
      this.importInput = undefined;
      this.importUrl = '';
      await this.reload();
    } catch (err) {
      this.errorText = `安装失败：${(err as BackendError).message}`;
      hilog.error(DOMAIN, TAG, 'skill install failed: %{public}s', this.errorText);
    } finally {
      this.busy = false;
    }
  }

  @Builder
  pageTopBar() {
    PageHeader({
        title: '技能',
        subtitle: '为助手添加更多能力',
        onBack: () => {
            ROOT_PATH_STACK.pop();
        }
      }) {
        HeaderAction({ label: '刷新', marker: 'skillspage-refresh-1', available: !this.busy,
          pending: this.loading,
          onAction: async (): Promise<void> => { await this.reload(); } })
      }
  }

  @Builder
  buildSurfaceContent() {
      Column({ space: Spacing.sm }) {
        
  
        Row({ space: 6 }) {
          ForEach(['all', 'global', 'builtin'], (kind: string) => {
            Button(kind === 'all' ? '全部' : (kind === 'global' ? '全局' : '内置'), { type: ButtonType.Normal })
              .fontSize(UIType.caption)
              .constraintSize({ minHeight: 44 })
              .backgroundColor(this.filterKind === kind ? this.uiColors.accent : this.uiColors.bgSurfaceHigh)
              .fontColor(this.filterKind === kind ? this.uiColors.textInverse : this.uiColors.textSecondary)
              .onClick(() => {
                this.setFilter(kind);
              })
          .attributeModifier(new ActionButtonStyle(this.uiColors, (this.filterKind === kind) ? ActionTone.Selected : ActionTone.Normal))
      }, (kind: string) => kind)
        }
        .width('100%')
        .padding({ left: Spacing.md })
  
        if (this.statusText !== '') {
          Text(this.statusText)
            .fontSize(Typography.caption)
            .fontColor(this.uiColors.textTertiary)
            .width('100%')
            .padding({ left: Spacing.md })
        }
        ErrorBannerView({ text: this.errorText })
  
        Column() {
          Column({ space: Spacing.md }) {
            if (this.loading) {
              Text('读取中…').fontSize(Typography.caption).fontColor(this.uiColors.textTertiary)
            } else if (this.skills.length === 0) {
              EmptyHint('该范围内没有技能', '可以从下面的 URL 导入一个技能包', this.uiColors)
            } else {
              ForEach(this.skills, (skill: SkillIndexEntry) => {
                this.skillCard(skill)
              }, (skill: SkillIndexEntry) => `${skill.name}|${skill.scope.kind}|${skill.installedHash}`)
            }
            this.importPanel()
          }
          .width('100%')
          .padding({ bottom: Spacing.xxl })
        }
        .width('100%')
        .align(Alignment.Top)
      }
      .width('100%')
      .backgroundColor(this.uiColors.bgBase)
    }

  build() {
    PageSurface({ topBar: () => { this.pageTopBar(); }, content: () => { this.buildSurfaceContent(); } })
  }

  @Builder
  skillCard(skill: SkillIndexEntry) {
    Column({ space: Spacing.sm }) {
      Row({ space: Spacing.sm }) {
        Column({ space: 2 }) {
          Text(skill.displayName !== undefined && skill.displayName !== null ? skill.displayName : skill.name)
            .fontSize(Typography.subtitle)
            .fontColor(this.uiColors.textPrimary)
            .width('100%')
            .maxLines(1)
          Text(skill.description)
            .fontSize(Typography.caption)
            .fontColor(this.uiColors.textSecondary)
            .width('100%')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(skill.scope.kind)
          .fontSize(Typography.micro)
          .fontColor(this.uiColors.textTertiary)
      }
      .width('100%')

      Text(`${skill.fileCount} 文件 · ${Math.round(skill.totalBytes / 1024)} KB${skill.hasScripts ? ' · 含脚本' : ''}${skill.hasBinary ? ' · 含二进制' : ''}`)
        .fontSize(Typography.micro)
        .fontColor(this.uiColors.textTertiary)
        .width('100%')

      Row({ space: Spacing.sm }) {
        Button(this.expanded === skill.name ? '收起' : '查看文件', { type: ButtonType.Normal })
          .fontSize(UIType.caption)
          .constraintSize({ minHeight: 44 })
          .layoutWeight(1)
          .onClick(() => {
            this.expand(skill);
          })
        .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button('导出', { type: ButtonType.Normal })
          .fontSize(UIType.caption)
          .constraintSize({ minHeight: 44 })
          .backgroundColor(this.uiColors.bgSurfaceHigh)
          .fontColor(this.uiColors.textSecondary)
          .enabled(!this.busy)
          .onClick(() => {
            this.exportRow(skill);
          })
        .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      Button('删除', { type: ButtonType.Normal })
          .fontSize(UIType.caption)
          .constraintSize({ minHeight: 44 })
          .backgroundColor(this.uiColors.danger)
          .onClick(() => {
            this.deleting = skill.name;
          })
      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Danger))
      }
      .width('100%')

      if (this.exportNote !== '' && this.expanded === skill.name) {
        Text(this.exportNote)
          .fontSize(Typography.micro)
          .fontColor(this.uiColors.textSecondary)
          .width('100%')
      }

      if (this.deleting === skill.name) {
        Row({ space: Spacing.sm }) {
          Text('确认删除该技能？')
            .fontSize(Typography.caption)
            .fontColor(this.uiColors.textSecondary)
            .layoutWeight(1)
          Button('确认', { type: ButtonType.Normal })
            .fontSize(UIType.caption)
            .constraintSize({ minHeight: 44 })
            .backgroundColor(this.uiColors.danger)
            .enabled(!this.busy)
            .onClick(() => {
              this.doDelete(skill);
            })
          .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Danger))
      Button('取消', { type: ButtonType.Normal })
            .fontSize(UIType.caption)
            .constraintSize({ minHeight: 44 })
            .backgroundColor(this.uiColors.bgSurfaceHigh)
            .onClick(() => {
              this.deleting = '';
            })
        .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
        .width('100%')
      }

      if (this.expanded === skill.name) {
        Divider().color(this.uiColors.borderSubtle)
        Text(this.filesNote)
          .fontSize(Typography.micro)
          .fontColor(this.uiColors.textTertiary)
          .width('100%')
        ForEach(this.files, (ref: SkillFileRef) => {
          Row({ space: Spacing.sm }) {
            Text(ref.path)
              .fontSize(Typography.caption)
              .fontColor(this.editPath === ref.path ? this.uiColors.accent : this.uiColors.textSecondary)
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(`${Math.round(ref.sizeBytes / 1024)} KB`)
              .fontSize(Typography.micro)
              .fontColor(this.uiColors.textTertiary)
          }
          .width('100%')
          .padding({ top: 4, bottom: 4 })
          .onClick(() => {
            this.openFile(skill, ref);
          })
        }, (ref: SkillFileRef) => `${ref.path}|${ref.sha256}`)

        if (this.editPath !== '') {
          Text(this.editNote)
            .fontSize(Typography.micro)
            .fontColor(this.uiColors.textTertiary)
            .width('100%')
          TextArea({ text: this.editContent })
            .fontColor(this.uiColors.textPrimary)
            .placeholderColor(this.uiColors.textTertiary)
            .backgroundColor(this.uiColors.bgSurfaceHigh)
            .borderRadius(UIRadius.sm)
            .fontSize(Typography.micro)
            .height(220)
            .width('100%')
            .backgroundColor(this.uiColors.bgSurfaceHigh)
            .borderRadius(Radius.sm)
            .onChange((value: string) => {
              this.editContent = value;
            })
          .attributeModifier(new TextAreaFieldStyle(this.uiColors))
      Row({ space: Spacing.sm }) {
            Button('保存文件', { type: ButtonType.Normal })
              .fontSize(UIType.caption)
              .constraintSize({ minHeight: 44 })
              .layoutWeight(1)
              .enabled(!this.busy)
              .onClick(() => {
                this.saveFile(skill);
              })
            .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      Button('关闭', { type: ButtonType.Normal })
              .fontSize(UIType.caption)
              .constraintSize({ minHeight: 44 })
              .backgroundColor(this.uiColors.bgSurfaceHigh)
              .onClick(() => {
                this.editPath = '';
                this.editContent = '';
              })
          .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
          .width('100%')
        }
      }
    }
    .width('100%')
    .padding(Spacing.md)
    .borderRadius(GLASS_CARD.radius)
    .backgroundColor(this.uiColors.bgSurface)
    .border({ width: 1, color: this.uiColors.borderSubtle })
  }

  @Builder
  importPanel() {
    Column({ space: Spacing.sm }) {
      SectionTitle('从 URL 导入技能', this.uiColors)
      Row({ space: Spacing.sm }) {
        TextInput({ text: this.importUrl, placeholder: 'https://…/skill.zip' })
          .fontColor(this.uiColors.textPrimary)
          .placeholderColor(this.uiColors.textTertiary)
          .backgroundColor(this.uiColors.bgSurfaceHigh)
          .borderRadius(UIRadius.sm)
          .fontSize(Typography.caption)
          .constraintSize({ minHeight: 44 })
          .layoutWeight(1)
          .backgroundColor(this.uiColors.bgSurfaceHigh)
          .borderRadius(Radius.sm)
          .onChange((value: string) => {
            this.importUrl = value;
          })
        .attributeModifier(new InputFieldStyle(this.uiColors))
      Button('下载', { type: ButtonType.Normal })
          .fontSize(UIType.caption)
          .constraintSize({ minHeight: 44 })
          .enabled(!this.busy)
          .onClick(() => {
            this.downloadImport();
          })
      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
      .width('100%')

      if (this.preview !== undefined) {
        Column({ space: 4 }) {
          Text(`技能：${this.preview!.skill.name}`)
            .fontSize(Typography.caption)
            .fontColor(this.uiColors.textPrimary)
            .width('100%')
          Text(`冲突：${this.preview!.conflict.kind} · ${this.preview!.files.length} 个文件`)
            .fontSize(Typography.micro)
            .fontColor(this.uiColors.textTertiary)
            .width('100%')
          if (this.preview!.warnings.length > 0) {
            Text(`警告：${this.preview!.warnings[0]}`)
              .fontSize(Typography.micro)
              .fontColor(this.uiColors.warning)
              .width('100%')
          }
          Row({ space: Spacing.sm }) {
            Button('安装（覆盖）', { type: ButtonType.Normal })
              .fontSize(UIType.caption)
              .constraintSize({ minHeight: 44 })
              .layoutWeight(1)
              .enabled(!this.busy)
              .onClick(() => {
                this.installImport('replace');
              })
            .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button('安装（跳过冲突）', { type: ButtonType.Normal })
              .fontSize(UIType.caption)
              .constraintSize({ minHeight: 44 })
              .backgroundColor(this.uiColors.bgSurfaceHigh)
              .fontColor(this.uiColors.textSecondary)
              .enabled(!this.busy)
              .onClick(() => {
                this.installImport('skip');
              })
          .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
          .width('100%')
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(Spacing.md)
    .borderRadius(GLASS_CARD.radius)
    .backgroundColor(this.uiColors.bgSurface)
    .border({ width: 1, color: this.uiColors.borderSubtle })
  }
}
