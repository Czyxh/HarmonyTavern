import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { IMMERSIVE_DEFAULT, IMMERSIVE_KEY, Immersive } from '../theme/Immersive';
import { HOLDING_HAND_KEY, HOLDING_HAND_UNKNOWN, HOLDING_ENABLED_KEY, HOLDING_LIGHT_KEY, HoldingPose } from '../theme/HoldingPose';
import { MOTION_REDUCE_KEY } from '../theme/Motion';

@Component
export struct GlassLightField {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @StorageProp(IMMERSIVE_KEY) immersiveLevel: number = IMMERSIVE_DEFAULT;
  @StorageProp(HOLDING_HAND_KEY) @Watch('updateLight') holdingHand: number = HOLDING_HAND_UNKNOWN;
  @StorageProp(HOLDING_ENABLED_KEY) @Watch('updateLight') holdingEnabled: boolean = true;
  @StorageProp(HOLDING_LIGHT_KEY) @Watch('updateLight') holdingLight: boolean = true;
  @StorageProp(MOTION_REDUCE_KEY) @Watch('updateLight') reduceMotion: boolean = false;
  @Prop @Watch('updateLight') focusX: number = -1;
  @Prop pressed: boolean = false;
  @Prop spherical: boolean = false;
  @Prop clipToBounds: boolean = true;
  @Prop fullCoverage: boolean = false;
  @State lightPosition: number = 0.5;
  @State fieldWidth: number = 0;
  @State fieldHeight: number = 0;

  aboutToAppear(): void {
    this.lightPosition = this.targetPosition();
  }

  private targetPosition(): number {
    if (this.reduceMotion || this.fullCoverage) { return 0.5; }
    return this.focusX >= 0 ? Math.max(0.12, Math.min(0.88, this.focusX))
      : this.holdingEnabled && this.holdingLight ? HoldingPose.lightPosition(this.holdingHand) : 0.5;
  }

  private updateLight(): void {
    this.getUIContext().animateTo({ duration: this.reduceMotion ? 0 : 160, curve: Curve.EaseOut }, (): void => {
      this.lightPosition = this.targetPosition();
    });
  }

  private intensity(): number {
    return Math.min(1, Immersive.presetOf(this.immersiveLevel).haloAlpha * (this.pressed ? 6 : 4.5)) *
      (this.spherical ? 1 : 0.45);
  }

  private lightRadius(): number {
    return Math.max(1, Math.sqrt(this.fieldWidth * this.fieldWidth + this.fieldHeight * this.fieldHeight) *
      (this.fullCoverage ? 2 : 1));
  }

  build() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .linearGradient({ angle: 145, colors: [[this.uiColors.highlight, 0],
          [this.fullCoverage ? this.uiColors.highlight : this.uiColors.clear, 0.55], [this.uiColors.reflection, 1]] })
        .opacity(0.3)
      Column()
        .width('100%').height('100%')
        .radialGradient({
          center: [`${this.lightPosition * 100}%`, this.spherical ? '18%' : '0%'],
          radius: this.lightRadius(),
          colors: [[this.uiColors.highlight, 0], [this.uiColors.clear, 1]]
        })
      Column()
        .width('100%').height('100%')
        .radialGradient({
          center: [`${(1 - this.lightPosition) * 100}%`, '100%'],
          radius: this.lightRadius(),
          colors: [[this.uiColors.reflection, 0], [this.uiColors.clear, 1]]
        })
    }
    .width('100%').height('100%')
    .onAreaChange((_previous: Area, current: Area): void => {
      this.fieldWidth = Number(current.width);
      this.fieldHeight = Number(current.height);
    })
    .opacity(this.intensity())
    .borderRadius(this.spherical ? 26 : 28)
    .clip(this.clipToBounds)
    .hitTestBehavior(HitTestMode.None)
    .accessibilityLevel('no-hide-descendants')
  }
}
