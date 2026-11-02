import { SurfaceStyle } from '../theme/SurfaceStyles';
import { iconTint } from '../theme/IconTint';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { Radius } from '../theme/Tokens';

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
export struct GridEntryCard {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @Prop label: string = '';
  @Prop detail: string = '';
  @Prop icon: Resource = $r('app.media.nav_space');
  onTap: () => void = (): void => {};

  build() {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 14 }) {
        Image(this.icon)
          .width(22)
          .height(22)
          .colorFilter(iconTint(this.uiColors.accent))
          .padding(11)
          .size({ width: 44, height: 44 })
          .backgroundColor(this.uiColors.accentContainer)
          .borderRadius(15)
          .accessibilityLevel('no')
        Column({ space: 4 }) {
          Text(this.label)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.uiColors.textPrimary)
          if (this.detail !== '') {
            Text(this.detail)
              .fontSize(12)
              .fontColor(this.uiColors.textSecondary)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Image($r('app.media.icon_chevron'))
          .width(16)
          .height(16)
          .colorFilter(iconTint(this.uiColors.textTertiary))
          .accessibilityLevel('no')
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .constraintSize({ minHeight: 80 })
    .backgroundColor(this.uiColors.bgSurface)
    .borderRadius(Radius.md)
    .attributeModifier(new SurfaceStyle(this.uiColors, Radius.md))
    .accessibilityText(this.label + '，' + this.detail)
    .stateStyles({ normal: touchFeedbackNormal, pressed: touchFeedbackPressed })
    .onClick(() => this.onTap())
  }
}
