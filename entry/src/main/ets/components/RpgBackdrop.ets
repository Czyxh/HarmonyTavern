import { Appearance, BACKGROUND_DEFAULT, BACKGROUND_KEY } from '../theme/Appearance';
import { RpgThemes } from '../theme/RpgThemes';

@Component
export struct RpgBackdrop {
  @StorageProp(BACKGROUND_KEY) backgroundId: string = BACKGROUND_DEFAULT;

  build() {
    if (RpgThemes.find(this.backgroundId) !== undefined) {
      Stack({ alignContent: Alignment.TopEnd }) {
        Image(RpgThemes.art(this.backgroundId)).width('100%').height(220)
          .objectFit(ImageFit.Cover).opacity(this.backgroundId === 'rpg_dungeon' ? 0.1 : 0.14)
          .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
        Column().width('100%').height(220)
          .linearGradient({ direction: GradientDirection.Bottom,
            colors: [[Appearance.palette(this.backgroundId).fadeEnd, 0],
              [Appearance.palette(this.backgroundId).fadeEnd, 0.35],
              [Appearance.palette(this.backgroundId).background, 1]] })
          .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
        Image(RpgThemes.texture(this.backgroundId)).width('100%').height('100%')
          .objectFit(ImageFit.Fill).opacity(this.backgroundId === 'rpg_pixel' ? 0.2 : 0.18)
          .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
        Image(RpgThemes.frame(this.backgroundId)).width('100%').height('100%')
          .objectFit(ImageFit.Fill).opacity(0.22)
          .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      }
      .width('100%').height('100%')
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
    }
  }
}
