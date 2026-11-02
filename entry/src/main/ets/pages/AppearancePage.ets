import { SurfaceStyle } from '../theme/SurfaceStyles';
import { ActionButtonStyle, ActionTone } from '../theme/ControlStyles';
import { iconTint } from '../theme/IconTint';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { RpgThemes } from '../theme/RpgThemes';
import { PageHeader } from '../components/PageHeader';
import { PageSurface } from '../components/PageSurface';
import { ROOT_PATH_STACK } from '../nav/RootNav';
import { Appearance, BackgroundPalette, BACKGROUND_DEFAULT, BACKGROUND_KEY, COLOR_TRANSITION_KEY } from '../theme/Appearance';
import { LightSense, LS_BLUR_DEFAULT, LS_BLUR_KEY, LS_BLUR_MAX } from '../theme/LightSense';
import { IMMERSIVE_DEFAULT, IMMERSIVE_KEY, IMMERSIVE_PRESETS, Immersive, ImmersivePreset } from '../theme/Immersive';
import { MotionPolicy, MOTION_REDUCE_KEY } from '../theme/Motion';
import { JellyTabBar, JellyTabItem } from '../components/JellyTabBar';
import { SwingContent } from '../components/SwingContent';
import { CustomColorEditor } from '../components/CustomColorEditor';
import { PersonalizationStore } from '../theme/PersonalizationStore';
import { DisplayPreferences, DISPLAY_MODE_KEY, FONT_SCALE_KEY } from '../theme/DisplayPreferences';
import { ReadingPreferences, READING_SIZE_KEY, READING_LINE_KEY, READING_FONT_KEY, READING_INSET_KEY } from '../theme/ReadingPreferences';
import { SettingsPicker } from '../components/SettingsPicker';
import { HoldingPose, HOLDING_ENABLED_KEY, HOLDING_ACTION_KEY, HOLDING_LIGHT_KEY, HOLDING_AVAILABLE_KEY } from '../theme/HoldingPose';

const SECTIONS: JellyTabItem[] = [
  { label: '主题', glyph: '' }, { label: '显示', glyph: '' }, { label: '字体', glyph: '' },
  { label: '光感', glyph: '' }, { label: '动效', glyph: '' }, { label: '握持', glyph: '' }
];

interface BlurPreset {
  label: string;
  value: number;
}

const BLUR_PRESETS: BlurPreset[] = [
  { label: '清晰', value: LS_BLUR_DEFAULT },
  { label: '标准', value: 28 },
  { label: '浓郁', value: 48 }
];

