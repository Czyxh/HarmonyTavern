import { LightSense, LS_BLUR_REFERENCE } from './LightSense';
import { Immersive, ImmersivePreset } from './Immersive';
import { COLORS, ColorTokens } from './Tokens';
import { ColorMetrics } from '@kit.ArkUI';

export interface GlassSpec {
  blurRadius: number;
  saturation: number;
  brightness: number;
  tint: ResourceColor;
  edge: ResourceColor;
  radius: number;
}

export const HEADER_BLUR_BOOST: number = 15;

export function glassLightColor(color: ResourceColor, opacity: number): string {
  try {
    const resolved: ColorMetrics = ColorMetrics.resourceColor(color);
    const sourceAlpha: number = resolved.alpha > 1 ? resolved.alpha / 255 : resolved.alpha;
    const alpha: number = Math.round(255 * sourceAlpha * Math.max(0, Math.min(1, opacity)));
    return '#' + [alpha, resolved.red, resolved.green, resolved.blue]
      .map((channel: number): string => Math.max(0, Math.min(255, Math.round(channel))).toString(16).padStart(2, '0'))
      .join('');
  } catch (error) {
    return '#00FFFFFF';
  }
}

export const GLASS_TAB_BAR: GlassSpec = {
  blurRadius: 28, saturation: 1.55, brightness: 1.02,
  tint: $r('app.color.dockTint'), edge: $r('app.color.glassEdge'), radius: 28
};
export const GLASS_HEADER: GlassSpec = {
  blurRadius: 28, saturation: 1.08, brightness: 1.0,
  tint: $r('app.color.glassTint'), edge: $r('app.color.glassEdge'), radius: 24
};
export const GLASS_HEADER_BUTTON: GlassSpec = {
  blurRadius: 32, saturation: 1.45, brightness: 1.04,
  tint: $r('app.color.headerButtonTint'), edge: $r('app.color.lensEdge'), radius: 22
};
export const GLASS_LENS: GlassSpec = {
  blurRadius: 9, saturation: 1.7, brightness: 1.03,
  tint: $r('app.color.lensTint'), edge: $r('app.color.lensEdge'), radius: 22
};
export const GLASS_INPUT: GlassSpec = {
  blurRadius: 24, saturation: 1.3, brightness: 1.0,
  tint: $r('app.color.glassTint'), edge: $r('app.color.glassEdge'), radius: 28
};
export const GLASS_ORB: GlassSpec = {
  blurRadius: 36, saturation: 1.5, brightness: 1.03,
  tint: $r('app.color.headerButtonTint'), edge: $r('app.color.lensEdge'), radius: 26
};
export const GLASS_MENU: GlassSpec = {
  blurRadius: 56, saturation: 1.15, brightness: 1.02,
  tint: $r('app.color.glassTint'), edge: $r('app.color.glassEdge'), radius: 24
};
export const GLASS_CARD: GlassSpec = {
  blurRadius: 0, saturation: 1.0, brightness: 1.0,
  tint: COLORS.bgSurface, edge: COLORS.borderSubtle, radius: 20
};

export function glassEffect(spec: GlassSpec, strength: number = LightSense.blurRadius(), level: number = Immersive.level(), colors: ColorTokens = COLORS): BackgroundEffectOptions {
  const preset: ImmersivePreset = Immersive.presetOf(level);
  // The chat composer is the baseline for every glass action orb.
  const material: GlassSpec = spec === GLASS_HEADER_BUTTON || spec === GLASS_ORB || spec === GLASS_INPUT ? GLASS_TAB_BAR : spec;
  let radius: number = Math.min(48, material.blurRadius * Math.max(0, strength) / LS_BLUR_REFERENCE * preset.blurRadius / 28);
  if (strength > 0 && spec === GLASS_HEADER) {
    radius += HEADER_BLUR_BOOST;
  }
  let tint: ResourceColor = colors.glassTint;
  if (material === GLASS_TAB_BAR) { tint = glassLightColor(colors.dockTint, 0.78); }
  if (spec === GLASS_LENS) { tint = colors.clear; }
  return {
    radius: radius,
    saturation: radius > 0 ? Math.min(1.85, 1 + (material.saturation - 1) * preset.saturation / 1.15) : 1,
    brightness: material.brightness * preset.brightness,
    color: radius > 0 ? tint : colors.bgSurface,
    policy: BlurStyleActivePolicy.FOLLOWS_WINDOW_ACTIVE_STATE,
    inactiveColor: colors.bgSurface
  };
}

export function frostedEffect(blur: number, colors: ColorTokens): BackgroundEffectOptions {
  return {
    radius: blur > 0 ? Math.max(40, Math.min(64, blur)) : 0,
    saturation: 1, brightness: 1,
    color: blur > 0 ? colors.glassTint : colors.bgSurface,
    adaptiveColor: AdaptiveColor.DEFAULT,
    policy: BlurStyleActivePolicy.ALWAYS_ACTIVE,
    inactiveColor: colors.bgSurface
  };
}

export class Glass {
  static readonly tabBarHeight: number = 64;
  static readonly tabBarRadius: number = 32;
  static readonly inputRadius: number = 28;
  static readonly cardRadius: number = 20;
  static readonly pressScale: number = 0.98;
  static readonly pressDuration: number = 120;
  static readonly edgeHairline: ResourceColor = $r('app.color.glassEdge');
  static readonly softShadow: ResourceColor = $r('app.color.softShadow');
}
