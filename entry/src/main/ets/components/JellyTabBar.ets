import { iconTint } from '../theme/IconTint';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { GLASS_TAB_BAR, GLASS_LENS, glassEffect, glassLightColor } from '../theme/Glass';
import { MOTION_REDUCE_KEY } from '../theme/Motion';
import { curves, CommonModifier } from '@kit.ArkUI';
import { LS_BLUR_DEFAULT, LS_BLUR_KEY } from '../theme/LightSense';
import { IMMERSIVE_DEFAULT, IMMERSIVE_KEY } from '../theme/Immersive';
import { GlassLightField } from './GlassLightField';
import { LiquidGlassRim } from './LiquidGlassRim';
import { SystemGlass, SystemLensStyle } from '../theme/SystemGlass';

export interface JellyTabItem {
  glyph: string;
  label: string;
}

export const JELLY_VISIBLE: number = 1;

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
export struct JellyTabBar {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @Prop items: JellyTabItem[] = [];
  @Prop @Watch('selectionChanged') currentIndex: number = 0;
  @Prop spec: number = JELLY_VISIBLE;
  @Prop containerWidthVp: number = 0;
  @Prop rail: boolean = false;
  @Prop bare: boolean = false;
  @Prop textOnly: boolean = false;
  @State trayWidth: number = 0;
  @State trayHeight: number = 44;
  @State trayWindowLeft: number = 0;
  @State trayWindowTop: number = 0;
  @State nativeWindowLeft: number = 0;
  @State nativeWindowTop: number = 0;
  @State lensPosition: number = 0;
  @State lensStretch: number = 1;
  @State dragging: boolean = false;
  @State lightPressed: boolean = false;
  @State lightFocus: number = -1;
  @State nativeMaterial: boolean = false;
  @StorageProp(LS_BLUR_KEY) @Watch('materialChanged') blurRadius: number = LS_BLUR_DEFAULT;
  @StorageProp(IMMERSIVE_KEY) immersiveLevel: number = IMMERSIVE_DEFAULT;
  @StorageProp(MOTION_REDUCE_KEY) @Watch('motionChanged') reduceMotion: boolean = false;
  onSelect: (index: number) => void = (): void => {};

  aboutToAppear(): void {
    this.materialChanged();
    SystemGlass.initialize().then((): void => { this.materialChanged(); });
    this.lensPosition = this.clampIndex(this.currentIndex);
  }

  private materialChanged(): void { this.nativeMaterial = this.blurRadius > 0 && SystemGlass.supported(); }

  private icon(index: number): Resource {
    if (index === 0) { return $r('app.media.nav_chat'); }
    if (index === 1) { return $r('app.media.nav_character'); }
    if (index === 2) { return $r('app.media.nav_library'); }
    return $r('app.media.icon_settings');
  }

  private clampIndex(index: number): number {
    return Math.max(0, Math.min(Math.max(0, this.items.length - 1), index));
  }

  private itemWidth(): number {
    return this.trayWidth / Math.max(1, this.items.length);
  }

  private lensOffset(): number {
    return this.lensPosition * this.itemWidth() + 2;
  }

  private pointerPosition(event: GestureEvent): number {
    if (event.fingerList.length === 0 || this.itemWidth() <= 0) {
      return this.lensPosition;
    }
    return this.clampIndex(event.fingerList[0].localX / this.itemWidth() - 0.5);
  }

  private settle(index: number): void {
    this.getUIContext().animateTo(this.reduceMotion ? { duration: 0 } : {
      curve: curves.springMotion(0.38, 0.76, 0.08)
    }, (): void => {
      this.lensPosition = this.clampIndex(index);
      this.lensStretch = 1;
    });
  }

  private selectionChanged(): void {
    if (!this.dragging) { this.settle(this.currentIndex); }
  }

  private motionChanged(): void {
    this.getUIContext().animateTo({ duration: 0 }, (): void => {
      this.lensStretch = 1;
      if (!this.dragging) { this.lensPosition = this.clampIndex(this.currentIndex); }
    });
  }

  private pressLens(): void {
    this.lightPressed = true;
    if (this.reduceMotion || this.rail) { return; }
    this.getUIContext().animateTo({ curve: curves.responsiveSpringMotion(0.16, 0.82) }, (): void => {
      this.lensStretch = 1.06;
    });
  }

  private dragLens(event: GestureEvent): void {
    const position: number = this.pointerPosition(event);
    this.lightPressed = true;
    this.lightFocus = (position + 0.5) / Math.max(1, this.items.length);
    const stretch: number = 1.04 + Math.min(Math.abs(event.velocityX) / 14000, 0.08);
    this.getUIContext().animateTo(this.reduceMotion ? { duration: 0 } : {
      curve: curves.responsiveSpringMotion(0.12, 0.88, 0.06)
    }, (): void => {
      this.lensPosition = position;
      this.lensStretch = this.reduceMotion ? 1 : stretch;
    });
  }

  private commitDrag(event: GestureEvent): void {
    const index: number = Math.round(this.pointerPosition(event));
    this.dragging = false;
    this.releaseLight();
    this.settle(index);
    if (index !== this.currentIndex) { this.onSelect(index); }
  }

