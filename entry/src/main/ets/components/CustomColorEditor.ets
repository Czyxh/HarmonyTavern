import { SurfaceStyle } from '../theme/SurfaceStyles';
import { ActionButtonStyle, ActionTone, InputFieldStyle } from '../theme/ControlStyles';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { Appearance } from '../theme/Appearance';
import { CustomPalette } from '../theme/CustomPalette';
import { JellyTabBar } from './JellyTabBar';
import { SwingContent } from './SwingContent';

@Component
export struct CustomColorEditor {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @State dark: boolean = false;
  @State selectedDraft: number = 0;
  @State baseColor: string = '#F4E5EB';
  @State accent: string = '#A34268';
  @State editingAccent: boolean = true;
  @State message: string = '';
  private lightBaseDraft: string = '#F4E5EB';
  private lightAccentDraft: string = '#A34268';
  private darkBaseDraft: string = '#281E25';
  private darkAccentDraft: string = '#EDA1BC';

  aboutToAppear(): void {
    this.lightBaseDraft = CustomPalette.saved(false, false);
    this.lightAccentDraft = CustomPalette.saved(false, true);
    this.darkBaseDraft = CustomPalette.saved(true, false);
    this.darkAccentDraft = CustomPalette.saved(true, true);
    this.baseColor = this.lightBaseDraft;
    this.accent = this.lightAccentDraft;
  }

  private loadDraft(dark: boolean): void {
    if (this.dark) {
      this.darkBaseDraft = this.baseColor;
      this.darkAccentDraft = this.accent;
    } else {
      this.lightBaseDraft = this.baseColor;
      this.lightAccentDraft = this.accent;
    }
    this.dark = dark;
    this.baseColor = dark ? this.darkBaseDraft : this.lightBaseDraft;
    this.accent = dark ? this.darkAccentDraft : this.lightAccentDraft;
    this.message = '';
  }

  private valid(): boolean {
    return CustomPalette.normalize(this.baseColor) !== '' && CustomPalette.normalize(this.accent) !== '';
  }

  private previewColors(): ColorTokens { return CustomPalette.colors(this.baseColor, this.accent); }

  private channel(index: number): number {
    const value: string = CustomPalette.normalize(this.editingAccent ? this.accent : this.baseColor) || '#808080';
    return CustomPalette.channel(value, index);
  }

  private changeChannel(index: number, value: number): void {
    const channels: number[] = [this.channel(0), this.channel(1), this.channel(2)];
    channels[index] = value;
    const color: string = CustomPalette.fromChannels(channels[0], channels[1], channels[2]);
    if (this.editingAccent) { this.accent = color; } else { this.baseColor = color; }
    this.message = '';
  }

  private apply(): void {
    if (!CustomPalette.save(this.dark, this.baseColor, this.accent)) { return; }
    Appearance.selectBackground('custom', this.getUIContext());
    this.message = `已保存${this.dark ? '深色' : '浅色'}配色，切换到对应显示模式时使用`;
  }

