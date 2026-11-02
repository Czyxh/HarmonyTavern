export interface ColorTokens {
  bgBase: ResourceColor;
  bgSurface: ResourceColor;
  bgSurfaceHigh: ResourceColor;
  borderSubtle: ResourceColor;
  borderStrong: ResourceColor;
  textPrimary: ResourceColor;
  textSecondary: ResourceColor;
  textTertiary: ResourceColor;
  textInverse: ResourceColor;
  accent: ResourceColor;
  accentPressed: ResourceColor;
  accentContainer: ResourceColor;
  danger: ResourceColor;
  dangerContainer: ResourceColor;
  success: ResourceColor;
  warning: ResourceColor;
  glassTint: ResourceColor;
  glassEdge: ResourceColor;
  dockTint: ResourceColor;
  lensTint: ResourceColor;
  headerButtonTint: ResourceColor;
  highlight: ResourceColor;
  clear: ResourceColor;
  reflection: ResourceColor;
  softShadow: ResourceColor;
}

export const COLORS: ColorTokens = {
  bgBase: $r('app.color.paperBackground'),
  bgSurface: $r('app.color.paperSurface'),
  bgSurfaceHigh: $r('app.color.paperSurfaceHigh'),
  borderSubtle: $r('app.color.paperBorder'),
  borderStrong: $r('app.color.paperBorder'),
  textPrimary: $r('app.color.paperInk'),
  textSecondary: $r('app.color.paperInkSecondary'),
  textTertiary: $r('app.color.paperInkTertiary'),
  textInverse: $r('app.color.paperOnAccent'),
  accent: $r('app.color.paperAccent'),
  accentPressed: $r('app.color.paperAccentPressed'),
  accentContainer: $r('app.color.paperAccentContainer'),
  danger: $r('app.color.danger'),
  dangerContainer: $r('app.color.dangerContainer'),
  success: $r('app.color.success'),
  warning: $r('app.color.warning'),
  glassTint: $r('app.color.paperGlassTint'),
  glassEdge: $r('app.color.paperGlassEdge'),
  dockTint: $r('app.color.paperDockTint'),
  lensTint: $r('app.color.paperLensTint'),
  headerButtonTint: $r('app.color.paperHeaderTint'),
  highlight: $r('app.color.paperHighlight'),
  clear: $r('app.color.paperClear'),
  reflection: $r('app.color.paperReflection'),
  softShadow: $r('app.color.paperShadow')
};

export const DARK_COLORS: ColorTokens = COLORS;
export const LIGHT_COLORS: ColorTokens = COLORS;

export class Typography {
  static readonly display: number = 32;
  static readonly title: number = 22;
  static readonly subtitle: number = 17;
  static readonly body: number = 15;
  static readonly caption: number = 13;
  static readonly micro: number = 12;
  static readonly bodyLineHeight: number = 1.6;
}

export class Spacing {
  static readonly xs: number = 4;
  static readonly sm: number = 8;
  static readonly md: number = 12;
  static readonly lg: number = 20;
  static readonly xl: number = 24;
  static readonly xxl: number = 32;
}

export class Radius {
  static readonly sm: number = 12;
  static readonly md: number = 20;
  static readonly lg: number = 28;
  static readonly pill: number = 999;
}

export class Touch {
  static readonly minTarget: number = 44;
  static readonly rowHeight: number = 72;
}

export class Motion {
  static readonly instant: number = 100;
  static readonly short: number = 150;
  static readonly local: number = 200;
  static readonly full: number = 300;
}
