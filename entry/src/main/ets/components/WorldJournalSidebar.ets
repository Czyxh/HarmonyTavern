import { FrameCallback } from '@kit.ArkUI';
import { WorldStateReport, worldNeedsInitialization } from '../backend/NativeWorld';
import { COLORS, ColorTokens } from '../theme/Tokens';
import { OriginMotion, OriginPanelState, MotionOrigin } from '../theme/OriginMotion';
import { iconTint } from '../theme/IconTint';
import { LiquidContour, LiquidVector } from '../theme/LiquidContour';

@AnimatableExtend(Stack)
function journalMorph(frame: LiquidVector) {
  .position({ x: frame.values[0], y: frame.values[1] })
  .width(frame.values[2]).height(frame.values[3])
  .borderRadius(LiquidContour.radius(frame.values[2], frame.values[3], frame.values[4]))
  .clip(true)
  .clipShape(new Path().commands(LiquidContour.body(frame.values[2], frame.values[3], frame.values[4], frame.values[5])))
}

class JournalFrame extends FrameCallback {
  private action: () => void;
  constructor(action: () => void) { super(); this.action = action; }
  onFrame(_frameTime: number): void { this.action(); }
}

@Component
export struct WorldJournalSidebar {
  @StorageProp('uiColors') colors: ColorTokens = COLORS;
  @StorageProp('reduceMotion') @Watch('intentChanged') reduceMotion: boolean = false;
  @StorageProp('appWindowWidth') windowWidth: number = 400;
  @StorageProp('appWindowHeight') windowHeight: number = 800;
  @StorageProp('systemTopInset') topInset: number = 0;
  @StorageProp('systemBottomInset') bottomInset: number = 0;
  @ObjectLink @Watch('intentChanged') panel: OriginPanelState;
  @Prop onRight: boolean = true;
  @Prop report: WorldStateReport = { status: 'missing', message: '尚未生成状态。' };
  @Prop busy: boolean = false;
  @Prop error: string = '';
  @Prop section: string = 'quests';
  @BuilderParam content: () => void;
  @State reveal: number = 0;
  @State detailHeight: number = 120;
  @State originX: number = 0;
  @State originY: number = 0;
  @State originWidth: number = 44;
  @State originHeight: number = 44;
  @State hostTop: number = 0;
  @State ready: boolean = false;
  private revision: number = 0;
  private mounted: boolean = false;
  onClosed: () => void = (): void => {};
  onGenerate: () => void = (): void => {};
  onCancel: () => void = (): void => {};
  @Prop canCancel: boolean = true;
  @Prop canGenerate: boolean = true;

