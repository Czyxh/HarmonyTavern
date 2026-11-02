import { COLORS, ColorTokens } from '../theme/Tokens';
import { IMMERSIVE_DEFAULT, IMMERSIVE_KEY } from '../theme/Immersive';
import { SystemGlass } from '../theme/SystemGlass';
import { CommonModifier } from '@kit.ArkUI';

/** A supported bottom TabBar material region for the existing chat composer. */
@Component
export struct SystemMaterialTray {
  @StorageProp('uiColors') uiColors: ColorTokens = COLORS;
  @StorageProp(IMMERSIVE_KEY) immersiveLevel: number = IMMERSIVE_DEFAULT;
  @BuilderParam content: () => void;
  @State contentHeight: number = 56;

  @Builder
  trayContent() {
    Column() { this.content() }
      .width('100%').padding({ left: 6, right: 6, top: 2, bottom: 2 })
      .onAreaChange((_old: Area, area: Area): void => {
        // Include the native floating TabBar's 4vp top and bottom insets.
        const height: number = Math.max(56, Number(area.height) + 8);
        if (Math.abs(this.contentHeight - height) > 0.5) { this.contentHeight = height; }
      })
  }

  build() {
    Tabs({ barPosition: BarPosition.End, barModifier: new CommonModifier().padding(0) }) {
      TabContent() { Column().height(0) }.tabBar(this.trayContent())
    }
    .width('100%').height(this.contentHeight)
    .barHeight(this.contentHeight).barWidth('100%').barOverlap(true).vertical(false)
    .scrollable(false).animationDuration(0)
    .barFloatingStyle({ barSideMargin: 0, barBottomMargin: 0, maskHeight: 0,
      systemMaterial: SystemGlass.navigation(this.immersiveLevel, this.uiColors) })
    .backgroundColor(Color.Transparent)
    .id('system-material-composer')
  }
}
