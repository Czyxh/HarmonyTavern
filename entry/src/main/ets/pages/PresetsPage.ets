import { ActionButtonStyle, ActionTone, InputFieldStyle, TextAreaFieldStyle } from '../theme/ControlStyles';
import { HeaderAction } from '../components/HeaderAction';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { PageSurface } from '../components/PageSurface';
import { SCROLL_EDGE_OPTIONS, SCROLL_NESTED_OPTIONS } from '../theme/ScrollFeedback';
import { Radius as UIRadius, Typography as UIType } from '../theme/Tokens';
import { PageHeader } from '../components/PageHeader';
// 预设（P8-11）：对应原项目 SillyTavern 的 Presets 面板 + Rust preset_service 的 8 类预设。
//
// 支持的类型（Rust PresetType::from_api_id）：
//   openai / kobold / novel / textgenerationwebui / instruct / context / sysprompt / reasoning
//
// 能力：按类型列出预设 → 读取（JSON 原文）→ 编辑保存 / 删除 / 恢复默认 / 新建。
// 预设内容是 SillyTavern 的 JSON 结构，这里给的是**原文编辑**（不臆造字段表单），
// 与原项目"在 ST 里编辑预设 JSON"一致。
//
// 对应 DevEco 工程路径：entry/src/main/ets/pages/PresetsPage.ets
import { Backend, BackendError } from '../backend/Backend';
import { ROOT_PATH_STACK } from '../nav/RootNav';
import { Radius, Spacing, Typography } from '../theme/Tokens';
import { GLASS_CARD, GLASS_HEADER, glassEffect } from '../theme/Glass';
import { EmptyHint, ErrorBannerView, SectionTitle } from '../components/Builders';

interface PresetTypeOption {
  apiId: string;
  label: string;
}

const PRESET_TYPES: PresetTypeOption[] = [
  { apiId: 'openai', label: 'OpenAI' },
  { apiId: 'instruct', label: 'Instruct' },
  { apiId: 'context', label: 'Context' },
  { apiId: 'sysprompt', label: '系统提示词' },
  { apiId: 'reasoning', label: 'Reasoning' },
  { apiId: 'textgenerationwebui', label: 'TextGen' },
  { apiId: 'kobold', label: 'Kobold' },
  { apiId: 'novel', label: 'NovelAI' }
];

@Component
export struct PresetsPage {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @State apiId: string = 'openai';
  @State loading: boolean = true;
  @State busy: boolean = false;
  @State errorText: string = '';
  @State statusText: string = '';
  @State names: string[] = [];

  @State editingName: string = '';
  @State editingText: string = '';
  @State isNew: boolean = false;

  aboutToAppear(): void {
    if (!Backend.isReady()) {
      this.errorText = '后端未就绪，请从首页进入';
      this.loading = false;
      return;
    }
    this.reload();
  }

  async reload(): Promise<void> {
    this.loading = true;
    this.errorText = '';
    try {
      this.names = await Backend.listPresets(this.apiId);
      if (this.editingName !== '' && !this.isNew) {
        this.editingName = '';
        this.editingText = '';
      }
    } catch (err) {
      this.errorText = `读取预设失败：${(err as BackendError).message}`;
      this.names = [];
    } finally {
      this.loading = false;
    }
  }

  selectType(id: string): void {
    if (this.apiId === id) {
      return;
    }
    this.apiId = id;
    this.editingName = '';
    this.editingText = '';
    this.isNew = false;
    this.reload();
  }

