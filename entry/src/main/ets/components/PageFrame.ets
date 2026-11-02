import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';

@Component
export struct PageFrame {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @BuilderParam content: () => void;

  build() {
    Row() {
      Column() {
        this.content()
      }
      .width('100%')
      .constraintSize({ maxWidth: 1040 })
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.uiColors.bgBase)
  }
}
