import { ColorTokens } from './Tokens';
import { RpgThemes } from './RpgThemes';
import { glassLightColor } from './Glass';

/** RPG conversation surfaces keep opaque reading areas and never intercept touch. */
export class RpgBubbleStyle implements AttributeModifier<CommonAttribute> {
  private id: string;
  private colors: ColorTokens;
  private user: boolean;
  private focused: boolean;
  constructor(id: string, colors: ColorTokens, user: boolean, focused: boolean = false) {
    this.id = id; this.colors = colors; this.user = user; this.focused = focused;
  }
  applyNormalAttribute(node: CommonAttribute): void {
    if (RpgThemes.find(this.id) === undefined) { return; }
    const pixel: boolean = this.id === 'rpg_pixel';
    const sakura: boolean = this.id === 'rpg_sakura';
    const radius: number = pixel ? 2 : 14;
    const color: ResourceColor = this.focused ? this.colors.accent : (this.user ? this.colors.accent : this.colors.borderStrong);
    node.borderRadius({ topLeft: radius, topRight: radius,
      bottomLeft: this.user ? radius : Math.min(radius, 7), bottomRight: this.user ? Math.min(radius, 7) : radius })
      .border({ width: this.focused ? 2 : (pixel ? 2 : 0.8), color: color })
      .backgroundColor(this.user ? this.colors.accent : this.colors.bgSurface)
      .shadow({ radius: pixel || sakura ? 0 : 9, offsetX: pixel ? 3 : 0, offsetY: pixel ? 3 : (sakura ? 0 : 3),
        color: glassLightColor(this.colors.softShadow, sakura ? 0 : 0.45) });
  }
}

export class RpgConversationStyle implements AttributeModifier<CommonAttribute> {
  private id: string;
  private colors: ColorTokens;
  constructor(id: string, colors: ColorTokens) {
    this.id = id; this.colors = colors;
  }
  applyNormalAttribute(node: CommonAttribute): void {
    if (RpgThemes.find(this.id) === undefined) { return; }
    const pixel: boolean = this.id === 'rpg_pixel';
    const dungeon: boolean = this.id === 'rpg_dungeon';
    node.borderRadius(RpgThemes.find(this.id)?.radius ?? 12)
      .backgroundColor(this.colors.bgSurface)
      .border({ width: pixel ? 3 : 1, style: BorderStyle.Solid,
        color: { top: dungeon ? this.colors.accent : this.colors.borderSubtle,
          bottom: this.colors.borderSubtle, left: this.colors.borderSubtle, right: this.colors.borderSubtle } })
      .shadow({ radius: pixel || this.id === 'rpg_sakura' ? 0 : 12,
        offsetX: pixel ? 3 : 0, offsetY: pixel ? 3 : 4,
        color: this.id === 'rpg_sakura' ? Color.Transparent : glassLightColor(this.colors.softShadow, 0.45) });
  }
}
