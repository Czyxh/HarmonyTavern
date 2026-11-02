import { COLORS, ColorTokens } from '../theme/Tokens';
import { GLASS_INPUT, glassEffect, glassLightColor } from '../theme/Glass';
import { LS_BLUR_DEFAULT, LS_BLUR_KEY } from '../theme/LightSense';
import { IMMERSIVE_DEFAULT, IMMERSIVE_KEY } from '../theme/Immersive';
import { NativeGlassBackdrop } from './NativeGlassBackdrop';
import { SystemGlass } from '../theme/SystemGlass';
import { iconTint } from '../theme/IconTint';

interface JournalAction { id: string; label: string; icon: Resource; }

const ACTIONS: JournalAction[] = [
  { id: 'quests', label: '任务书', icon: $r('app.media.icon_journal') },
  { id: 'relationships', label: '人物好感度', icon: $r('app.media.icon_relationship') },
  { id: 'equipment', label: '装备栏', icon: $r('app.media.icon_equipment') },
  { id: 'settings', label: '状态栏设置', icon: $r('app.media.icon_settings') }
];

@Styles
function journalNormal() { .opacity(1) }
@Styles
function journalPressed() { .opacity(0.68) }

@Component
export struct WorldJournalDock {
  @StorageProp('uiColors') colors: ColorTokens = COLORS;
  @StorageProp(LS_BLUR_KEY) blurRadius: number = LS_BLUR_DEFAULT;
  @StorageProp(IMMERSIVE_KEY) immersiveLevel: number = IMMERSIVE_DEFAULT;
  @StorageProp('systemMaterialAvailable') nativeAvailable: boolean = false;
  @StorageProp('reduceMotion') @Watch('motionChanged') reduceMotion: boolean = false;
  @StorageProp('appWindowWidth') windowWidth: number = 400;
  @StorageProp('appWindowHeight') windowHeight: number = 800;
  @StorageProp('systemTopInset') topInset: number = 0;
  @StorageProp('systemBottomInset') bottomInset: number = 0;
  @Prop onRight: boolean = true;
  @Prop busy: boolean = false;
  @State expanded: boolean = false;
  @State progress: number = 0;
  @State dockRight: boolean = true;
  @State railVisible: boolean = false;
  @State cupAngle: number = 0;
  private revision: number = 0;
  onSection: (section: string, onRight: boolean, sourceId: string) => void = (): void => {};

  private motionChanged(): void {
    if (this.reduceMotion) { this.revision++; this.progress = this.expanded ? 1 : 0; this.railVisible = this.expanded; this.cupAngle = 0; }
  }
  private right(): boolean { return this.expanded || this.railVisible ? this.dockRight : this.onRight; }
  private top(): number {
    return Math.max(this.topInset + 108, Math.min(this.windowHeight * 0.36, this.windowHeight - this.bottomInset - 330));
  }
  private toggle(): void {
    if (!this.expanded && !this.railVisible) { this.dockRight = this.onRight; }
    this.expanded = !this.expanded;
    const revision: number = ++this.revision;
    if (this.expanded) { this.railVisible = true; }
    this.getUIContext().animateTo({ duration: this.reduceMotion ? 0 : 140, curve: Curve.EaseInOut }, (): void => {
      this.cupAngle = this.reduceMotion ? 0 : (this.right() ? -112 : 112);
    });
    this.getUIContext().animateTo({ duration: this.reduceMotion ? 0 : 360,
      delay: this.reduceMotion || !this.expanded ? 0 : 100, curve: Curve.EaseInOut,
      onFinish: (): void => {
        if (revision !== this.revision) { return; }
        if (!this.expanded) { this.railVisible = false; }
        this.getUIContext().animateTo({ duration: this.reduceMotion ? 0 : 180, curve: Curve.EaseOut }, (): void => { this.cupAngle = 0; });
      }
    }, (): void => {
      this.progress = this.expanded ? 1 : 0;
    });
  }
  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.railVisible) {
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.nativeAvailable && this.blurRadius > 0 && SystemGlass.supported()) {
          NativeGlassBackdrop({ fillParent: true, radius: 28 })
        }
      Column({ space: 4 }) {
        Blank().height(48)
        ForEach(ACTIONS, (action: JournalAction) => {
          Button({ type: ButtonType.Circle }) {
            Image(action.icon).width(21).height(21).colorFilter(iconTint(this.colors.textPrimary))
          }.width(44).height(44).padding(0).backgroundColor(Color.Transparent)
            .stateEffect(false).stateStyles({ normal: journalNormal, pressed: journalPressed }).focusOnTouch(false).id('world-journal-action-' + action.id).accessibilityText(action.label)
            .onClick((): void => { this.onSection(action.id, this.right(), 'world-journal-action-' + action.id); })
        }, (action: JournalAction): string => action.id)
      }.width(52).padding({ top: 4, bottom: 6 }).opacity(this.progress)
      }.width(12 + 40 * this.progress).height(12 + 238 * this.progress).borderRadius(28).clip(true)
        .backgroundColor(Color.Transparent)
        .backgroundEffect(this.nativeAvailable && this.blurRadius > 0 ? { radius: 0, color: Color.Transparent } :
          glassEffect(GLASS_INPUT, this.blurRadius, this.immersiveLevel, this.colors))
        .border({ width: this.nativeAvailable && this.blurRadius > 0 ? 0 : 0.65, color: glassLightColor(this.colors.glassEdge, 0.65) })
        .opacity(this.progress)
        .rotate({ angle: (1 - this.progress) * (this.right() ? 18 : -18), centerX: 26, centerY: 38 })
        .translate({ x: (1 - this.progress) * 20 * (this.right() ? 1 : -1), y: (1 - this.progress) * 38 })
        .enabled(this.expanded).id('world-journal-rail')
      }
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.startIcon')).width(48).height(48).objectFit(ImageFit.Contain)
          .rotate({ angle: this.cupAngle, centerX: 24, centerY: 30 })
          .scale({ x: 1 - this.progress * 0.18, y: 1 - this.progress * 0.18 })
          .translate({ x: (1 - this.progress) * 23 * (this.right() ? 1 : -1) })
      }.width(52).height(52).padding(0).backgroundColor(Color.Transparent).clip(false)
        .focusOnTouch(false).stateEffect(false).id('chat-world-journal')
        .accessibilityText(this.expanded ? '收起冒险工具栏' : '展开冒险工具栏')
        .onClick((): void => { this.toggle(); })
      if (this.busy && this.expanded) {
        LoadingProgress().width(8).height(8).color(this.colors.accent).position({ x: 37, y: 37 }).hitTestBehavior(HitTestMode.None)
      }
    }.width(52).height(this.railVisible ? 250 : 52).hitTestBehavior(HitTestMode.Transparent)
      .position({ x: this.right() ? this.windowWidth - 52 - this.progress * 8 : this.progress * 8, y: this.top() })
  }
}
