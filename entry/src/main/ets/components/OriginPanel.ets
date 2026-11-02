import { curves, FrameCallback } from '@kit.ArkUI';
import { OriginMotion, OriginPanelState, MotionOrigin } from '../theme/OriginMotion';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { glassLightColor, frostedEffect } from '../theme/Glass';
import { LS_BLUR_DEFAULT, LS_BLUR_KEY } from '../theme/LightSense';
import { MOTION_REDUCE_KEY } from '../theme/Motion';
import { LiquidContour, LiquidVector } from '../theme/LiquidContour';
import { LiquidSurface } from '../theme/LiquidSurface';

@AnimatableExtend(Stack)
function liquidPanelFrame(frame: LiquidVector) {
  .position({ x: LiquidSurface.body(frame).left, y: LiquidSurface.body(frame).top })
  .width(LiquidSurface.body(frame).width).height(LiquidSurface.body(frame).height)
  .borderRadius(LiquidContour.radius(LiquidSurface.body(frame).width, LiquidSurface.body(frame).height, frame.values[4]))
  .clip(true)
  .clipShape(new Path().commands(LiquidSurface.bodyPath(frame)))
}

class OriginFrame extends FrameCallback {
  private action: () => void;
  constructor(action: () => void) { super(); this.action = action; }
  onFrame(_frameTime: number): void { this.action(); }
}

@Component
export struct OriginPanel {
  @ObjectLink @Watch('intentChanged') state: OriginPanelState;
  @BuilderParam content: () => void;
  @Prop preventClose: boolean = false;
  onClosed: () => void = (): void => {};
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @StorageProp(LS_BLUR_KEY) blurRadius: number = LS_BLUR_DEFAULT;
  @StorageProp(MOTION_REDUCE_KEY) @Watch('motionChanged') reduceMotion: boolean = false;
  @StorageProp('systemTopInset') topInset: number = 0;
  @StorageProp('systemBottomInset') safeBottom: number = 0;
  @StorageProp('systemKeyboardTop') @Watch('layoutChanged') keyboardTop: number = 0;
  @StorageProp('appWindowHeight') @Watch('layoutChanged') windowHeight: number = 0;
  @StorageProp('appWindowWidth') @Watch('layoutChanged') windowWidth: number = 0;
  @State leftVp: number = 0;
  @State topVp: number = 0;
  @State widthVp: number = 44;
  @State heightVp: number = 44;
  @State roundness: number = 1;
  @State sourceLeft: number = 0;
  @State sourceTop: number = 0;
  @State sourceWidth: number = 44;
  @State sourceHeight: number = 44;
  @State contentAlpha: number = 0;
  @State maskAlpha: number = 0;
  @State ready: boolean = false;
  @State contentWidth: number = 1;
  @State contentHeight: number = 1;
  private host: MotionOrigin = new MotionOrigin();
  private hostWindowTop: number = 0;
  private revision: number = 0;
  private mounted: boolean = false;
  private lastIntent: boolean = false;
  private lastContentHeight: number = 0;
  private lastMenuHeight: number = 304;
  private lastMenuWidth: number = 224;
  private expansionStarted: boolean = false;
  private expanded: boolean = false;

  private hostId(): string { return 'origin-panel-host-' + this.state.sourceId; }

  private frame(): LiquidVector {
    return new LiquidVector([this.leftVp, this.topVp, this.widthVp, this.heightVp, this.roundness,
      this.sourceLeft, this.sourceTop, this.sourceWidth, this.sourceHeight, this.getUIContext().vp2px(1),
      this.state.motion === 'orb' ? 1 : 0]);
  }

  private measureHost(): boolean {
    const host: MotionOrigin = OriginMotion.captureOnScreen(this.getUIContext(), this.hostId());
    if (!host.valid) { return false; }
    this.host = host;
    this.hostWindowTop = OriginMotion.capture(this.getUIContext(), this.hostId()).top;
    return true;
  }

  private source(): MotionOrigin {
    // Opening uses the pre-press bounds; decorative source deformation must not move the anchor.
    const captured: MotionOrigin = this.state.opened ? this.state.origin :
      OriginMotion.captureOnScreen(this.getUIContext(), this.state.sourceId, this.state.origin);
    const local: MotionOrigin = new MotionOrigin();
    local.left = captured.left - this.host.left;
    local.top = captured.top - this.host.top;
    local.width = captured.width;
    local.height = captured.height;
    local.valid = captured.valid;
    return local;
  }

  private growsDown(source: MotionOrigin): boolean {
    return source.top + source.height / 2 < this.host.height / 2;
  }