  private cancelDrag(): void {
    this.dragging = false;
    this.releaseLight();
    this.settle(this.currentIndex);
  }

  private releaseLight(): void {
    this.lightPressed = false;
    this.lightFocus = -1;
  }

  private visualScale(index: number): number {
    if (this.rail) { return 1; }
    const proximity: number = Math.max(0, 1 - Math.abs(index - this.lensPosition));
    return 1 + (this.textOnly ? 0.1 : 0.16) * proximity;
  }

  private visualSelected(index: number): boolean {
    return (this.dragging ? Math.round(this.lensPosition) : this.currentIndex) === index;
  }

  @Builder
  tabVisual(item: JellyTabItem, index: number) {
    Column({ space: 2 }) {
      if (!this.textOnly) {
        Image(this.icon(index))
          .width(20)
          .height(20)
          .colorFilter(iconTint(this.visualSelected(index) ? this.uiColors.accent : this.uiColors.textSecondary))
      }
      Text(item.label)
        .fontSize(this.textOnly ? 14 : 10)
        .fontWeight(this.visualSelected(index) ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.visualSelected(index) ? this.uiColors.accent : this.uiColors.textSecondary)
        .maxLines(1)
        .textAlign(TextAlign.Center)
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .width('100%')
    .height('100%')
    .scale({ x: this.visualScale(index), y: this.visualScale(index) })
    .accessibilityLevel('no-hide-descendants')
  }

  @Builder
  tabItem(item: JellyTabItem, index: number) {
    Button({ type: ButtonType.Normal }) {
      this.tabVisual(item, index)
    }
    .width(this.rail ? 76 : `${100 / Math.max(1, this.items.length)}%`)
    .height(this.rail ? 76 : (this.nativeMaterial ? this.trayHeight : 44))
    .padding(0)
    .stateEffect(false)
    .hoverEffect(HoverEffect.None)
    .backgroundColor(this.rail && this.currentIndex === index ? this.uiColors.accentContainer : Color.Transparent)
    .borderRadius(this.rail ? 24 : 22)
    .accessibilityText(item.label)
    .id(`jelly-tab-item-${index}`)
    .accessibilitySelected(this.currentIndex === index)
    .onTouch((event: TouchEvent): void => {
      if (event.type === TouchType.Down) {
        this.lightFocus = (index + 0.5) / Math.max(1, this.items.length);
        this.pressLens();
      }
      if (!this.dragging && (event.type === TouchType.Up || event.type === TouchType.Cancel)) {
        this.releaseLight();
        this.settle(this.currentIndex);
      }
    })
    .stateStyles({ normal: touchFeedbackNormal, pressed: touchFeedbackPressed })
    .onClick(() => {
      if (!this.dragging) {
        this.settle(index);
        this.onSelect(index);
      }
    })
  }

  @Builder
  lens() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (!this.nativeMaterial) {
        LiquidGlassRim({ pressed: this.lightPressed && !this.reduceMotion, compact: true })
      }
      Column()
        .width('100%').height(44)
        .linearGradient({ angle: 155, colors: [
          [glassLightColor(this.uiColors.highlight, this.lightPressed ? 0.6 : 0.45), 0],
          [glassLightColor(this.uiColors.highlight, 0.12), 0.5],
          [glassLightColor(this.uiColors.reflection, 0.45), 1]
        ] })
        .borderRadius(22)
        .border({ radius: 22, width: 0.6, color: glassLightColor(this.uiColors.highlight, 0.6) })
        .blur(0.8)
    }
    .width(Math.max(0, this.itemWidth() - 4))
    .height(44)
    .backgroundEffect(this.nativeMaterial ? { radius: 0, color: Color.Transparent } :
      glassEffect(GLASS_LENS, this.blurRadius, this.immersiveLevel, this.uiColors))
    .attributeModifier(new SystemLensStyle(this.nativeMaterial, this.reduceMotion))
    .borderRadius(22)
    .clip(true)
    .scale({ x: this.lensStretch, y: 2 - this.lensStretch })
    .translate({ x: this.lensOffset() })
    .visibility(this.trayWidth > 0 && this.items.length > 0 ? Visibility.Visible : Visibility.Hidden)
    .hitTestBehavior(HitTestMode.None)
    .accessibilityLevel('no-hide-descendants')
  }

  @Builder
  slidingTabs(interactive: boolean = true) {
    Stack({ alignContent: Alignment.TopStart }) {
      if (!this.nativeMaterial) {
        LiquidGlassRim({ pressed: this.lightPressed && !this.reduceMotion })
          .width(Math.max(0, this.trayWidth + 12)).height(56)
          .position({ x: -6, y: -6 })
      }
      this.lens()
      if (interactive) { this.tabControls(false) }
    }
    .width('100%')
    .height(44)
    .id('jelly-tab-tray')
    .onAreaChange((_previous: Area, current: Area): void => {
      this.trayWidth = Number(current.width);
      this.trayHeight = Math.min(Number(current.height), this.textOnly ? 40 : 44);
      this.trayWindowLeft = Number(current.globalPosition.x);
      this.trayWindowTop = Number(current.globalPosition.y);
    })
  }

  @Builder
  tabControls(native: boolean) {
    Row() {
      ForEach(this.items, (item: JellyTabItem, index: number) => {
        this.tabItem(item, index)
      }, (item: JellyTabItem) => item.label)
    }
    .width('100%')
    .height(native ? this.trayHeight : 44)
    .gesture(
      PanGesture({ direction: PanDirection.Horizontal, distance: 5 })
        .onActionStart((event: GestureEvent): void => {
          this.dragging = true;
          this.dragLens(event);
        })
        .onActionUpdate((event: GestureEvent): void => { this.dragLens(event); })
        .onActionEnd((event: GestureEvent): void => { this.commitDrag(event); })
        .onActionCancel((): void => { this.cancelDrag(); })
    )
  }

  @Builder
  nativeBarContent() {
    Column() { this.slidingTabs(false) }
      // Floating TabBar reserves 4vp above and below its custom content.
      .width('100%').height('100%').padding({ left: 6, right: 6 })
      .justifyContent(FlexAlign.Center)
  }

  @Builder
  nativeBar() {
    // A real bottom TabBar hosts the custom, accessible navigation controls.
    // Keeping the content host separate preserves the existing interruptible page transition.
    Stack({ alignContent: Alignment.TopStart }) {
      Tabs({ barPosition: BarPosition.End, barModifier: new CommonModifier().padding(0).systemMaterial(SystemGlass.empty()).backgroundColor(Color.Transparent) }) {
        TabContent() { Column().height(0) }
          .tabBar(this.nativeBarContent())
      }
      .width('100%').height(this.textOnly ? 48 : 56)
      .barHeight(this.textOnly ? 48 : 56).barWidth('100%').barOverlap(true).vertical(false).scrollable(false).animationDuration(0)
      .barFloatingStyle({ barSideMargin: 0, barBottomMargin: 0, maskHeight: 0,
        systemMaterial: SystemGlass.navigation(this.immersiveLevel, this.uiColors) })
      .barBackgroundColor(Color.Transparent).barBackgroundEffect({ radius: 0, color: Color.Transparent })
      .backgroundColor(Color.Transparent).borderRadius(this.textOnly ? 24 : 28).clip(this.textOnly)
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
      .id('system-material-tabbar')
      GlassLightField({ pressed: this.lightPressed, fullCoverage: true })
        .width('100%').height('100%')
      Column() { this.tabControls(true) }
        .width(this.trayWidth).height(this.trayHeight)
        .position({ x: this.trayWindowLeft - this.nativeWindowLeft, y: this.trayWindowTop - this.nativeWindowTop })
    }
    .width(this.bare || this.textOnly ? '100%' : Math.max(240, Math.min(380, this.containerWidthVp - 40)))
    .height(this.textOnly ? 48 : 56)
    .onAreaChange((_previous: Area, current: Area): void => {
      this.nativeWindowLeft = Number(current.globalPosition.x);
      this.nativeWindowTop = Number(current.globalPosition.y);
    })
  }

  build() {
    if (this.rail) {
      Column({ space: 16 }) {
        Text('HT')
          .fontSize(23)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.uiColors.accent)
          .margin({ top: 20, bottom: 20 })
          .accessibilityText('HarmonyTavern')
        ForEach(this.items, (item: JellyTabItem, index: number) => {
          this.tabItem(item, index)
        }, (item: JellyTabItem) => item.label)
        Blank()
      }
      .padding(12)
      .width(104)
      .height('100%')
      .backgroundEffect(glassEffect(GLASS_TAB_BAR, this.blurRadius, this.immersiveLevel, this.uiColors))
      .border({ width: { right: 1 }, color: this.uiColors.borderSubtle })
    } else if (this.nativeMaterial) {
      this.nativeBar()
    } else if (this.bare) {
      Stack() {
        GlassLightField({ pressed: this.lightPressed, fullCoverage: true })
        this.slidingTabs()
      }.width('100%').height(44)
    } else {
      Stack() {
        GlassLightField({ pressed: this.lightPressed, fullCoverage: true })
        Column() {
          this.slidingTabs()
        }.width('100%').height('100%').padding(this.textOnly ? 2 : 6)
      }
      .width(this.textOnly ? '100%' : Math.max(240, Math.min(380, this.containerWidthVp - 40)))
      .height(this.textOnly ? 48 : 56)
      .backgroundEffect(glassEffect(GLASS_TAB_BAR, this.blurRadius, this.immersiveLevel, this.uiColors))
      .linearGradient({
        angle: 155,
        colors: [[this.uiColors.highlight, 0], [this.uiColors.clear, 0.45],
          [this.uiColors.reflection, 1]]
      })
      .borderRadius(28)
      .border({ radius: 28, width: 1, color: this.uiColors.glassEdge })
      .clip(true)
      .shadow({ radius: this.textOnly ? 0 : 24, color: this.uiColors.softShadow, offsetY: this.textOnly ? 0 : 8 })
    }
  }
}
