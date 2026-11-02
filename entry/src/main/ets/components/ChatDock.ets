import { RpgThemes } from '../theme/RpgThemes';
import { BACKGROUND_KEY, BACKGROUND_DEFAULT } from '../theme/Appearance';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { iconTint } from '../theme/IconTint';
import { GLASS_ORB, glassEffect, glassLightColor } from '../theme/Glass';
import { SystemGlass } from '../theme/SystemGlass';
import { NativeGlassBackdrop } from './NativeGlassBackdrop';
import { LS_BLUR_DEFAULT, LS_BLUR_KEY } from '../theme/LightSense';
import { IMMERSIVE_DEFAULT, IMMERSIVE_KEY } from '../theme/Immersive';
import { MOTION_REDUCE_KEY } from '../theme/Motion';
import { curves } from '@kit.ArkUI';
import { OriginPanelState } from '../theme/OriginMotion';
import { OriginPanel } from './OriginPanel';
import { LiquidMenuItem } from './LiquidMenuItem';

@Observed
export class ChatDockState {
  text: string = '';
  streaming: boolean = false;
  available: boolean = false;
  attachments: number = 0;
  summaryVisible: boolean = false;
  searchOpen: boolean = false;
  panelOpen: boolean = false;
  preventBack: boolean = false;
  changeText: (value: string) => void = (): void => {};
  submit: () => void = (): void => {};
  attach: () => void = (): void => {};
  selectModel: () => void = (): void => {};
  compactContext: () => void = (): void => {};
  toggleSearch: () => void = (): void => {};
  toggleSummary: () => void = (): void => {};
  scrollToLatest: () => void = (): void => {};
}

@Component
export struct ChatDock {
  @StorageProp(BACKGROUND_KEY) backgroundId: string = BACKGROUND_DEFAULT;
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @ObjectLink state: ChatDockState;

  build() {
    Row({ space: 4 }) {
      TextArea({ placeholder: RpgThemes.find(this.backgroundId) !== undefined ? '自由输入，推进故事…' : '说点什么…', text: this.state.text })
        .id('chat-composer-input')
        .layoutWeight(1)
        .fontSize(16)
        .fontColor(this.uiColors.textPrimary)
        .placeholderColor(this.uiColors.textSecondary)
        .backgroundColor(Color.Transparent)
        .borderRadius(0)
        .border({ width: 0 })
        .padding({ left: 12, right: 12, top: 12, bottom: 12 })
        .constraintSize({ minHeight: 44, maxHeight: 100 })
        .maxLines(4, { overflowMode: MaxLinesMode.SCROLL })
        .enterKeyType(EnterKeyType.Send)
        .onChange((value: string) => this.state.changeText(value))
        .onSubmit(() => { if (!this.state.streaming) { this.state.submit(); } })
      Button({ type: RpgThemes.find(this.backgroundId) !== undefined ? ButtonType.Normal : ButtonType.Circle }) {
        Image(this.state.streaming ? $r('app.media.icon_stop') : $r('app.media.icon_send'))
          .width(this.state.streaming ? 20 : 24).height(this.state.streaming ? 20 : 24)
          .colorFilter(iconTint(this.uiColors.textInverse))
      }
        .width(44).height(44)
        .borderRadius(this.backgroundId === 'rpg_pixel' ? 2 : 11)
        .fontSize(this.state.streaming ? 16 : 24)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.uiColors.textInverse)
        .backgroundColor(this.uiColors.accent)
        .stateEffect(true)
        .accessibilityText(this.state.streaming ? '停止生成' : '发送消息')
        .id('chat-send-anchor')
        .enabled(this.state.streaming || (this.state.available && this.state.text.trim().length > 0))
        .onClick(() => { this.state.submit(); })
    }
    .width('100%')
    .alignItems(VerticalAlign.Bottom)
  }
}

@Component
export struct ChatDockAction {
  @StorageProp(BACKGROUND_KEY) backgroundId: string = BACKGROUND_DEFAULT;
  @StorageProp('systemMaterialAvailable') nativeAvailable: boolean = false;
  @StorageProp('liquidPressedSource') liquidPressedSource: string = '';
  @StorageProp('liquidSourceSqueezed') @Watch('squeezeChanged') sourceSqueezed: boolean = false;
  @State squeeze: number = 0;
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @StorageProp(LS_BLUR_KEY) blurRadius: number = LS_BLUR_DEFAULT;
  @StorageProp(IMMERSIVE_KEY) immersiveLevel: number = IMMERSIVE_DEFAULT;
  @StorageProp(MOTION_REDUCE_KEY) reduceMotion: boolean = false;
  @ObjectLink @Watch('panelChanged') state: ChatDockState;
  @Prop revealed: boolean = true;
  @Prop onRight: boolean = false;
  @State pressed: boolean = false;
  @State touchPosition: number = -1;
  @State pressScale: number = 1;
  @State @Watch('panelChanged') menuOrigin: OriginPanelState = new OriginPanelState();
  onInteractionChange: (active: boolean) => void = (): void => {};

  private panelChanged(): void {
    this.onInteractionChange(this.pressed || this.menuOrigin.presented || this.state.panelOpen);
  }