@Component
export struct AppearancePage {
  @State activeSection: number = 0;
  @State displayedSection: number = 0;
  @State showCustom: boolean = false;
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @StorageProp(BACKGROUND_KEY) backgroundId: string = BACKGROUND_DEFAULT;
  @StorageProp(LS_BLUR_KEY) glassBlur: number = LS_BLUR_DEFAULT;
  @StorageProp(IMMERSIVE_KEY) immersiveLevel: number = IMMERSIVE_DEFAULT;
  @StorageProp(MOTION_REDUCE_KEY) reduceMotion: boolean = false;
  @StorageProp(COLOR_TRANSITION_KEY) colorTransition: boolean = true;
  @StorageProp(DISPLAY_MODE_KEY) displayMode: string = 'system';
  @StorageProp(FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(READING_SIZE_KEY) readingSize: number = 15;
  @StorageProp(READING_LINE_KEY) readingLine: number = 2;
  @StorageProp(READING_FONT_KEY) readingFont: string = 'system';
  @StorageProp(READING_INSET_KEY) readingInset: number = 10;
  @StorageProp(HOLDING_ENABLED_KEY) holdingEnabled: boolean = true;
  @StorageProp(HOLDING_ACTION_KEY) holdingAction: boolean = true;
  @StorageProp(HOLDING_LIGHT_KEY) holdingLight: boolean = true;
  @StorageProp(HOLDING_AVAILABLE_KEY) holdingAvailable: boolean = false;
  @State settingError: string = '';

  private resetAppearance(): void {
    Appearance.selectBackground(BACKGROUND_DEFAULT, this.getUIContext());
    LightSense.setBlurRadius(LS_BLUR_DEFAULT);
    Immersive.setLevel(IMMERSIVE_DEFAULT);
    MotionPolicy.setReduceMotion(false);
    PersonalizationStore.set(COLOR_TRANSITION_KEY, true);
    HoldingPose.setEnabled(HOLDING_ENABLED_KEY, true);
    HoldingPose.setEnabled(HOLDING_ACTION_KEY, true);
    HoldingPose.setEnabled(HOLDING_LIGHT_KEY, true);
    const displayReset: boolean = DisplayPreferences.setMode('system');
    const fontReset: boolean = DisplayPreferences.setFontScale(1);
    ReadingPreferences.reset();
    this.settingError = displayReset && fontReset ? '' : '部分系统显示设置未能恢复，请重试。';
  }

  @Styles
  sectionCard() {
    .width('100%')
    .padding(20)
    .backgroundColor(this.uiColors.bgSurface)
    .borderRadius(24)
    .attributeModifier(new SurfaceStyle(this.uiColors, 24))
    .border({ width: 1, color: this.uiColors.borderSubtle })
  }

  @Builder
  heading(title: string, detail: string) {
    Column({ space: 6 }) {
      Text(title).fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.uiColors.textPrimary)
      Text(detail).fontSize(13).fontColor(this.uiColors.textSecondary).lineHeight(20)
    }
    .width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  preview() {
    Column({ space: 12 }) {
      Row() {
        Text('此刻的色调').fontSize(12).fontColor(this.uiColors.textSecondary).layoutWeight(1)
        Text(Appearance.palette(this.backgroundId).label).fontSize(12).fontColor(this.uiColors.accent)
      }
      .width('100%')
      Text('让阅读慢下来').fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.uiColors.textPrimary).width('100%')
      Text('柔和的底色，清晰的文字。\n留一点安静，给正在展开的故事。')
        .fontSize(15).fontColor(this.uiColors.textSecondary).lineHeight(25).width('100%')
      Row({ space: 10 }) {
        Text('从一句问候开始…').fontSize(13).fontColor(this.uiColors.textTertiary).layoutWeight(1)
        Image($r('app.media.icon_spark')).width(20).height(20).colorFilter(iconTint(this.uiColors.accent))
      }
      .width('100%').padding(14).backgroundColor(this.uiColors.bgSurfaceHigh).borderRadius(18)
    }
    .sectionCard()
  }

