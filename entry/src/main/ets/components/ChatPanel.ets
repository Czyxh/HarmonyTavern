import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { HeaderAction } from './HeaderAction';
import { GLASS_MENU, glassEffect } from '../theme/Glass';
import { LS_BLUR_DEFAULT, LS_BLUR_KEY } from '../theme/LightSense';
import { IMMERSIVE_DEFAULT, IMMERSIVE_KEY } from '../theme/Immersive';
import { SCROLL_EDGE_OPTIONS, SCROLL_NESTED_OPTIONS } from '../theme/ScrollFeedback';
import { PanelSizing } from '../theme/PanelSizing';

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
export struct ChatPanel {
  private sizing: PanelSizing = new PanelSizing();
  private measuredHeight: number = 0;
  onContentHeight: (height: number) => void = (_height: number): void => {};
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @StorageProp(LS_BLUR_KEY) blurRadius: number = LS_BLUR_DEFAULT;
  @StorageProp(IMMERSIVE_KEY) immersiveLevel: number = IMMERSIVE_DEFAULT;
  @StorageProp('systemBottomInset') safeBottom: number = 0;
  @StorageProp('appViewportBottom') viewportBottom: number = 0;
  @StorageProp('systemKeyboardTop') keyboardTop: number = 0;
  @StorageProp('appWindowHeight') windowHeight: number = 0;
  @State panelHeight: number = 0;
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop hasFooter: boolean = false;
  @Prop managedLayout: boolean = false;
  @BuilderParam content: () => void;
  @BuilderParam footer: () => void = this.emptyFooter;
  onClose: () => void = (): void => {};

  @Builder
  emptyFooter() {}

  private measure(section: 'header' | 'body' | 'footer', area: Area): void {
    if (!this.managedLayout) { return; }
    if (!this.hasFooter) { this.sizing.update('footer', 0); }
    this.sizing.update(section, Number(area.height));
    if (this.sizing.header <= 0 || this.sizing.body <= 0) { return; }
    const height: number = this.sizing.limit(Number.MAX_SAFE_INTEGER);
    if (Math.abs(this.measuredHeight - height) <= 0.5) { return; }
    this.measuredHeight = height;
    this.onContentHeight(height);
  }

  private visibleHeight(): number | string {
    if (this.managedLayout) { return '100%'; }
    if (this.panelHeight <= 0 || this.viewportBottom <= 0 || this.windowHeight <= 0) { return '100%'; }
    const visibleBottom: number = this.keyboardTop > 0 ? Math.min(this.viewportBottom, this.keyboardTop) : this.viewportBottom;
    const panelTop: number = Math.max(0, this.windowHeight - this.panelHeight);
    return Math.max(0, Math.min(this.panelHeight, visibleBottom - panelTop));
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column({ space: 0 }) {
        Row({ space: 12 }) {
          Column({ space: 6 }) {
            Text(this.title)
              .fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.uiColors.textPrimary)
              .width('100%')
            if (this.subtitle !== '') {
              Text(this.subtitle)
                .fontSize(13).fontColor(this.uiColors.textSecondary).width('100%')
            }
          }
          .layoutWeight(1)
          HeaderAction({ icon: $r('app.media.icon_close'), refresh: false, label: '关闭' + this.title,
            onAction: async (): Promise<void> => { this.onClose(); } })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .padding({ left: 20, right: 16, top: 20, bottom: 16 })
        .onAreaChange((_previous: Area, current: Area): void => { this.measure('header', current); })
        Scroll() {
          Column({ space: 16 }) {
            this.content()
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 16, right: 16, bottom: this.hasFooter ? 16 :
            (this.managedLayout ? 20 : Math.max(24, this.safeBottom + 16)) })
          .onAreaChange((_previous: Area, current: Area): void => { this.measure('body', current); })
        }
        .width('100%').layoutWeight(1)
        .align(Alignment.Top)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring, SCROLL_EDGE_OPTIONS)
        .nestedScroll(SCROLL_NESTED_OPTIONS)
        if (this.hasFooter) {
          Column() { this.footer() }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: this.managedLayout || this.keyboardTop > 0 ? 12 : Math.max(16, this.safeBottom + 8) })
            .backgroundColor(this.uiColors.headerButtonTint)
            .onAreaChange((_previous: Area, current: Area): void => { this.measure('footer', current); })
        }
      }
      .width('100%').height(this.visibleHeight())
      .backgroundColor(Color.Transparent)
      .backgroundEffect(this.managedLayout ? { radius: 0, color: Color.Transparent } :
        glassEffect(GLASS_MENU, this.blurRadius, this.immersiveLevel, this.uiColors))
      .linearGradient({ angle: 150, colors: [
        [this.managedLayout ? this.uiColors.clear : this.uiColors.highlight, 0], [this.uiColors.clear, 0.3],
        [this.managedLayout ? this.uiColors.clear : this.uiColors.reflection, 1]
      ] })
      .border({ width: this.managedLayout ? 0 : 0.8, color: this.uiColors.glassEdge })
      .borderRadius({ topLeft: 28, topRight: 28 })
      .clip(true)
    }
    .width('100%').height('100%')
    .onAreaChange((_previous: Area, current: Area): void => {
      this.panelHeight = Number(current.height);
    })
  }
}