  @Builder
  colorField(label: string, accent: boolean) {
    Column({ space: 8 }) {
      Text(label).fontSize(15).fontColor(this.uiColors.textPrimary)
      Row({ space: 10 }) {
        Button({ type: ButtonType.Circle }) {
          Circle().fill(CustomPalette.normalize(accent ? this.accent : this.baseColor) || '#808080').width(30).height(30)
        }
        .width(44).height(44).backgroundColor(this.uiColors.bgSurfaceHigh)
        .border({ width: this.editingAccent === accent ? 2 : 0, color: this.uiColors.accent })
        .accessibilityText(`用滑块调节${label}`).accessibilitySelected(this.editingAccent === accent)
        .onClick(() => { this.editingAccent = accent; })
        TextInput({ text: accent ? this.accent : this.baseColor, placeholder: '#RRGGBB' })
          .layoutWeight(1).height(48).maxLength(7).fontColor(this.uiColors.textPrimary)
          .backgroundColor(this.uiColors.bgSurfaceHigh).borderRadius(16)
          .accessibilityText(`${label}，十六进制颜色`)
          .onFocus(() => { this.editingAccent = accent; })
          .onChange((value: string) => {
            if (accent) { this.accent = value; } else { this.baseColor = value; }
            this.message = '';
          })
      .attributeModifier(new InputFieldStyle(this.uiColors))
      }
      .width('100%')
    }
    .width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  channelSlider(label: string, index: number) {
    Row({ space: 10 }) {
      Text(label).fontSize(13).fontColor(this.uiColors.textSecondary).width(22)
      Slider({ value: this.channel(index), min: 0, max: 255, step: 1 })
        .layoutWeight(1).selectedColor(this.uiColors.accent).blockColor(this.uiColors.accent)
        .trackColor(this.uiColors.bgSurfaceHigh).accessibilityText(`${this.editingAccent ? '主题色' : '背景色'}${label}通道`)
        .onChange((value: number) => { this.changeChannel(index, value); })
      Text(`${this.channel(index)}`).width(28).fontSize(12).fontColor(this.uiColors.textSecondary)
    }
    .width('100%')
  }

  @Builder
  editorContent() {
    Column({ space: 18 }) {
      Column({ space: 12 }) {
        Text('属于你的故事色彩').fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.previewColors().textPrimary).width('100%')
        Text('这是一张卡片，也是一段新故事的起点。').fontSize(14).fontColor(this.previewColors().textSecondary)
          .width('100%').padding(14).backgroundColor(this.previewColors().bgSurface).borderRadius(16)
        Text('主题色预览').fontSize(14).fontColor(this.previewColors().textInverse)
          .padding({ left: 20, right: 20, top: 12, bottom: 12 }).backgroundColor(this.previewColors().accent).borderRadius(22)
      }
      .width('100%').padding(18).backgroundColor(this.previewColors().bgBase).borderRadius(20)
      this.colorField('背景色', false)
      this.colorField('主题色', true)
      Text(`正在调节：${this.editingAccent ? '主题色' : '背景色'}`).fontSize(13).fontColor(this.uiColors.textSecondary).width('100%')
      this.channelSlider('红', 0)
      this.channelSlider('绿', 1)
      this.channelSlider('蓝', 2)
      Text(this.valid() ? '为保证清晰，主题色会按背景适当调整明暗，以预览为准。' : '请输入有效的颜色，例如 #E8A6BD 或 #FAB。')
        .fontSize(12).fontColor(this.valid() ? this.uiColors.textTertiary : this.uiColors.danger).lineHeight(19).width('100%')
      Button('保存并应用', { type: ButtonType.Normal }).width('100%').height(48).fontSize(15)
        .backgroundColor(this.uiColors.accent).fontColor(this.uiColors.textInverse).enabled(this.valid())
        .onClick(() => { this.apply(); })
      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      if (this.message !== '') {
        Text(this.message).fontSize(13).fontColor(this.uiColors.success).lineHeight(20).width('100%')
      }
    }
    .width('100%')
  }

  build() {
    Column({ space: 18 }) {
      Text('自定义配色').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.uiColors.textPrimary).width('100%')
      Text('分别保存日间和夜间配色。输入色值或拖动滑块，文字、卡片、图标和玻璃会自动搭配。')
        .fontSize(13).fontColor(this.uiColors.textSecondary).lineHeight(20).width('100%')
      JellyTabBar({ items: [{ glyph: '', label: '浅色配色' }, { glyph: '', label: '深色配色' }],
        currentIndex: this.selectedDraft, textOnly: true, onSelect: (index: number): void => { this.selectedDraft = index; } })
      SwingContent({ activeIndex: this.selectedDraft,
        onDisplay: (index: number): void => { this.loadDraft(index === 1); },
        content: (): void => { this.editorContent(); } })
    }
    .width('100%').padding(20).backgroundColor(this.uiColors.bgSurface).borderRadius(24).attributeModifier(new SurfaceStyle(this.uiColors, 24))
    .border({ width: 1, color: this.uiColors.borderSubtle })
  }
}
