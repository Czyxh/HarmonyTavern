import { ColorTokens } from './Tokens';
import { RpgThemes } from './RpgThemes';
import { GLASS_HEADER_BUTTON, glassEffect, glassLightColor } from './Glass';

export enum ActionTone { Normal, Primary, Danger, Selected, Warning }

/** Shared form controls. Blur stays on their containing surface, not every button. */
export class ActionButtonStyle implements AttributeModifier<ButtonAttribute> {
  private colors: ColorTokens;
  private tone: ActionTone;
  private menu: boolean;
  constructor(colors: ColorTokens, tone: ActionTone = ActionTone.Normal, menu: boolean = false) {
    this.colors = colors; this.tone = tone; this.menu = menu;
  }
  applyNormalAttribute(button: ButtonAttribute): void {
    const radius: number = RpgThemes.radius(16);
    const danger: boolean = this.tone === ActionTone.Danger;
    const accent: boolean = this.tone === ActionTone.Primary || this.tone === ActionTone.Selected;
    const warning: boolean = this.tone === ActionTone.Warning;
    button.height(this.menu ? 48 : 44).borderRadius(16).fontSize(14)
      .fontWeight(this.tone === ActionTone.Selected ? FontWeight.Bold : FontWeight.Medium)
      .padding({ left: this.menu ? 16 : 10, right: this.menu ? 16 : 10 }).opacity(1).stateEffect(true)
      .labelStyle({ overflow: TextOverflow.Ellipsis, maxLines: 2 })
      .backgroundColor(danger ? this.colors.dangerContainer :
        (accent ? this.colors.accentContainer : (this.menu ? this.colors.clear : this.colors.headerButtonTint)))
      .linearGradient({ angle: 145, colors: [[glassLightColor(this.colors.highlight, this.menu ? 0 : 0.14), 0],
        [this.colors.clear, 0.5], [glassLightColor(this.colors.reflection, this.menu ? 0 : 0.16), 1]] })
      .fontColor(danger ? this.colors.danger : (warning ? this.colors.warning : (accent ? this.colors.accent : this.colors.textPrimary)))
      .border({ radius: radius, width: this.menu ? 0 : RpgThemes.borderWidth(0.8),
        color: danger ? this.colors.danger : (warning ? this.colors.warning : (this.tone === ActionTone.Selected ? this.colors.accent : glassLightColor(this.colors.glassEdge, 0.7))) })
      .borderRadius(radius).clip(true);
  }
  applyPressedAttribute(button: ButtonAttribute): void {
    button.opacity(0.68);
    if (this.menu) { button.backgroundColor(this.colors.headerButtonTint); }
  }
  applyFocusedAttribute(button: ButtonAttribute): void { button.border({ radius: RpgThemes.radius(16), width: 1.5, color: this.colors.accent }).borderRadius(RpgThemes.radius(16)); }
  applyDisabledAttribute(button: ButtonAttribute): void { button.opacity(0.45); }
}

export class OrbButtonStyle implements AttributeModifier<ButtonAttribute> {
  private colors: ColorTokens;
  private blur: number;
  private immersion: number;
  constructor(colors: ColorTokens, blur: number, immersion: number) {
    this.colors = colors; this.blur = blur; this.immersion = immersion;
  }
  applyNormalAttribute(button: ButtonAttribute): void {
    button.width(44).height(44).padding(0).borderRadius(22).opacity(1).stateEffect(true)
      .backgroundColor(Color.Transparent).backgroundEffect(glassEffect(GLASS_HEADER_BUTTON, this.blur, this.immersion, this.colors))
      .border({ radius: 22, width: 1, color: this.colors.glassEdge })
      .linearGradient({ angle: 145, colors: [[glassLightColor(this.colors.highlight, 0.16), 0], [this.colors.clear, 0.45],
        [glassLightColor(this.colors.reflection, 0.12), 1]] }).borderRadius(22).clip(true);
  }
  applyPressedAttribute(button: ButtonAttribute): void { button.opacity(0.68); }
  applyDisabledAttribute(button: ButtonAttribute): void { button.opacity(0.45); }
}

export class InputFieldStyle implements AttributeModifier<TextInputAttribute> {
  private colors: ColorTokens;
  constructor(colors: ColorTokens) { this.colors = colors; }
  applyNormalAttribute(field: TextInputAttribute): void {
    field.height(44).borderRadius(16).fontSize(14).padding({ left: 12, right: 12 })
      .fontColor(this.colors.textPrimary).placeholderColor(this.colors.textSecondary)
      .backgroundColor(glassLightColor(this.colors.headerButtonTint, 0.76))
      .border({ radius: 16, width: 0.65, color: glassLightColor(this.colors.glassEdge, 0.7) }).borderRadius(16);
  }
  applyFocusedAttribute(field: TextInputAttribute): void { field.border({ radius: 16, width: 1.5, color: this.colors.accent }).borderRadius(16); }
}

export class TextAreaFieldStyle implements AttributeModifier<TextAreaAttribute> {
  private colors: ColorTokens;
  constructor(colors: ColorTokens) { this.colors = colors; }
  applyNormalAttribute(field: TextAreaAttribute): void {
    field.borderRadius(16).fontSize(14).padding(12)
      .fontColor(this.colors.textPrimary).placeholderColor(this.colors.textSecondary)
      .backgroundColor(glassLightColor(this.colors.headerButtonTint, 0.76))
      .border({ radius: 16, width: 0.65, color: glassLightColor(this.colors.glassEdge, 0.7) }).borderRadius(16);
  }
  applyFocusedAttribute(field: TextAreaAttribute): void { field.border({ radius: 16, width: 1.5, color: this.colors.accent }).borderRadius(16); }
}
