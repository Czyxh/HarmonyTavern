import { RpgThemes } from '../theme/RpgThemes';
import { Appearance, BACKGROUND_DEFAULT, BACKGROUND_KEY } from '../theme/Appearance';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { GLASS_HEADER, glassEffect } from '../theme/Glass';
import { LS_BLUR_DEFAULT, LS_BLUR_KEY } from '../theme/LightSense';
import { IMMERSIVE_DEFAULT, IMMERSIVE_KEY } from '../theme/Immersive';
import { SCROLL_EDGE_OPTIONS, SCROLL_NESTED_OPTIONS } from '../theme/ScrollFeedback';
import { RpgBackdrop } from './RpgBackdrop';

@Component
export struct PageSurface {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @StorageProp(BACKGROUND_KEY) backgroundId: string = BACKGROUND_DEFAULT;
  @BuilderParam topBar: () => void;
  @BuilderParam content: () => void;
  @Prop scrollable: boolean = true;
  @Prop horizontalInset: number = 16;
  @Prop topContentInset: number = 104;
  @Prop bottomInset: number = 24;
  @Prop edgeFades: boolean = true;
  @StorageProp('systemTopInset') topInset: number = 0;
  @StorageProp('systemBottomInset') safeBottom: number = 0;
  @State viewportHeight: number = 0;
  @StorageProp(LS_BLUR_KEY) blurRadius: number = LS_BLUR_DEFAULT;
  @StorageProp(IMMERSIVE_KEY) immersiveLevel: number = IMMERSIVE_DEFAULT;

  private fadeStops(): FractionStop[] {
    const height: number = Math.max(this.topInset + 97, this.viewportHeight);
    return [[1, 0], [0.85, (this.topInset + 24) / height],
      [0.35, (this.topInset + 60) / height], [0, (this.topInset + 96) / height], [0, 1]];
  }

  private fadeRadius(): number {
    return this.edgeFades && this.viewportHeight > 0 ? glassEffect(GLASS_HEADER, this.blurRadius, this.immersiveLevel, this.uiColors).radius : 0;
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      RpgBackdrop()
      if (this.scrollable) {
        Scroll() {
          Column({ space: 0 }) {
            this.content()
          }
          .width('100%')
          .padding({ top: this.topInset + this.topContentInset, bottom: Math.max(this.bottomInset, this.safeBottom + 24),
            left: this.horizontalInset, right: this.horizontalInset })
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .edgeEffect(EdgeEffect.Spring, SCROLL_EDGE_OPTIONS)
        .nestedScroll(SCROLL_NESTED_OPTIONS)
        .backgroundColor(Color.Transparent)
        .linearGradientBlur(this.fadeRadius(), {
          fractionStops: this.fadeStops(), direction: GradientDirection.Bottom
        })
      } else {
        Column({ space: 0 }) {
          this.content()
        }
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
        .linearGradientBlur(this.fadeRadius(), {
          fractionStops: this.fadeStops(), direction: GradientDirection.Bottom
        })
      }
      Column().width('100%').height(this.topInset + 96)
        .linearGradient({ direction: GradientDirection.Bottom,
          colors: [[Appearance.palette(this.backgroundId).fadeTop, 0],
            [Appearance.palette(this.backgroundId).fadeMiddle, 0.55],
            [Appearance.palette(this.backgroundId).fadeEnd, 1]] })
        .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      Column({ space: 0 }) {
        Column().height(this.topInset)
        this.topBar()
      }
      .width('100%')
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.uiColors.bgBase)
    .onAreaChange((_previous: Area, current: Area): void => {
      this.viewportHeight = Number(current.height);
    })
  }
}
