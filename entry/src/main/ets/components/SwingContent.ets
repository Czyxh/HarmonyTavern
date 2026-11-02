import { curves, FrameCallback } from '@kit.ArkUI';
import { MOTION_REDUCE_KEY } from '../theme/Motion';

class SwingFrame extends FrameCallback {
  private action: () => void;

  constructor(action: () => void) {
    super();
    this.action = action;
  }

  onFrame(_frameTime: number): void { this.action(); }
}

@Component
export struct SwingContent {
  @Prop @Watch('selectionChanged') activeIndex: number = 0;
  @Prop fillHeight: boolean = false;
  @BuilderParam content: () => void;
  onDisplay: (index: number) => void = (_index: number): void => {};
  @StorageProp(MOTION_REDUCE_KEY) @Watch('motionChanged') reduceMotion: boolean = false;
  @State swingOffset: number = 0;
  @State angle: number = 0;
  @State panelScale: number = 1;
  @State displayedIndex: number = 0;
  private widthVp: number = 320;
  private revision: number = 0;
  private mounted: boolean = false;

  aboutToAppear(): void {
    this.displayedIndex = this.activeIndex;
    this.onDisplay(this.displayedIndex);
    this.mounted = true;
    this.reset();
  }

  aboutToDisappear(): void {
    this.mounted = false;
    this.revision++;
  }

  private reset(): void {
    this.swingOffset = 0;
    this.angle = 0;
    this.panelScale = 1;
  }

  private motionChanged(): void {
    if (!this.reduceMotion) { return; }
    this.revision++;
    this.getUIContext().animateTo({ duration: 0 }, (): void => {
      this.displayedIndex = this.activeIndex;
      this.onDisplay(this.displayedIndex);
      this.reset();
    });
  }

  private selectionChanged(): void {
    const revision: number = ++this.revision;
    if (!this.mounted || this.reduceMotion) {
      this.getUIContext().animateTo({ duration: 0 }, (): void => {
        this.displayedIndex = this.activeIndex;
        this.onDisplay(this.displayedIndex);
        this.reset();
      });
      return;
    }
    if (this.activeIndex === this.displayedIndex) {
      this.getUIContext().animateTo({ curve: curves.springMotion(0.42, 0.78, 0.08) }, (): void => { this.reset(); });
      return;
    }
    const direction: number = this.activeIndex > this.displayedIndex ? 1 : -1;
    const distance: number = Math.max(1, this.widthVp) + 32;
    this.getUIContext().animateTo({ duration: 140, curve: Curve.EaseIn,
      onFinish: (): void => {
        if (!this.mounted || revision !== this.revision) { return; }
        this.getUIContext().animateTo({ duration: 0 }, (): void => {
          this.displayedIndex = this.activeIndex;
          this.onDisplay(this.displayedIndex);
          this.swingOffset = direction * distance;
          this.angle = -direction * 1.8;
          this.panelScale = 0.985;
        });
        this.getUIContext().postFrameCallback(new SwingFrame((): void => {
          if (!this.mounted || revision !== this.revision || this.reduceMotion) { return; }
          this.getUIContext().animateTo({ curve: curves.springMotion(0.42, 0.84, 0.08) }, (): void => { this.reset(); });
        }));
      }
    }, (): void => {
      this.swingOffset = -direction * distance;
      this.angle = direction * 1.8;
      this.panelScale = 0.985;
    });
  }

  build() {
    Column() {
      Column() {
        this.content()
      }
      .width('100%')
      .height(this.fillHeight ? '100%' : undefined)
      .scale({ x: this.panelScale, y: this.panelScale, centerY: '0%' })
      .rotate({ angle: this.angle, centerX: '50%', centerY: '0%' })
      .translate({ x: this.swingOffset })
      .enabled(this.displayedIndex === this.activeIndex)
    }
    .width('100%')
    .height(this.fillHeight ? '100%' : undefined)
    .clip(true)
    .onAreaChange((_previous: Area, current: Area): void => { this.widthVp = Number(current.width); })
  }
}