  @Builder
  backgroundCard() {
    Column({ space: 16 }) {
      this.heading('阅读配色', '选择阅读配色或 RPG 主题。切换后全局生效并自动保存，每套主题都提供深浅配色。')
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        ForEach(Appearance.palettes(), (palette: BackgroundPalette) => {
          Button({ type: ButtonType.Normal }) {
            Column({ space: 10 }) {
              if (RpgThemes.find(palette.id) !== undefined) {
                Image(RpgThemes.art(palette.id)).width('100%').height(62).objectFit(ImageFit.Cover)
                  .borderRadius(RpgThemes.find(palette.id)?.radius ?? 12).accessibilityLevel('no')
              }
              Row({ space: 5 }) {
                Circle().width(18).height(18).fill(palette.surface)
                Circle().width(18).height(18).fill(palette.surfaceHigh)
                Blank()
                Text(Appearance.palette(this.backgroundId).id === palette.id ? '✓' : '')
                  .fontSize(18).fontWeight(FontWeight.Bold).fontColor(Appearance.colors(palette.id).accent)
              }
              .width('100%')
              Text(palette.label).fontSize(16).fontWeight(FontWeight.Medium).fontColor(Appearance.colors(palette.id).textPrimary)
              Text(palette.description).fontSize(12).fontColor(Appearance.colors(palette.id).textSecondary).lineHeight(18)
            }
            .width('100%').alignItems(HorizontalAlign.Start)
          }
          .width('48%').padding(14).margin({ bottom: 12 }).backgroundColor(palette.background)
          .borderRadius(RpgThemes.find(palette.id)?.radius ?? 20)
          .border({ width: Appearance.palette(this.backgroundId).id === palette.id ? 2 : 1,
            color: Appearance.palette(this.backgroundId).id === palette.id ? this.uiColors.accent : this.uiColors.borderSubtle })
          .accessibilityText(`${palette.label}，${palette.description}`)
          .id('appearance-theme-' + palette.id)
          .accessibilitySelected(Appearance.palette(this.backgroundId).id === palette.id)
          .onClick(() => { Appearance.selectBackground(palette.id, this.getUIContext()); })
        }, (palette: BackgroundPalette) => palette.id)
      }
      .width('100%')
      Button(this.showCustom ? '收起自定义配色' : '编辑自定义配色', { type: ButtonType.Normal }).width('100%').height(48).fontSize(15)
        .fontColor(this.uiColors.accent).backgroundColor(this.uiColors.accentContainer)
        .onClick(() => { this.showCustom = !this.showCustom; })
      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Text('深浅模式可在“显示模式”中选择；配色切换动效可在“动态效果”中调整。')
        .fontSize(12).fontColor(this.uiColors.textTertiary).lineHeight(19).width('100%')
    }
    .sectionCard()
  }

  @Builder
  glassCard() {
    Column({ space: 16 }) {
      this.heading('玻璃与光场', '默认清晰 4，保留透光与高光。统一调整导航、分段滑块和聊天栏。')
      Row() {
        Text('模糊强度').fontSize(15).fontColor(this.uiColors.textPrimary).layoutWeight(1)
        Text(`${Math.round(this.glassBlur)}`).fontSize(14).fontColor(this.uiColors.accent)
      }
      .width('100%')
      Slider({ value: this.glassBlur, min: 0, max: LS_BLUR_MAX, step: 1, style: SliderStyle.OutSet })
        .width('100%').blockColor(this.uiColors.accent).selectedColor(this.uiColors.accent).trackColor(this.uiColors.bgSurfaceHigh)
        .accessibilityText('玻璃模糊强度')
        .onChange((value: number) => { LightSense.setBlurRadius(value); })
      Row({ space: 8 }) {
        ForEach(BLUR_PRESETS, (preset: BlurPreset) => {
          Button(preset.label, { type: ButtonType.Normal }).layoutWeight(1).height(44).fontSize(14)
            .fontColor(Math.round(this.glassBlur) === preset.value ? this.uiColors.accent : this.uiColors.textSecondary)
            .backgroundColor(Math.round(this.glassBlur) === preset.value ? this.uiColors.accentContainer : this.uiColors.bgSurfaceHigh)
            .accessibilitySelected(Math.round(this.glassBlur) === preset.value)
            .onClick(() => { LightSense.setBlurRadius(preset.value); })
        .attributeModifier(new ActionButtonStyle(this.uiColors, (Math.round(this.glassBlur) === preset.value) ? ActionTone.Selected : ActionTone.Normal))
      }, (preset: BlurPreset) => preset.label)
      }
      .width('100%')
      Text(this.glassBlur <= 0 ? '已关闭模糊，使用实色界面' : '清晰档位为 4；数值越高，背景虚化越明显')
        .fontSize(12).fontColor(this.uiColors.textTertiary).width('100%')
      Text('顶部模糊比普通玻璃增加约 15，向下渐变到清晰；设为 0 时全部关闭。')
        .fontSize(12).fontColor(this.uiColors.textTertiary).lineHeight(19).width('100%')
      Divider().color(this.uiColors.borderSubtle)
      Text('光影层次').fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.uiColors.textPrimary).width('100%')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(IMMERSIVE_PRESETS, (preset: ImmersivePreset, index: number) => {
          Button(preset.label, { type: ButtonType.Normal }).width('48%').margin({ right: '2%', bottom: 8 }).height(44).fontSize(14)
            .fontColor(this.immersiveLevel === index ? this.uiColors.accent : this.uiColors.textSecondary)
            .backgroundColor(this.immersiveLevel === index ? this.uiColors.accentContainer : this.uiColors.bgSurfaceHigh)
            .accessibilitySelected(this.immersiveLevel === index)
            .onClick(() => { Immersive.setLevel(index); })
        .attributeModifier(new ActionButtonStyle(this.uiColors, (this.immersiveLevel === index) ? ActionTone.Selected : ActionTone.Normal))
      }, (preset: ImmersivePreset) => preset.label)
      }
      .width('100%')
      Text(Immersive.presetOf(this.immersiveLevel).hint).fontSize(12).fontColor(this.uiColors.textTertiary).width('100%')
    }
    .sectionCard()
  }

  @Builder
  motionCard() {
    Column({ space: 18 }) {
      this.heading('动态效果', '按你的习惯选择界面的动感。')
      this.switchRow('配色切换动效', '背景、卡片和按钮柔和过渡到新的配色', this.colorTransition,
        (enabled: boolean): void => { PersonalizationStore.set(COLOR_TRANSITION_KEY, enabled); }, !this.reduceMotion)
      Row({ space: 16 }) {
        Column({ space: 6 }) {
          Text('减少动态效果').fontSize(15).fontColor(this.uiColors.textPrimary)
          Text('关闭配色过渡，减少入场、弹性与控件动效').fontSize(12).fontColor(this.uiColors.textTertiary).lineHeight(19)
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.reduceMotion }).selectedColor(this.uiColors.accent)
          .accessibilityText('减少动态效果')
          .onChange((enabled: boolean) => { MotionPolicy.setReduceMotion(enabled); })
      }
      .width('100%')
    }
    .sectionCard()
  }

  @Builder
  switchRow(label: string, detail: string, selected: boolean, change: (enabled: boolean) => void, enabled: boolean = true) {
    Row({ space: 16 }) {
      Column({ space: 6 }) {
        Text(label).fontSize(15).fontColor(this.uiColors.textPrimary)
        Text(detail).fontSize(12).fontColor(this.uiColors.textTertiary).lineHeight(19)
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: selected }).selectedColor(this.uiColors.accent)
        .enabled(enabled).accessibilityText(label).onChange(change)
    }
    .width('100%').opacity(enabled ? 1 : 0.5)
  }

  @Builder
  holdingCard() {
    Column({ space: 22 }) {
      this.heading('智感握持', '加号远离握持手，创造模式的杯子靠近握持手，光源跟随握持方向。双手握持或未识别时，加号在左、杯子在右。')
      this.switchRow('启用智感握持', '使用设备提供的握持识别', this.holdingEnabled,
        (enabled: boolean): void => { HoldingPose.setEnabled(HOLDING_ENABLED_KEY, enabled); })
      Divider().color(this.uiColors.borderSubtle)
      this.switchRow('加号与杯子随握持手', '左手握持：加号在右、杯子在左；右手握持：加号在左、杯子在右；关闭后加号固定左侧、杯子固定右侧', this.holdingAction,
        (enabled: boolean): void => { HoldingPose.setEnabled(HOLDING_ACTION_KEY, enabled); }, this.holdingEnabled)
      this.switchRow('光源跟随握持', '玻璃高光随握持方向变化', this.holdingLight,
        (enabled: boolean): void => { HoldingPose.setEnabled(HOLDING_LIGHT_KEY, enabled); }, this.holdingEnabled)
      Text(!this.holdingEnabled ? '已关闭握持识别' : !this.holdingAction && !this.holdingLight ? '未启用跟随功能，握持识别已暂停'
        : this.holdingAvailable ? '已连接设备握持识别' : '当前设备暂未提供握持识别，使用固定布局与居中光源')
        .fontSize(12).fontColor(this.uiColors.textSecondary).lineHeight(20).width('100%')
    }
    .sectionCard()
  }

  @Builder
  displayCard() {
    Column({ space: 16 }) {
      this.heading('显示模式', '仅调整本应用。每套主题都提供对应的浅色与深色配色。')
      ForEach(['system', 'light', 'dark'], (mode: string) => {
        Button({ type: ButtonType.Normal }) {
          Row() {
            Text(DisplayPreferences.modeLabel(mode)).fontSize(16).fontColor(this.uiColors.textPrimary).layoutWeight(1)
            Text(this.displayMode === mode ? '✓' : '').fontSize(20).fontColor(this.uiColors.accent)
          }
          .width('100%')
        }
        .width('100%').constraintSize({ minHeight: 56 }).padding(16).borderRadius(18)
        .backgroundColor(this.displayMode === mode ? this.uiColors.accentContainer : this.uiColors.bgSurfaceHigh)
        .accessibilitySelected(this.displayMode === mode)
        .onClick(() => { this.settingError = DisplayPreferences.setMode(mode) ? '' : '显示模式未能切换，请重试。'; })
      }, (mode: string) => mode)
    }
    .sectionCard()
  }

  @Builder
  fontCard() {
    Column({ space: 20 }) {
      this.heading('字体与阅读', '应用字号和聊天排版集中在这里，历史消息与生成中的文字同步生效。')
      Text('故事，从一行字开始。').fontSize(22).fontWeight(FontWeight.Medium).fontColor(this.uiColors.textPrimary).width('100%')
      Text('月光落在纸上，远方的故事缓缓展开。\nHarmonyTavern · 0123456789')
        .fontSize(this.readingSize).fontFamily(ReadingPreferences.fontFamily(this.readingFont))
        .fontColor(this.uiColors.textSecondary).lineHeight(this.readingSize * this.readingLine)
        .width('100%').padding({ left: this.readingInset, right: this.readingInset })
      Divider().color(this.uiColors.borderSubtle)
      Text(`字号大小 · ${Math.round(this.fontScale * 100)}%`).fontSize(15).fontColor(this.uiColors.accent).width('100%')
      Slider({ value: this.fontScale, min: 0.85, max: 1.3, step: 0.05 })
        .width('100%').selectedColor(this.uiColors.accent).blockColor(this.uiColors.accent)
        .trackColor(this.uiColors.bgSurfaceHigh).accessibilityText('应用字号大小')
        .onChange((value: number, mode: SliderChangeMode) => {
          if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
            this.settingError = DisplayPreferences.setFontScale(value) ? '' : '字号未能更新，请重试。';
          }
        })
      Button('恢复标准字号', { type: ButtonType.Normal }).width('100%').height(44).fontColor(this.uiColors.accent).backgroundColor(this.uiColors.accentContainer)
        .onClick(() => { this.settingError = DisplayPreferences.setFontScale(1) ? '' : '字号未能更新，请重试。'; })
    .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      Divider().color(this.uiColors.borderSubtle)
      SettingsPicker({ title: '聊天字体', marker: 'reading-font', selectedId: this.readingFont,
        options: [{ id: 'system', label: '系统字体', detail: '跟随系统默认字形' },
          { id: 'serif', label: '衬线字体', detail: '使用设备可用的衬线字形，缺失字符由系统补齐' },
          { id: 'monospace', label: '等宽字体', detail: '适合数字、代码与整齐的文字排列' }],
        onSelect: (id: string): void => { PersonalizationStore.set(READING_FONT_KEY, id); } })
      Text('聊天字号 · ' + this.readingSize + ' sp').fontSize(15).fontColor(this.uiColors.accent).width('100%')
      Slider({ value: this.readingSize, min: 13, max: 22, step: 1 }).width('100%')
        .selectedColor(this.uiColors.accent).blockColor(this.uiColors.accent).trackColor(this.uiColors.bgSurfaceHigh)
        .accessibilityText('聊天字号').id('reading-size')
        .onChange((value: number, mode: SliderChangeMode): void => {
          if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) { ReadingPreferences.setNumber(READING_SIZE_KEY, value); }
        })
      Text('行距 · ' + this.readingLine.toFixed(1) + ' 倍').fontSize(15).fontColor(this.uiColors.accent).width('100%')
      Slider({ value: this.readingLine, min: 1.5, max: 2.4, step: 0.1 }).width('100%')
        .selectedColor(this.uiColors.accent).blockColor(this.uiColors.accent).trackColor(this.uiColors.bgSurfaceHigh)
        .accessibilityText('聊天行距').id('reading-line-height')
        .onChange((value: number, mode: SliderChangeMode): void => {
          if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) { ReadingPreferences.setNumber(READING_LINE_KEY, value); }
        })
      Text('正文左右留白 · ' + this.readingInset + ' vp').fontSize(15).fontColor(this.uiColors.accent).width('100%')
      Slider({ value: this.readingInset, min: 8, max: 24, step: 2 }).width('100%')
        .selectedColor(this.uiColors.accent).blockColor(this.uiColors.accent).trackColor(this.uiColors.bgSurfaceHigh)
        .accessibilityText('正文左右留白，越小每行容纳的文字越多').id('reading-inset')
        .onChange((value: number, mode: SliderChangeMode): void => {
          if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) { ReadingPreferences.setNumber(READING_INSET_KEY, value); }
        })
      Button('恢复默认聊天排版').attributeModifier(new ActionButtonStyle(this.uiColors)).width('100%')
        .onClick((): void => { ReadingPreferences.reset(); })
      }
    .sectionCard()
  }

  @Builder
  topBar() {
    PageHeader({ title: '显示与外观', subtitle: '主题、阅读与玻璃质感',
      onBack: () => ROOT_PATH_STACK.pop() })
  }

  @Builder
  sectionContent() {
    Column({ space: 20 }) {
      if (this.displayedSection === 0) {
        this.preview()
        this.backgroundCard()
      } else if (this.displayedSection === 1) {
        this.displayCard()
      } else if (this.displayedSection === 2) {
        this.fontCard()
      } else if (this.displayedSection === 3) {
        this.glassCard()
      } else if (this.displayedSection === 4) {
        this.motionCard()
      } else if (this.displayedSection === 5) {
        this.holdingCard()
      }
      CustomColorEditor()
        .visibility(this.displayedSection === 0 && this.showCustom ? Visibility.Visible : Visibility.None)
        .accessibilityLevel(this.displayedSection === 0 && this.showCustom ? 'auto' : 'no-hide-descendants')
      if (this.settingError !== '') {
        Text(this.settingError).fontSize(13).fontColor(this.uiColors.danger).width('100%')
      }
    }
    .width('100%').padding({ bottom: 16 })
  }

  @Builder
  content() {
    Column({ space: 20 }) {
      JellyTabBar({ items: SECTIONS, currentIndex: this.activeSection, textOnly: true,
        onSelect: (index: number): void => { this.activeSection = index; this.settingError = ''; } })
      SwingContent({ activeIndex: this.activeSection,
        onDisplay: (index: number): void => { this.displayedSection = index; },
        content: (): void => { this.sectionContent(); } })
      Button('恢复默认显示与外观', { type: ButtonType.Normal }).width('100%').height(48).fontSize(15)
        .fontColor(this.uiColors.accent).backgroundColor(this.uiColors.accentContainer)
        .onClick(() => { this.resetAppearance(); })
    .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      }
    .width('100%')
  }

  build() {
    PageSurface({ topBar: () => { this.topBar(); }, content: () => { this.content(); } })
  }
}