  private target(): MotionOrigin {
    const target: MotionOrigin = new MotionOrigin();
    const top: number = Math.max(0, this.topInset - this.hostWindowTop) + 12;
    const windowBottom: number = this.keyboardTop > 0 ? this.keyboardTop : this.windowHeight - this.safeBottom;
    const bottom: number = Math.min(this.host.height, windowBottom - this.hostWindowTop) - 12;
    target.width = Math.max(1, Math.min(this.state.compact ? this.state.menuWidth : 720, this.host.width - 24));
    const heightLimit: number = Math.max(1, Math.min(
      (this.windowHeight - this.topInset - this.safeBottom) * this.state.heightRatio, bottom - top));
    target.height = this.state.compact ? Math.max(1, Math.min(this.state.menuHeight, bottom - top)) :
      Math.max(1, Math.min(heightLimit, this.state.contentHeight > 0 ? this.state.contentHeight : heightLimit));
    target.left = Math.max(0, (this.host.width - target.width) / 2);
    target.top = Math.max(top, bottom - target.height);
    if (this.state.motion === 'orb') {
      const source: MotionOrigin = this.source();
      if (source.valid) {
        if (this.state.compact) {
          target.left = Math.max(12, Math.min(this.host.width - target.width - 12,
            source.left + source.width / 2 - (source.left < this.host.width / 2 ? 26 : target.width - 26)));
        }
        const preferred: number = this.growsDown(source) ? source.top + source.height + 10 :
          source.top - target.height - 10;
        target.top = Math.max(top, Math.min(bottom - target.height, preferred));
      }
    }
    target.valid = true;
    return target;
  }

  private collapsed(): MotionOrigin {
    const source: MotionOrigin = this.source();
    if (this.state.motion === 'orb' && source.valid) {
      const seed: MotionOrigin = new MotionOrigin();
      seed.left = source.left + source.width / 2;
      seed.top = this.growsDown(source) ? source.top + source.height : source.top;
      seed.width = 0;
      seed.height = 0;
      seed.valid = true;
      return seed;
    }
    const frame: MotionOrigin = this.target();
    frame.top = this.host.height + 12;
    return frame;
  }

  private setFrame(frame: MotionOrigin, expanded: boolean): void {
    this.leftVp = frame.left;
    this.topVp = frame.top;
    this.widthVp = frame.width;
    this.heightVp = frame.height;
    this.roundness = expanded || this.state.motion === 'bottom' ? 0 : 1;
  }

  private updateSource(): void {
    const source: MotionOrigin = this.source();
    this.sourceLeft = source.left;
    this.sourceTop = source.top;
    this.sourceWidth = source.width;
    this.sourceHeight = source.height;
  }

  private prepareContent(): void {
    const target: MotionOrigin = this.target();
    this.contentWidth = target.width;
    this.contentHeight = target.height;
  }

  aboutToAppear(): void { this.lastIntent = this.state.opened; }

  aboutToDisappear(): void {
    this.mounted = false;
    this.revision++;
    if (!this.state.opened && this.state.sourceId !== '') {
      try { this.getUIContext().getFocusController().requestFocus(this.state.sourceId); }
      catch (error) { return; }
    }
  }

  private intentChanged(): void {
    if (!this.mounted) { return; }
    if (this.lastContentHeight !== this.state.contentHeight) {
      this.lastContentHeight = this.state.contentHeight;
      if (this.ready && this.state.opened && !this.state.compact) { this.layoutChanged(); }
    }
    if (this.lastMenuHeight !== this.state.menuHeight || this.lastMenuWidth !== this.state.menuWidth) {
      this.lastMenuHeight = this.state.menuHeight;
      this.lastMenuWidth = this.state.menuWidth;
      if (this.ready && this.state.opened && this.state.compact) { this.layoutChanged(); }
    }
    if (this.lastIntent === this.state.opened) { return; }
    this.lastIntent = this.state.opened;
    if (this.ready) { this.queueMotion(); }
  }

  private motionChanged(): void { if (this.mounted && this.ready) { this.queueMotion(); } }

  private layoutChanged(): void {
    if (!this.mounted || !this.ready) { return; }
    if (!this.state.opened || !this.expanded) { this.queueMotion(); return; }
    this.getUIContext().postFrameCallback(new OriginFrame((): void => {
      if (!this.mounted || !this.state.opened || !this.expanded) { return; }
      this.measureHost();
      this.getUIContext().animateTo({ duration: this.reduceMotion ? 0 : 180, curve: Curve.EaseOut }, (): void => {
        this.prepareContent();
        this.setFrame(this.target(), true);
      });
    }));
  }

  private current(revision: number): boolean { return this.mounted && revision === this.revision; }

  private finishClose(revision: number): void {
    if (!this.current(revision) || this.state.opened) { return; }
    this.getUIContext().getFocusController().clearFocus();
    this.state.presented = false;
    this.onClosed();
  }