  async open(name: string): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      const preset: ESObject = await Backend.getPreset(name, this.apiId);
      if (preset === null || preset === undefined) {
        this.errorText = `预设「${name}」读出来是空的`;
        return;
      }
      this.editingName = name;
      this.isNew = false;
      this.editingText = JSON.stringify(preset, null, 2);
    } catch (err) {
      this.errorText = `读取预设失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async save(): Promise<void> {
    const name: string = this.editingName.trim();
    if (name === '') {
      this.errorText = '预设名不能为空';
      return;
    }
    let parsed: ESObject;
    try {
      parsed = JSON.parse(this.editingText) as ESObject;
    } catch (err) {
      this.errorText = 'JSON 不合法，先修正再保存';
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      await Backend.savePreset({ name: name, apiId: this.apiId, preset: parsed });
      this.statusText = `已保存 ${name}`;
      this.isNew = false;
      await this.reload();
    } catch (err) {
      this.errorText = `保存失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async remove(name: string): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      await Backend.deletePreset({ name: name, apiId: this.apiId });
      this.statusText = `已删除 ${name}`;
      if (this.editingName === name) {
        this.editingName = '';
        this.editingText = '';
      }
      await this.reload();
    } catch (err) {
      this.errorText = `删除失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async restore(name: string): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      await Backend.restorePreset({ name: name, apiId: this.apiId });
      this.statusText = `已恢复默认 ${name}`;
      await this.reload();
    } catch (err) {
      this.errorText = `恢复失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  startNew(): void {
    this.isNew = true;
    this.editingName = '';
    this.editingText = '{\n  \n}';
    this.statusText = '新建预设：填名字 → 编辑 JSON → 保存';
  }

  @Builder
  pageTopBar() {
    PageHeader({ title: '预设', subtitle: '调校每一次回应', onBack: (): void => { ROOT_PATH_STACK.pop(); } }) {
      HeaderAction({ label: '刷新预设', marker: 'presets-refresh-action', available: !this.busy && !this.loading,
        pending: this.loading,
        onAction: async (): Promise<void> => { await this.reload(); } })
      HeaderAction({ icon: $r('app.media.icon_add'), label: '新建预设', marker: 'presets-create-action',
        refresh: false, available: !this.busy && !this.loading,
        onAction: async (): Promise<void> => { this.startNew(); } })
    }
  }

  @Builder
  buildSurfaceContent() {
      Column({ space: Spacing.sm }) {
        
  
        Scroll() {
          Row({ space: 6 }) {
            ForEach(PRESET_TYPES, (option: PresetTypeOption) => {
              Button(option.label, { type: ButtonType.Normal })
                .fontSize(UIType.caption)
                .constraintSize({ minHeight: 44 })
                .backgroundColor(this.apiId === option.apiId ? this.uiColors.accent : this.uiColors.bgSurfaceHigh)
                .fontColor(this.apiId === option.apiId ? this.uiColors.textInverse : this.uiColors.textSecondary)
                .onClick(() => {
                  this.selectType(option.apiId);
                })
            .attributeModifier(new ActionButtonStyle(this.uiColors, (this.apiId === option.apiId) ? ActionTone.Selected : ActionTone.Normal))
      }, (option: PresetTypeOption) => option.apiId)
          }
          .padding({ left: Spacing.md, right: Spacing.md })
        }
        .scrollBar(BarState.Off)
        .scrollable(ScrollDirection.Horizontal)
        .edgeEffect(EdgeEffect.Spring, SCROLL_EDGE_OPTIONS)
        .nestedScroll(SCROLL_NESTED_OPTIONS)
        .width('100%')
        .constraintSize({ minHeight: 44 })
  
        if (this.statusText !== '') {
          Text(this.statusText)
            .fontSize(Typography.micro)
            .fontColor(this.uiColors.textTertiary)
            .width('100%')
            .padding({ left: Spacing.md })
        }
        ErrorBannerView({ text: this.errorText })
  
        Column() {
          Column({ space: Spacing.md }) {
            if (this.isNew || this.editingName !== '') {
              this.editorCard()
            }
  
            if (this.loading) {
              Text('读取中…').fontSize(Typography.caption).fontColor(this.uiColors.textTertiary)
            } else if (this.names.length === 0) {
              EmptyHint(`${this.apiId} 类型下没有预设`, '点击右上角＋创建预设，或切换预设类型', this.uiColors)
            } else {
              ForEach(this.names, (name: string) => {
                Column({ space: 6 }) {
                  Row({ space: Spacing.sm }) {
                    Text(name)
                      .fontSize(Typography.caption)
                      .fontColor(this.editingName === name ? this.uiColors.accent : this.uiColors.textPrimary)
                      .layoutWeight(1)
                      .maxLines(1)
                    Text(this.apiId)
                      .fontSize(Typography.micro)
                      .fontColor(this.uiColors.textTertiary)
                  }
                  .width('100%')
  
                  Row({ space: Spacing.sm }) {
                    Button('打开', { type: ButtonType.Normal })
                      .fontSize(UIType.caption)
                      .constraintSize({ minHeight: 44 })
                      .layoutWeight(1)
                      .enabled(!this.busy)
                      .onClick(() => {
                        this.open(name);
                      })
                    .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button('恢复默认', { type: ButtonType.Normal })
                      .fontSize(UIType.caption)
                      .constraintSize({ minHeight: 44 })
                      .backgroundColor(this.uiColors.bgSurfaceHigh)
                      .fontColor(this.uiColors.textSecondary)
                      .enabled(!this.busy)
                      .onClick(() => {
                        this.restore(name);
                      })
                    .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      Button('删除', { type: ButtonType.Normal })
                      .fontSize(UIType.caption)
                      .constraintSize({ minHeight: 44 })
                      .backgroundColor(this.uiColors.danger)
                      .enabled(!this.busy)
                      .onClick(() => {
                        this.remove(name);
                      })
                  .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Danger))
      }
                  .width('100%')
                }
                .width('100%')
                .padding(Spacing.md)
                .borderRadius(GLASS_CARD.radius)
                .backgroundColor(this.uiColors.bgSurface)
                .border({ width: 1, color: this.uiColors.borderSubtle })
              }, (name: string) => `${this.apiId}|${name}`)
            }
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
  editorCard() {
    Column({ space: Spacing.sm }) {
      SectionTitle(this.isNew ? '新建预设' : `编辑：${this.editingName}`, this.uiColors)
      TextInput({ text: this.editingName, placeholder: '预设名（英文/数字）' })
        .fontColor(this.uiColors.textPrimary)
        .placeholderColor(this.uiColors.textTertiary)
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(UIRadius.sm)
        .fontSize(Typography.caption)
        .constraintSize({ minHeight: 44 })
        .width('100%')
        .enabled(this.isNew)
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(Radius.sm)
        .onChange((value: string) => {
          this.editingName = value;
        })
      .attributeModifier(new InputFieldStyle(this.uiColors))
      Text('预设 JSON（SillyTavern 原始结构）')
        .fontSize(Typography.micro)
        .fontColor(this.uiColors.textTertiary)
        .width('100%')
      TextArea({ text: this.editingText })
        .fontColor(this.uiColors.textPrimary)
        .placeholderColor(this.uiColors.textTertiary)
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(UIRadius.sm)
        .fontSize(Typography.micro)
        .height(320)
        .width('100%')
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(Radius.sm)
        .onChange((value: string) => {
          this.editingText = value;
        })
      .attributeModifier(new TextAreaFieldStyle(this.uiColors))
      Row({ space: Spacing.sm }) {
        Button('保存', { type: ButtonType.Normal })
          .fontSize(Typography.caption)
          .constraintSize({ minHeight: 44 })
          .layoutWeight(1)
          .enabled(!this.busy)
          .onClick(() => {
            this.save();
          })
        .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      Button('关闭', { type: ButtonType.Normal })
          .fontSize(Typography.caption)
          .constraintSize({ minHeight: 44 })
          .backgroundColor(this.uiColors.bgSurfaceHigh)
          .fontColor(this.uiColors.textSecondary)
          .onClick(() => {
            this.editingName = '';
            this.editingText = '';
            this.isNew = false;
          })
      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
      .width('100%')
    }
    .width('100%')
    .padding(Spacing.md)
    .borderRadius(GLASS_CARD.radius)
    .backgroundColor(this.uiColors.bgSurface)
    .border({ width: 1, color: this.uiColors.borderSubtle })
  }
}
