import { NativeGlassBackdrop } from './NativeGlassBackdrop';
import { SystemGlass } from '../theme/SystemGlass';
import { iconTint } from '../theme/IconTint';
import { COLORS, ColorTokens } from '../theme/Tokens';
import { GLASS_HEADER_BUTTON, glassEffect, glassLightColor } from '../theme/Glass';
import { LS_BLUR_DEFAULT, LS_BLUR_KEY } from '../theme/LightSense';
import { IMMERSIVE_DEFAULT, IMMERSIVE_KEY } from '../theme/Immersive';

@Styles
function actionNormal() { .opacity(1) }
@Styles
function actionPressed() { .opacity(0.68) }

/** Shared toolbar action: immediate press, short refresh turn, real pending state. */
@Component
export struct HeaderAction {
  @StorageProp('systemMaterialAvailable') nativeAvailable: boolean = false;
  @StorageProp('liquidPressedSource') @Watch('squeezeChanged') liquidPressedSource: string = '';
  @StorageProp('liquidSourceSqueezed') @Watch('squeezeChanged') sourceSqueezed: boolean = false;
  @Prop symbol: string = '';
  @StorageProp('uiColors') colors: ColorTokens = COLORS;
  @StorageProp(LS_BLUR_KEY) blurRadius: number = LS_BLUR_DEFAULT;
  @StorageProp(IMMERSIVE_KEY) immersiveLevel: number = IMMERSIVE_DEFAULT;
  @StorageProp('reduceMotion') @Watch('squeezeChanged') reduceMotion: boolean = false;
  @Prop icon: Resource = $r('app.media.icon_refresh');
  @Prop label: string = '刷新';
  @Prop marker: string = '';
  @Prop available: boolean = true;
  @Prop pending: boolean = false;
  @Prop refresh: boolean = true;
  @State running: boolean = false;
  @State angle: number = 0;
  @State pressScale: number = 1;
  @State squeeze: number = 0;
  private alive: boolean = true;
  onAction: () => Promise<void> = async (): Promise<void> => {};

  aboutToAppear(): void { this.alive = true; }
  aboutToDisappear(): void { this.alive = false; }
  private touchChanged(event: TouchEvent): void {
    if (event.type === TouchType.Move) { return; }
    const pressed: boolean = event.type === TouchType.Down;
    this.getUIContext().animateTo({ duration: pressed || this.reduceMotion ? 0 : 100,
      curve: Curve.EaseOut }, (): void => {
      this.pressScale = pressed && !this.reduceMotion ? 0.94 : 1;
    });
  }
  private squeezeChanged(): void {
    const active: boolean = this.marker !== '' && this.liquidPressedSource === this.marker &&
      this.sourceSqueezed && !this.reduceMotion;
    this.getUIContext().animateTo({ duration: this.reduceMotion ? 0 : (active ? 70 : 160),
      curve: Curve.EaseOut }, (): void => {
      this.squeeze = active ? 1 : 0;
      if (this.reduceMotion) { this.pressScale = 1; }
    });
  }
  private async activate(): Promise<void> {
    if (!this.available || this.pending || this.running) { return; }
    this.running = true;
    if (this.refresh && !this.reduceMotion) {
      this.getUIContext().animateTo({ duration: 320, curve: Curve.EaseOut }, (): void => { this.angle += 360; });
    }
    try { await this.onAction(); }
    catch (error) {
      if (this.alive) { this.getUIContext().getPromptAction().showToast({ message: (error as Error).message }); }
    } finally { if (this.alive) { this.running = false; } }
  }
  private nativeSurface(): boolean {
    return this.nativeAvailable && this.blurRadius > 0 && SystemGlass.supported();
  }
  build() {
    Button({ type: ButtonType.Circle }) {
      Stack() {
        if (this.nativeSurface()) { NativeGlassBackdrop({ diameter: 44, radius: 22 }) }
        if (this.symbol !== '') {
          Text(this.symbol).fontSize(26).fontColor(this.colors.textPrimary)
            .opacity(this.running || this.pending ? 0 : 1)
        } else {
          Image(this.icon).width(22).height(22).colorFilter(iconTint(this.colors.textPrimary))
            .rotate({ angle: this.angle }).opacity(this.running || this.pending ? 0 : 1)
        }
        if (this.running || this.pending) { LoadingProgress().width(22).height(22).color(this.colors.accent) }
      }.width(44).height(44)
      .scale({ x: this.pressScale, y: this.pressScale })
    }
    .width(44).height(44).padding(0).borderRadius(22)
    .backgroundColor(Color.Transparent)
    .backgroundEffect(this.nativeSurface() ? { radius: 0, color: Color.Transparent } : glassEffect(GLASS_HEADER_BUTTON, this.blurRadius, this.immersiveLevel, this.colors))
    .linearGradient({ angle: 145, colors: [[this.nativeSurface() ? this.colors.clear : glassLightColor(this.colors.highlight, 0.16), 0],
      [this.colors.clear, 0.45], [this.nativeSurface() ? this.colors.clear : glassLightColor(this.colors.reflection, 0.12), 1]] })
    .border({ radius: 22, width: this.nativeSurface() ? 0 : 0.8, color: this.colors.glassEdge }).clip(true)
    .stateStyles({ normal: actionNormal, pressed: actionPressed })
    .scale({ x: 1 + this.squeeze * 0.06, y: 1 - this.squeeze * 0.1 })
    .focusOnTouch(false).enabled(this.available && !this.running && !this.pending)
    .id(this.marker).accessibilityText(this.running || this.pending ? this.label + '中' : this.label)
    .onTouch((event: TouchEvent): void => { this.touchChanged(event); })
    .onClick((): void => { this.activate(); })
  }
}