  private touchChanged(event: TouchEvent): void {
    if (event.type === TouchType.Move) { return; }
    this.pressed = event.type === TouchType.Down || event.type === TouchType.Move;
    this.touchPosition = this.pressed && event.touches.length > 0 ? event.touches[0].x / 52 : -1;
    this.panelChanged();
    this.getUIContext().animateTo({ duration: this.pressed || this.reduceMotion ? 0 : 100, curve: Curve.EaseOut }, (): void => {
      this.pressScale = this.pressed && !this.reduceMotion ? 0.94 : 1;
    });
  }

  private squeezeChanged(): void {
    this.getUIContext().animateTo({ duration: this.reduceMotion ? 0 : (this.sourceSqueezed ? 70 : 160),
      curve: Curve.EaseOut }, (): void => {
      this.squeeze = this.sourceSqueezed && this.liquidPressedSource === 'chat-tools-anchor' && !this.reduceMotion ? 1 : 0;
    });
  }

  private description(): string {
    return this.state.attachments > 0 ? `聊天工具，已附加 ${this.state.attachments} 张图片` : '聊天工具';
  }

  @Builder
  toolsMenu() {
    Scroll() {
      Column() {
        LiquidMenuItem({ label: this.state.attachments > 0 ? `添加图片 · 已附加 ${this.state.attachments} 张` : '添加图片',
          available: this.state.available,
          onSelect: (): void => { this.menuOrigin.select((): void => { this.state.attach(); }); } })
        LiquidMenuItem({ label: '模型设置',
          onSelect: (): void => { this.menuOrigin.select((): void => { this.state.selectModel(); }); } })
        LiquidMenuItem({ label: '精简上下文', available: this.state.available && !this.state.streaming,
          onSelect: (): void => { this.menuOrigin.select((): void => { this.state.compactContext(); }); } })
        LiquidMenuItem({ label: this.state.searchOpen ? '关闭搜索' : '搜索消息', available: this.state.available,
          onSelect: (): void => { this.menuOrigin.select((): void => { this.state.toggleSearch(); }); } })
        LiquidMenuItem({ label: this.state.summaryVisible ? '收起摘要' : '查看摘要', available: this.state.available,
          onSelect: (): void => { this.menuOrigin.select((): void => { this.state.toggleSummary(); }); } })
        LiquidMenuItem({ label: '回到最新消息', available: this.state.available,
          onSelect: (): void => { this.menuOrigin.select((): void => { this.state.scrollToLatest(); }); } })
      }
      .width('100%').padding(8)
      .onAreaChange((_previous: Area, area: Area): void => { this.menuOrigin.fitMenuHeight(Number(area.height)); })
    }
    .width('100%').height('100%').scrollBar(BarState.Off)
  }

  @Builder
  toolsCover() {
    Stack() {
      OriginPanel({ state: this.menuOrigin, content: (): void => { this.toolsMenu(); } })
    }
    .width('100%').height('100%')
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }

  build() {
    Button({ type: ButtonType.Circle }) {
      Stack() {
        if (this.nativeAvailable && this.blurRadius > 0 && SystemGlass.supported()) {
          NativeGlassBackdrop({ diameter: 52, radius: 26 })
        }
        Image($r('app.media.icon_add'))
          .width(28).height(28)
          .colorFilter(iconTint(this.uiColors.textPrimary))
          .accessibilityLevel('no')
      }
      .width(52).height(52)
    }
    .width(this.revealed ? 52 : 0).height(52).padding(0)
    .visibility(this.revealed ? Visibility.Visible : Visibility.Hidden)
    .backgroundColor(Color.Transparent)
    .backgroundEffect(this.nativeAvailable && this.blurRadius > 0 ? { radius: 0, color: Color.Transparent } :
      glassEffect(GLASS_ORB, this.blurRadius, this.immersiveLevel, this.uiColors))
    .borderRadius(26)
    .border({ width: this.nativeAvailable && this.blurRadius > 0 ? 0 : 0.65,
      color: glassLightColor(this.uiColors.glassEdge, 0.65) })
    .scale({ x: this.pressScale + this.squeeze * 0.06, y: this.pressScale - this.squeeze * 0.1 })
    .stateEffect(false)
    .accessibilityText(this.description())
    .id('chat-tools-anchor')
    .accessibilityLevel(this.revealed ? 'auto' : 'no-hide-descendants')
    .enabled(this.revealed)
    .onTouch((event: TouchEvent): void => { this.touchChanged(event); })
    .onClick((): void => {
      if (this.menuOrigin.presented) { this.menuOrigin.toggle(); return; }
      this.onInteractionChange(true);
      this.menuOrigin.openMenu(this.getUIContext(), 'chat-tools-anchor', 304,
        ['精简上下文', this.state.attachments > 0 ? `添加图片 · 已附加 ${this.state.attachments} 张` : '添加图片']);
    })
    .bindContentCover($$this.menuOrigin.presented, this.toolsCover(), {
      modalTransition: ModalTransition.NONE, backgroundColor: Color.Transparent,
      onWillDismiss: (): void => { this.menuOrigin.close(); },
      onDisappear: (): void => {
        this.menuOrigin.dismissed();
        this.panelChanged();
      }
    })
  }
}
