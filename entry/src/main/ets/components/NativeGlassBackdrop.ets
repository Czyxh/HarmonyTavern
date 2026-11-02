import { CommonModifier } from '@kit.ArkUI';
import { COLORS, ColorTokens } from '../theme/Tokens';
import { IMMERSIVE_DEFAULT, IMMERSIVE_KEY } from '../theme/Immersive';
import { SystemGlass } from '../theme/SystemGlass';

class NativeSurfaceStyle implements AttributeModifier<CommonAttribute> {
  private colors: ColorTokens;
  private level: number;
  private reading: boolean;
  constructor(colors: ColorTokens, level: number, reading: boolean) {
    this.colors = colors; this.level = level; this.reading = reading;
  }
  applyNormalAttribute(node: CommonAttribute): void {
    node.systemMaterial(this.reading ? SystemGlass.reading(this.level, this.colors) : SystemGlass.navigation(this.level, this.colors));
  }
}

@Component
export struct NativeGlassBackdrop {
  @StorageProp('uiColors') colors: ColorTokens = COLORS;
  @StorageProp(IMMERSIVE_KEY) immersiveLevel: number = IMMERSIVE_DEFAULT;
  @Prop radius: number = 22;
  @Prop diameter: number = 44;
  @Prop fillParent: boolean = false;
  @Prop readingSurface: boolean = false;
  @Builder
  material() {
    Stack() {
      Column().width('calc(100% + 24vp)').height('calc(100% + 8vp)')
        .position({ x: -12, y: -4 }).borderRadius(this.radius)
        .attributeModifier(new NativeSurfaceStyle(this.colors, this.immersiveLevel, this.readingSurface))
    }.width('100%').height('100%')
  }

  build() {
    Tabs({ barPosition: BarPosition.End,
      barModifier: new CommonModifier().padding(0).systemMaterial(SystemGlass.empty()).backgroundColor(Color.Transparent) }) {
      TabContent() { Column().height(0) }.tabBar(this.material())
    }
    .barWidth('100%').barHeight('100%', true).barOverlap(true).vertical(false)
    .barBackgroundColor(Color.Transparent).barBackgroundEffect({ radius: 0, color: Color.Transparent })
    .scrollable(false).animationDuration(0).width('100%').height(this.fillParent ? '100%' : this.diameter)
    .backgroundColor(Color.Transparent).borderRadius(this.radius).clip(true)
    .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
  }
}
