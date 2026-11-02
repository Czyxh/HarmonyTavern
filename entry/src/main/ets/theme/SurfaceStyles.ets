import { ColorTokens } from './Tokens';
import { glassLightColor } from './Glass';
import { RpgThemes } from './RpgThemes';
import { RpgConversationStyle } from './RpgBubbleStyle';

/** Low-cost tonal elevation for content cards; navigation owns the live glass sampling. */
export class SurfaceStyle implements AttributeModifier<CommonAttribute> {
  private colors: ColorTokens;
  private radius: number;
  constructor(colors: ColorTokens, radius: number = 20) { this.colors = colors; this.radius = radius; }
  applyNormalAttribute(node: CommonAttribute): void {
    const theme = RpgThemes.active();
    if (theme !== undefined) {
      new RpgConversationStyle(theme.id, this.colors).applyNormalAttribute(node);
      return;
    }
    const radius: number = RpgThemes.radius(this.radius);
    node.backgroundColor(this.colors.bgSurface)
      .linearGradient({ angle: 145, colors: [[glassLightColor(this.colors.highlight, 0.12), 0],
        [this.colors.clear, 0.52], [glassLightColor(this.colors.reflection, 0.13), 1]] })
      .border({ radius: radius, width: RpgThemes.borderWidth(0.65), color: glassLightColor(this.colors.glassEdge, 0.65) })
      .borderRadius(radius)
      .shadow({ radius: 10, color: glassLightColor(this.colors.softShadow, 0.4), offsetY: 3 });
  }
}
