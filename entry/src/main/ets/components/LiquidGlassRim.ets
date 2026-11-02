import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { glassLightColor } from '../theme/Glass';
import { LS_BLUR_DEFAULT, LS_BLUR_KEY } from '../theme/LightSense';
import { IMMERSIVE_DEFAULT, IMMERSIVE_KEY, Immersive } from '../theme/Immersive';

/** Small live backdrop samples form a curved rim; foreground labels stay outside this layer. */
@Component
export struct LiquidGlassRim {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @StorageProp(LS_BLUR_KEY) blurRadius: number = LS_BLUR_DEFAULT;
  @StorageProp(IMMERSIVE_KEY) immersiveLevel: number = IMMERSIVE_DEFAULT;
  @Prop pressed: boolean = false;
  @Prop compact: boolean = false;

  private rimEffect(): BackgroundEffectOptions {
    return { radius: this.blurRadius > 0 ? 3 : 0,
      saturation: this.blurRadius > 0 ? 1.55 : 1,
      brightness: 1.02, color: this.uiColors.clear,
      policy: BlurStyleActivePolicy.FOLLOWS_WINDOW_ACTIVE_STATE,
      inactiveColor: this.uiColors.bgSurface };
  }

  build() {
    Stack() {
      Row() {
        Column()
          .width(this.compact ? 7 : 11).height('100%')
          .backgroundEffect(this.rimEffect()).opacity(0.28)
          .linearGradient({ angle: 90, colors: [
            [glassLightColor(this.uiColors.highlight, 0.5), 0],
            [glassLightColor(this.uiColors.highlight, 0.08), 0.45], [this.uiColors.clear, 1]] })
          .borderRadius(28).clip(true)
          .scale({ x: this.pressed ? 1.16 : 1.08, y: 0.94 })
          .translate({ x: this.pressed ? 2 : 1 })
        Blank()
        Column()
          .width(this.compact ? 7 : 11).height('100%')
          .backgroundEffect(this.rimEffect()).opacity(0.28)
          .linearGradient({ angle: 270, colors: [
            [glassLightColor(this.uiColors.reflection, 0.65), 0],
            [glassLightColor(this.uiColors.highlight, 0.16), 0.45], [this.uiColors.clear, 1]] })
          .borderRadius(28).clip(true)
          .scale({ x: this.pressed ? 1.16 : 1.08, y: 0.94 })
          .translate({ x: this.pressed ? -2 : -1 })
      }.width('100%').height('100%')
      Column()
        .width('100%').height('100%')
        .linearGradient({ angle: this.pressed ? 125 : 145, colors: [
          [glassLightColor(this.uiColors.highlight, 0.62), 0],
          [this.uiColors.clear, 0.22], [this.uiColors.clear, 0.72],
          [glassLightColor(this.uiColors.reflection, 0.48), 1]] })
        .border({ radius: 28, width: 0.65, color: glassLightColor(this.uiColors.highlight, 0.45) })
    }
    .width('100%').height('100%')
    .opacity(this.blurRadius > 0 ? Math.min(0.9, 0.52 + Immersive.presetOf(this.immersiveLevel).haloAlpha * 1.6) : 0)
    .borderRadius(28).clip(true)
    .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
  }
}