  private reveal(opening: boolean): void {
    this.getUIContext().animateTo({ duration: this.reduceMotion ? 0 : (opening ? 160 : 80),
      delay: this.reduceMotion || !opening || this.state.motion === 'bottom' ? 0 : 70,
      curve: Curve.EaseOut }, (): void => {
      this.contentAlpha = this.state.motion === 'bottom' ? 1 : (opening ? 1 : 0);
      this.maskAlpha = opening ? 1 : 0;
    });
  }

  private expand(revision: number): void {
    if (!this.current(revision) || !this.state.opened) { return; }
    this.reveal(true);
    this.getUIContext().animateTo({ curve: curves.springMotion(0.32, 0.9), onFinish: (): void => {
      if (this.current(revision) && this.state.opened) {
        this.expanded = true;
      }
    } }, (): void => { this.setFrame(this.target(), true); });
  }

  private runMotion(revision: number): void {
    if (!this.current(revision)) { return; }
    this.measureHost();
    this.updateSource();
    const opening: boolean = this.state.opened;
    if (!opening && !this.expansionStarted) { this.finishClose(revision); return; }
    if (this.reduceMotion) {
      this.prepareContent();
      this.getUIContext().animateTo({ duration: 0 }, (): void => {
        this.setFrame(this.target(), true);
        this.contentAlpha = opening ? 1 : 0;
        this.maskAlpha = opening ? 1 : 0;
      });
      this.expanded = opening;
      this.expansionStarted = opening;
      if (!opening) { this.finishClose(revision); }
      return;
    }
    this.expanded = false;
    if (opening) {
      this.prepareContent();
      this.expansionStarted = true;
      this.expand(revision);
      return;
    }
    this.reveal(false);
    if (this.state.motion === 'bottom' || !this.source().valid) {
      this.getUIContext().animateTo({ duration: 240, curve: curves.cubicBezierCurve(0.4, 0, 0.8, 0.4),
        onFinish: (): void => { this.finishClose(revision); }
      }, (): void => { this.setFrame(this.collapsed(), true); });
      return;
    }
    this.getUIContext().animateTo({ curve: curves.springMotion(0.28, 0.95),
      onFinish: (): void => { this.finishClose(revision); }
    }, (): void => { this.setFrame(this.collapsed(), false); });
  }

  private queueMotion(): void {
    const revision: number = ++this.revision;
    this.getUIContext().postFrameCallback(new OriginFrame((): void => { this.runMotion(revision); }));
  }

  private initialize(): void {
    if (!this.mounted || this.ready || !this.measureHost()) { return; }
    this.prepareContent();
    this.updateSource();
    this.setFrame(this.reduceMotion ? this.target() : this.collapsed(), this.reduceMotion);
    this.ready = true;
    this.queueMotion();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%').height('100%')
        .backgroundColor(glassLightColor(this.uiColors.textPrimary, this.state.compact ? 0.07 : 0.14)).opacity(this.maskAlpha)
        .accessibilityText('关闭面板')
        .onClick((): void => { if (!this.preventClose) { this.state.close(); } })
      Stack() {}
      .backgroundEffect(frostedEffect(this.blurRadius, this.uiColors))
      .border({ width: 0.65, color: this.uiColors.glassEdge })
      .liquidPanelFrame(this.frame())
      .visibility(this.ready ? Visibility.Visible : Visibility.Hidden)
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
      Stack({ alignContent: Alignment.TopStart }) {
        Column() { this.content() }
          .width(this.contentWidth).height(this.contentHeight)
          .opacity(this.contentAlpha)
      }
      .id('origin-panel-surface')
      .liquidPanelFrame(this.frame())
      .visibility(this.ready ? Visibility.Visible : Visibility.Hidden)
      .hitTestBehavior(this.state.opened ? HitTestMode.Default : HitTestMode.Block)
      .onClick((): void => {})
      // The modal cover owns input. Keep the source reachable above its mask,
      // including while the panel is opening or returning to the source.
      if (this.ready && this.state.motion === 'orb' && this.state.origin.valid) {
        Button({ type: ButtonType.Circle }) {}
          .width(this.sourceWidth).height(this.sourceHeight)
          .position({ x: this.sourceLeft, y: this.sourceTop })
          .backgroundColor(Color.Transparent)
          .focusOnTouch(false)
          .accessibilityText(this.state.opened ? '收回菜单' : '展开菜单')
          .id('origin-source-toggle')
          .onClick((): void => { if (!this.preventClose) { this.state.toggle(); } })
      }
    }
    .id(this.hostId())
    .width('100%').height('100%')
    .backgroundColor(Color.Transparent)
    .onAppear((): void => {
      this.mounted = true;
      this.lastIntent = this.state.opened;
      this.getUIContext().postFrameCallback(new OriginFrame((): void => { this.initialize(); }));
    })
    .onAreaChange((): void => {
      if (!this.ready) { this.initialize(); }
      else { this.layoutChanged(); }
    })
    .onDisAppear((): void => { this.mounted = false; this.revision++; })
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}
