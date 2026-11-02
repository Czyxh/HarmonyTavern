import { curves, FrameNode, UIContext } from '@kit.ArkUI';
import { MotionPolicy } from './Motion';

export class MotionOrigin {
  left: number = 0;
  top: number = 0;
  width: number = 44;
  height: number = 44;
  valid: boolean = false;
}

export class OriginMotion {
  static capture(context: UIContext, sourceId: string, fallback: MotionOrigin = new MotionOrigin()): MotionOrigin {
    return OriginMotion.measure(context, sourceId, fallback, false);
  }

  static captureOnScreen(context: UIContext, sourceId: string,
    fallback: MotionOrigin = new MotionOrigin()): MotionOrigin {
    return OriginMotion.measure(context, sourceId, fallback, true);
  }

  private static measure(context: UIContext, sourceId: string, fallback: MotionOrigin,
    screenCoordinates: boolean): MotionOrigin {
    try {
      const node: FrameNode | null = context.getFrameNodeById(sourceId);
      if (node === null) { return fallback; }
      const position = screenCoordinates ? node.getPositionToScreenWithTransform() :
        node.getPositionToWindowWithTransform();
      const size = node.getMeasuredSize();
      const origin: MotionOrigin = new MotionOrigin();
      origin.left = position.x;
      origin.top = position.y;
      origin.width = context.px2vp(size.width);
      origin.height = context.px2vp(size.height);
      origin.valid = origin.width > 0 && origin.height > 0 && Number.isFinite(origin.width) &&
        Number.isFinite(origin.height) && Number.isFinite(origin.left) && Number.isFinite(origin.top);
      return origin.valid ? origin : fallback;
    } catch (error) {
      return fallback;
    }
  }

  static dialog(context: UIContext, sourceId: string): TransitionEffect {
    if (MotionPolicy.isReduceMotion()) { return TransitionEffect.IDENTITY; }
    const origin: MotionOrigin = OriginMotion.capture(context, sourceId);
    if (!origin.valid) { return TransitionEffect.scale({ x: 0.94, y: 0.94 }).animation({ duration: 160 }); }
    const width: number = AppStorage.get<number>('appWindowWidth') ?? 0;
    const height: number = AppStorage.get<number>('appWindowHeight') ?? 0;
    return TransitionEffect.scale({ x: 0.04, y: 0.04 })
      .combine(TransitionEffect.translate({ x: origin.left + origin.width / 2 - width / 2,
        y: origin.top + origin.height / 2 - height / 2 }))
      .animation({ curve: curves.springMotion(0.38, 0.9) });
  }
}

export type OriginPanelMotion = 'orb' | 'bottom';

@Observed
export class OriginPanelState {
  private static pulseRevision: number = 0;
  presented: boolean = false;
  opened: boolean = false;
  sourceId: string = '';
  origin: MotionOrigin = new MotionOrigin();
  heightRatio: number = 0.75;
  contentHeight: number = 0;
  motion: OriginPanelMotion = 'orb';
  compact: boolean = false;
  menuHeight: number = 304;
  menuWidth: number = 224;
  private pendingAction: (() => void) | undefined = undefined;

  open(context: UIContext, sourceId: string, heightRatio: number = 0.75,
    motion: OriginPanelMotion = 'orb'): void {
    this.pendingAction = undefined;
    this.sourceId = sourceId;
    this.origin = OriginMotion.captureOnScreen(context, sourceId);
    const pulseRevision: number = ++OriginPanelState.pulseRevision;
    AppStorage.setOrCreate('liquidPressedSource', sourceId);
    AppStorage.setOrCreate('liquidSourceSqueezed', !MotionPolicy.isReduceMotion() && motion === 'orb');
    setTimeout((): void => {
      if (pulseRevision === OriginPanelState.pulseRevision) {
        AppStorage.setOrCreate('liquidSourceSqueezed', false);
      }
    }, 140);
    this.heightRatio = heightRatio;
    if (!this.presented) { this.contentHeight = 0; }
    this.motion = motion;
    this.compact = false;
    this.opened = true;
    this.presented = true;
  }

  close(): void { this.opened = false; }

  toggle(): void {
    this.pendingAction = undefined;
    this.opened = !this.opened;
  }

  openMenu(context: UIContext, sourceId: string, height: number, labels: string[] = []): void {
    this.open(context, sourceId);
    this.compact = true;
    this.menuHeight = height;
    this.fitMenuWidth(context, labels);
  }

  fitMenuWidth(context: UIContext, labels: string[]): void {
    let width: number = labels.length > 0 ? 176 : 224;
    for (const label of labels) {
      const measured: number = context.getMeasureUtils().measureText({ textContent: label, fontSize: '15fp' });
      width = Math.max(width, context.px2vp(measured) + 48);
    }
    this.menuWidth = Math.min(320, Math.ceil(width));
  }

  fitContentHeight(height: number): void {
    if (!this.compact && Number.isFinite(height) && height > 0 && Math.abs(this.contentHeight - height) > 0.5) {
      this.contentHeight = height;
    }
  }

  fitMenuHeight(height: number): void {
    if (this.compact && Number.isFinite(height) && height > 0 && Math.abs(this.menuHeight - height) > 0.5) {
      this.menuHeight = height;
    }
  }

  select(action: () => void): void {
    if (!this.opened) { return; }
    this.pendingAction = action;
    this.close();
  }

  dismissed(): void {
    const action: (() => void) | undefined = this.pendingAction;
    this.pendingAction = undefined;
    if (action !== undefined) { action(); }
  }
}
