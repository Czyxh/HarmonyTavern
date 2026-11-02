import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { BACKGROUND_KEY, BACKGROUND_DEFAULT } from '../theme/Appearance';
import { RpgThemes } from '../theme/RpgThemes';

@Component
export struct IdentityAvatar {
  @StorageProp(BACKGROUND_KEY) backgroundId: string = BACKGROUND_DEFAULT;
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @Prop name: string = '';
  @Prop diameter: number = 52;
  @Prop @Watch('resetImage') source: string = '';
  @State imageFailed: boolean = false;

  private resetImage(): void {
    this.imageFailed = false;
  }

  private avatarRadius(): number {
    if (this.backgroundId === 'rpg_pixel') { return 2; }
    if (this.backgroundId === 'rpg_dungeon') { return 4; }
    return RpgThemes.find(this.backgroundId) !== undefined ? this.diameter / 2 : this.diameter * 0.34;
  }

  build() {
    Stack() {
      Text(this.name.trim().substring(0, 1).toUpperCase() || '✦')
        .fontSize(this.diameter * 0.38)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.uiColors.accent)
        .width(this.diameter)
        .height(this.diameter)
        .textAlign(TextAlign.Center)
        .linearGradient({
          angle: 135,
          colors: [[this.uiColors.accentContainer, 0], [this.uiColors.bgSurfaceHigh, 1]]
        })
        .borderRadius(this.avatarRadius())
        .border({ width: 1, color: this.uiColors.glassEdge })
        .accessibilityLevel('no')
      if (this.source !== '' && !this.imageFailed) {
        Image(this.source)
          .width(this.diameter)
          .height(this.diameter)
          .objectFit(ImageFit.Cover)
          .onError(() => { this.imageFailed = true; })
          .accessibilityLevel('no')
      }
    }
    .width(this.diameter)
    .height(this.diameter)
    .borderRadius(this.avatarRadius())
    .clip(true)
    .accessibilityLevel('no-hide-descendants')
  }
}
