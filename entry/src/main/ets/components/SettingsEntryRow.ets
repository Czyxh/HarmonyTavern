import { iconTint } from '../theme/IconTint';
import { COLORS, ColorTokens } from '../theme/Tokens';
import { glassLightColor } from '../theme/Glass';
import { RpgThemes } from '../theme/RpgThemes';

@Styles
function settingRest() { .opacity(1) }
@Styles
function settingPress() { .opacity(0.64) }

/** A compact row inside a shared settings surface; each row keeps its own touch target. */
@Component
export struct SettingsEntryRow {
  @StorageProp('uiColors') colors: ColorTokens = COLORS;
  @Prop label: string = '';
  @Prop detail: string = '';
  @Prop icon: Resource = $r('app.media.icon_settings');
  @Prop marker: string = '';
  @Prop last: boolean = false;
  onOpen: () => void = (): void => {};

  build() {
    Column({ space: 0 }) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 13 }) {
          Stack() {
            Image(this.icon).width(21).height(21).colorFilter(iconTint(this.colors.accent))
          }.width(40).height(40).borderRadius(RpgThemes.radius(15))
            .backgroundColor(this.colors.accentContainer)
            .border({ width: 0.6, color: glassLightColor(this.colors.glassEdge, 0.65) })
            .accessibilityLevel('no-hide-descendants')
          Column({ space: 4 }) {
            Text(this.label).fontSize(16).fontWeight(FontWeight.Medium)
              .fontColor(this.colors.textPrimary).width('100%')
            Text(this.detail).fontSize(12).lineHeight(18).fontColor(this.colors.textSecondary)
              .width('100%')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Image($r('app.media.icon_chevron')).width(14).height(14)
            .colorFilter(iconTint(this.colors.textTertiary)).accessibilityLevel('no')
        }.width('100%').padding({ left: 16, right: 16, top: 16, bottom: 16 })
      }.width('100%').height('auto').constraintSize({ minHeight: 80 })
        .padding(0).borderRadius(0).backgroundColor(Color.Transparent)
        .stateStyles({ normal: settingRest, pressed: settingPress })
        .accessibilityText(this.label + '，' + this.detail).id(this.marker)
        .onClick((): void => { this.onOpen(); })
      if (!this.last) {
        Divider().strokeWidth(0.5).color(this.colors.borderSubtle)
          .margin({ left: 69, right: 16 })
      }
    }.width('100%')
  }
}