  aboutToDisappear(): void { this.mounted = false; this.revision++; }
  private initialize(): void {
    if (!this.mounted) { return; }
    const host: MotionOrigin = OriginMotion.captureOnScreen(this.getUIContext(), 'world-journal-host');
    this.hostTop = OriginMotion.capture(this.getUIContext(), 'world-journal-host').top;
    this.originX = this.panel.origin.left - host.left;
    this.originY = this.panel.origin.top - host.top;
    this.originWidth = this.panel.origin.width;
    this.originHeight = this.panel.origin.height;
    this.ready = true;
    this.intentChanged();
  }
  private intentChanged(): void {
    if (!this.mounted || !this.ready) { return; }
    const revision: number = ++this.revision;
    const opening: boolean = this.panel.opened;
    this.getUIContext().animateTo({ duration: this.reduceMotion ? 0 : (opening ? 300 : 240), curve: Curve.EaseInOut,
      onFinish: (): void => {
        if (!this.mounted || revision !== this.revision || this.panel.opened) { return; }
        this.panel.presented = false;
        this.onClosed();
      }
    }, (): void => { this.reveal = opening ? 1 : 0; });
  }
  private title(): string {
    if (this.section === 'relationships') { return '人物关系'; }
    if (this.section === 'status') { return '位置与状态'; }
    if (this.section === 'inventory') { return '随身物品'; }
    if (this.section === 'equipment') { return '装备栏'; }
    if (this.section === 'settings') { return '状态栏设置'; }
    return '任务书';
  }
  private cardWidth(): number { return Math.max(1, Math.min(340, this.windowWidth - 40)); }
  private cardHeight(): number { return Math.max(180, Math.min(520, this.windowHeight - this.topInset - this.bottomInset - 64)); }
  private bodyHeight(): number { return Math.max(52, Math.min(this.detailHeight, this.cardHeight() - 124)); }
  private actualHeight(): number { return this.bodyHeight() + 80 + (this.report.status === 'stale' ? 28 : 0) + (this.error !== '' ? 48 : 0); }
  private left(): number { return this.onRight ? this.windowWidth - this.cardWidth() - 20 : 20; }
  private top(): number {
    return Math.max(this.topInset - this.hostTop + 16, Math.min(this.originY - 24,
      this.windowHeight - this.hostTop - this.bottomInset - this.actualHeight() - 16));
  }
  @Builder
  action(icon: Resource, label: string, marker: string, selected: () => void, available: boolean = true) {
    Button({ type: ButtonType.Circle }) {
      Image(icon).width(18).height(18).colorFilter(iconTint(this.colors.textSecondary))
    }.width(44).height(44).padding(0).backgroundColor(Color.Transparent).id(marker).accessibilityText(label)
      .enabled(available).onClick(selected)
  }
  private frame(): LiquidVector {
    const progress: number = this.reduceMotion ? 1 : this.reveal;
    return new LiquidVector([
      this.originX + progress * (this.left() - this.originX),
      this.originY + progress * (this.top() - this.originY),
      this.originWidth + progress * (this.cardWidth() - this.originWidth),
      this.originHeight + progress * (this.actualHeight() - this.originHeight),
      1 - progress, this.getUIContext().vp2px(1)
    ]);
  }
  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column().width('100%').height('100%').backgroundColor(Color.Transparent)
        .onClick((): void => { this.panel.close(); }).accessibilityText('关闭冒险浮层')
      Stack({ alignContent: Alignment.TopStart }) {
        Column({ space: 8 }) {
          Row({ space: 0 }) {
            Text(this.title()).fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.colors.textPrimary).layoutWeight(1)
            if (this.busy) { this.action($r('app.media.icon_stop'), '取消状态生成', 'world-journal-cancel', (): void => { this.onCancel(); }, this.canCancel) }
            else if (this.section !== 'settings') { this.action($r('app.media.icon_refresh'), '重新生成状态', 'world-journal-refresh', (): void => { this.onGenerate(); }, this.canGenerate) }
            this.action($r('app.media.icon_close'), '关闭', 'world-journal-close', (): void => { this.panel.close(); })
          }.width('100%')
          if (this.report.status === 'stale') { Text('上次快照 · 本轮待确认').fontSize(12).fontColor(this.colors.warning).width('100%') }
          if (this.error !== '') { Text(this.error).fontSize(12).fontColor(this.colors.danger).width('100%') }
          Scroll() {
            Column({ space: 12 }) {
              this.content()
              if (this.section !== 'settings' && this.report.status === 'loading' && this.report.state === undefined) {
                LoadingProgress().width(24).height(24).color(this.colors.accent)
              }
              if (this.section !== 'settings' && worldNeedsInitialization(this.report)) {
                Text('还没有已确认的记录').fontSize(15).fontColor(this.colors.textPrimary).width('100%')
                Text('剧情推进后自动整理，也可以点刷新生成。').fontSize(13).fontColor(this.colors.textSecondary).width('100%')
              }
            }.width('100%').padding({ bottom: 8 })
              .onAreaChange((_previous: Area, area: Area): void => {
                const height: number = Number(area.height);
                if (Number.isFinite(height) && height > 0 && Math.abs(height - this.detailHeight) > 0.5) { this.detailHeight = height; }
              })
          }.height(this.bodyHeight()).width('100%').align(Alignment.TopStart).scrollBar(BarState.Auto)
        }.width(this.cardWidth()).padding({ left: 16, right: 12, top: 8, bottom: 12 })
          .opacity(this.reduceMotion ? this.reveal : Math.max(0, (this.reveal - 0.55) / 0.45))
      }.journalMorph(this.frame())
        .backgroundColor(this.colors.bgSurface)
        .border({ width: 0.65, color: this.colors.borderSubtle })
        .opacity(this.ready ? (this.reduceMotion ? this.reveal : 1) : 0)
        .id('world-journal-' + this.section)
    }.width('100%').height('100%').id('world-journal-host')
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .onAppear((): void => {
        this.mounted = true;
        this.getUIContext().postFrameCallback(new JournalFrame((): void => { this.initialize(); }));
      })
  }
}
