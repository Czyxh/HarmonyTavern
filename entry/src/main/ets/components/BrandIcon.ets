import { BrandIcons } from '../theme/BrandIcons';
import { iconTint } from '../theme/IconTint';
import { COLORS, ColorTokens } from '../theme/Tokens';

@Component
export struct BrandIcon {
  @StorageProp('uiColors') colors: ColorTokens = COLORS;
  @Prop provider: string = '';
  @Prop model: string = '';
  @Prop diameter: number = 24;
  @Prop framed: boolean = false;

  private brand(): string {
    return this.model.trim() !== '' ? BrandIcons.model(this.model) : BrandIcons.provider(this.provider);
  }

  build() {
    Stack() {
      if (this.brand() === '' || BrandIcons.monochrome(this.brand())) {
        Image(this.brand() === '' && this.framed ? $r('app.media.icon_cloud') : BrandIcons.resource(this.brand()))
          .width(this.framed ? this.diameter * 0.62 : this.diameter)
          .height(this.framed ? this.diameter * 0.62 : this.diameter)
          .objectFit(ImageFit.Contain)
          .colorFilter(iconTint(this.brand() === '' ? this.colors.accent : this.colors.textPrimary))
      } else {
        Image(BrandIcons.resource(this.brand()))
          .width(this.framed ? this.diameter * 0.62 : this.diameter)
          .height(this.framed ? this.diameter * 0.62 : this.diameter)
          .objectFit(ImageFit.Contain)
      }
    }
    .width(this.diameter).height(this.diameter)
    .backgroundColor(this.framed ? this.colors.bgSurfaceHigh : Color.Transparent)
    .borderRadius(this.framed ? this.diameter * 0.34 : 0)
    .accessibilityLevel('no-hide-descendants')
  }
}
