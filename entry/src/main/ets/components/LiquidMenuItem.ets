import { ActionButtonStyle, ActionTone } from '../theme/ControlStyles';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';

// Immediate touch-down feedback; opacity also works with reduced motion.
@Styles
function touchFeedbackNormal() {
  .opacity(1)
}

@Styles
function touchFeedbackPressed() {
  .opacity(0.68)
}

@Component
export struct LiquidMenuItem {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @Prop label: string = '';
  @Prop available: boolean = true;
  @Prop destructive: boolean = false;
  onSelect: () => void = (): void => {};

  build() {
    Button({ type: ButtonType.Normal }) {
      Text(this.label)
        .fontSize(15)
        .fontColor(!this.available ? this.uiColors.textTertiary :
          (this.destructive ? this.uiColors.danger : this.uiColors.textPrimary))
        .width('100%').textAlign(TextAlign.Start)
    }
    .width('100%').height(48).padding({ left: 16, right: 16 })
    .borderRadius(18)
    .backgroundColor(this.destructive ? this.uiColors.dangerContainer : Color.Transparent)
    .enabled(this.available).focusOnTouch(false)
    .stateStyles({ normal: touchFeedbackNormal, pressed: touchFeedbackPressed })
    .attributeModifier(new ActionButtonStyle(this.uiColors, this.destructive ? ActionTone.Danger : ActionTone.Normal, true))
    .height('auto').constraintSize({ minHeight: 48 }).padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .onClick((): void => { this.onSelect(); })
  }
}
