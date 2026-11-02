import { COLORS, ColorTokens } from '../theme/Tokens';
import { MOTION_REDUCE_KEY } from '../theme/Motion';
import { ReadingPreferences, READING_SIZE_KEY, READING_LINE_KEY, READING_FONT_KEY } from '../theme/ReadingPreferences';
import { StreamReveal } from '../theme/StreamReveal';

@Component
export struct StreamingText {
  onHeightChanged: () => void = (): void => {};
  @Prop @Watch('targetChanged') text: string = '';
  @Prop @Watch('targetChanged') active: boolean = false;
  @StorageProp(MOTION_REDUCE_KEY) @Watch('targetChanged') reduceMotion: boolean = false;
  @StorageProp('uiColors') colors: ColorTokens = COLORS;
  @StorageProp(READING_SIZE_KEY) fontSize: number = 15;
  @StorageProp(READING_LINE_KEY) lineHeight: number = 1.5;
  @StorageProp(READING_FONT_KEY) font: string = 'system';
  @State displayed: string = '';
  private timer: number = -1;
  private mounted: boolean = false;
  private lastFrame: number = 0;

  aboutToAppear(): void { this.mounted = true; this.targetChanged(); }
  aboutToDisappear(): void { this.mounted = false; this.clearTimer(); }

  private clearTimer(): void {
    if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; }
  }

  private targetChanged(): void {
    if (!this.mounted) { return; }
    if (!this.active || this.reduceMotion || !this.text.startsWith(this.displayed)) {
      this.clearTimer(); this.displayed = this.text; return;
    }
    if (this.timer >= 0 || this.displayed === this.text) { return; }
    this.lastFrame = Date.now();
    this.timer = setTimeout((): void => { this.reveal(); }, 16);
  }

  private reveal(): void {
    this.timer = -1;
    if (!this.mounted) { return; }
    const now: number = Date.now();
    this.displayed = this.text.substring(0, StreamReveal.boundary(this.text, this.displayed.length, now - this.lastFrame));
    this.lastFrame = now;
    if (this.displayed !== this.text) { this.timer = setTimeout((): void => { this.reveal(); }, 16); }
  }

  build() {
    Text(this.displayed || '正在回应…').fontSize(this.fontSize).lineHeight(this.fontSize * this.lineHeight)
      .fontFamily(ReadingPreferences.fontFamily(this.font))
      .fontColor(this.text === '' ? this.colors.textSecondary : this.colors.textPrimary)
      .copyOption(CopyOptions.LocalDevice).width('100%').id('chat-stream-text')
      .onAreaChange((previous: Area, current: Area): void => {
        if (Number(previous.height) !== Number(current.height)) { this.onHeightChanged(); }
      })
  }
}
