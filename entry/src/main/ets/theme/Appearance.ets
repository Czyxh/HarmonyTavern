import { ColorTokens } from './Tokens';
import { ThemeControl, UIContext } from '@kit.ArkUI';
import { CustomPalette } from './CustomPalette';
import { PersonalizationStore } from './PersonalizationStore';
import { RPG_THEMES, RpgThemes, RpgThemeDefinition } from './RpgThemes';

export const BACKGROUND_KEY: string = 'appearanceBackground';
export const BACKGROUND_DEFAULT: string = 'paper';
export const APP_DARK_KEY: string = 'appearanceIsDark';
export const COLOR_TRANSITION_KEY: string = 'appearanceColorTransition';

export interface BackgroundPalette {
  id: string;
  label: string;
  description: string;
  background: ResourceColor;
  surface: ResourceColor;
  surfaceHigh: ResourceColor;
  fadeTop: ResourceColor;
  fadeMiddle: ResourceColor;
  fadeEnd: ResourceColor;
}

export const BACKGROUND_PALETTES: BackgroundPalette[] = [
  {
    id: 'paper', label: '护眼纸张', description: '暖纸底色，深墨文字',
    background: $r('app.color.paperBackground'), surface: $r('app.color.paperSurface'),
    surfaceHigh: $r('app.color.paperSurfaceHigh'), fadeTop: $r('app.color.paperFadeTop'),
    fadeMiddle: $r('app.color.paperFadeMiddle'), fadeEnd: $r('app.color.paperFadeEnd')
  },
  {
    id: 'sage', label: '柔雾绿', description: '低饱和，柔和耐看',
    background: $r('app.color.sageBackground'), surface: $r('app.color.sageSurface'),
    surfaceHigh: $r('app.color.sageSurfaceHigh'), fadeTop: $r('app.color.sageFadeTop'),
    fadeMiddle: $r('app.color.sageFadeMiddle'), fadeEnd: $r('app.color.sageFadeEnd')
  },
  {
    id: 'sand', label: '暖米色', description: '温润的纸张色调',
    background: $r('app.color.sandBackground'), surface: $r('app.color.sandSurface'),
    surfaceHigh: $r('app.color.sandSurfaceHigh'), fadeTop: $r('app.color.sandFadeTop'),
    fadeMiddle: $r('app.color.sandFadeMiddle'), fadeEnd: $r('app.color.sandFadeEnd')
  },
  {
    id: 'mist', label: '静雾蓝', description: '清淡、安静的灰蓝',
    background: $r('app.color.mistBackground'), surface: $r('app.color.mistSurface'),
    surfaceHigh: $r('app.color.mistSurfaceHigh'), fadeTop: $r('app.color.mistFadeTop'),
    fadeMiddle: $r('app.color.mistFadeMiddle'), fadeEnd: $r('app.color.mistFadeEnd')
  },
  {
    id: 'moon', label: '月白', description: '简洁的中性浅灰',
    background: $r('app.color.moonBackground'), surface: $r('app.color.moonSurface'),
    surfaceHigh: $r('app.color.moonSurfaceHigh'), fadeTop: $r('app.color.moonFadeTop'),
    fadeMiddle: $r('app.color.moonFadeMiddle'), fadeEnd: $r('app.color.moonFadeEnd')
  }
];

export class Appearance {
  static onApplied: (colors: ColorTokens) => void = (): void => {};

  static palettes(): BackgroundPalette[] {
    return BACKGROUND_PALETTES.concat([Appearance.palette('rose'), Appearance.palette('custom')],
      RPG_THEMES.map((theme: RpgThemeDefinition): BackgroundPalette => Appearance.palette(theme.id)));
  }

  static palette(id: string): BackgroundPalette {
    const rpg: RpgThemeDefinition | undefined = RpgThemes.find(id);
    if (rpg !== undefined) {
      const colors: ColorTokens = RpgThemes.colors(id);
      const base: string = colors.bgBase as string;
      return {
        id: rpg.id, label: rpg.label, description: rpg.description,
        background: colors.bgBase, surface: colors.bgSurface, surfaceHigh: colors.bgSurfaceHigh,
        fadeTop: CustomPalette.alpha(base, 'CC'), fadeMiddle: CustomPalette.alpha(base, '66'),
        fadeEnd: CustomPalette.alpha(base, '00')
      };
    }
    if (id === 'rose' || id === 'custom') {
      const colors: ColorTokens = Appearance.generatedColors(id);
      const base: string = colors.bgBase as string;
      return {
        id: id, label: id === 'rose' ? '玫瑰粉' : '自定义',
        description: id === 'rose' ? '柔粉底色，玫瑰点缀' : '调配自己的底色与主题色',
        background: colors.bgBase, surface: colors.bgSurface, surfaceHigh: colors.bgSurfaceHigh,
        fadeTop: CustomPalette.alpha(base, 'CC'), fadeMiddle: CustomPalette.alpha(base, '66'),
        fadeEnd: CustomPalette.alpha(base, '00')
      };
    }
    return BACKGROUND_PALETTES.find((palette: BackgroundPalette) => palette.id === id) ?? BACKGROUND_PALETTES[0];
  }

  private static generatedColors(id: string): ColorTokens {
    const dark: boolean = AppStorage.get<boolean>(APP_DARK_KEY) ?? false;
    return id === 'custom' ? CustomPalette.colors(CustomPalette.saved(dark, false), CustomPalette.saved(dark, true))
      : CustomPalette.colors(dark ? '#281E25' : '#F4E5EB', dark ? '#EDA1BC' : '#A34268');
  }

  static selectBackground(id: string, context?: UIContext): void {
    const selected: string = Appearance.palette(id).id;
    const colors: ColorTokens = Appearance.colors(selected);
    const apply: () => void = (): void => {
      PersonalizationStore.set(BACKGROUND_KEY, selected);
      AppStorage.setOrCreate('uiColors', colors);
      ThemeControl.setDefaultTheme(Appearance.theme(selected));
    };
    if (context && (AppStorage.get<boolean>(COLOR_TRANSITION_KEY) ?? true) && !AppStorage.get<boolean>('reduceMotion')) {
      context.animateTo({ duration: 240, curve: Curve.EaseInOut }, apply);
    } else {
      apply();
    }
    Appearance.onApplied(colors);
  }

  static colors(id: string): ColorTokens {
    if (RpgThemes.find(id) !== undefined) { return RpgThemes.colors(id); }
    if (id === 'rose' || id === 'custom') { return Appearance.generatedColors(id); }
    const palette: BackgroundPalette = Appearance.palette(id);
    const paper: boolean = palette.id === 'paper';
    if (!paper) {
      const dark: boolean = AppStorage.get<boolean>(APP_DARK_KEY) ?? false;
      const base: string = palette.id === 'sage' ? (dark ? '#151C18' : '#E8EEE7') :
        palette.id === 'sand' ? (dark ? '#211E18' : '#F0EADF') :
        palette.id === 'mist' ? (dark ? '#171E25' : '#E5EBF0') : (dark ? '#1A1C20' : '#ECEDEF');
      const accent: string = palette.id === 'sage' ? (dark ? '#A8C5AA' : '#48634D') :
        palette.id === 'sand' ? (dark ? '#D8BA8B' : '#88683D') :
        palette.id === 'mist' ? (dark ? '#9AC0D6' : '#466B7F') : (dark ? '#BCA9E4' : '#66558C');
      const colors: ColorTokens = CustomPalette.colors(base, accent);
      colors.bgBase = palette.background;
      colors.bgSurface = palette.surface;
      colors.bgSurfaceHigh = palette.surfaceHigh;
      return colors;
    }
    return {
      bgBase: palette.background, bgSurface: palette.surface, bgSurfaceHigh: palette.surfaceHigh,
      textPrimary: paper ? $r('app.color.paperInk') : $r('app.color.textPrimary'),
      textSecondary: paper ? $r('app.color.paperInkSecondary') : $r('app.color.textSecondary'),
      textTertiary: paper ? $r('app.color.paperInkTertiary') : $r('app.color.textTertiary'),
      textInverse: paper ? $r('app.color.paperOnAccent') : $r('app.color.textInverse'),
      accent: paper ? $r('app.color.paperAccent') : $r('app.color.accent'),
      accentPressed: paper ? $r('app.color.paperAccentPressed') : $r('app.color.accentPressed'),
      accentContainer: paper ? $r('app.color.paperAccentContainer') : $r('app.color.accentContainer'),
      borderSubtle: paper ? $r('app.color.paperBorder') : $r('app.color.borderSubtle'),
      borderStrong: paper ? $r('app.color.paperBorder') : $r('app.color.borderStrong'),
      danger: $r('app.color.danger'), dangerContainer: $r('app.color.dangerContainer'),
      success: $r('app.color.success'), warning: $r('app.color.warning'),
      glassTint: paper ? $r('app.color.paperGlassTint') : $r('app.color.glassTint'),
      glassEdge: paper ? $r('app.color.paperGlassEdge') : $r('app.color.glassEdge'),
      dockTint: paper ? $r('app.color.paperDockTint') : $r('app.color.dockTint'),
      lensTint: paper ? $r('app.color.paperLensTint') : $r('app.color.lensTint'),
      headerButtonTint: paper ? $r('app.color.paperHeaderTint') : $r('app.color.headerButtonTint'),
      highlight: paper ? $r('app.color.paperHighlight') : $r('app.color.headerButtonHighlight'),
      clear: paper ? $r('app.color.paperClear') : $r('app.color.headerButtonClear'),
      reflection: paper ? $r('app.color.paperReflection') : $r('app.color.headerButtonReflection'),
      softShadow: paper ? $r('app.color.paperShadow') : $r('app.color.softShadow')
    };
  }

  static theme(id: string): CustomTheme {
    const colors: ColorTokens = Appearance.colors(id);
    return {
      colors: {
        brand: colors.accent,
        fontPrimary: colors.textPrimary,
        fontSecondary: colors.textSecondary,
        fontTertiary: colors.textTertiary,
        fontEmphasize: colors.accent,
        fontOnPrimary: colors.textInverse,
        iconPrimary: colors.textPrimary,
        iconSecondary: colors.textSecondary,
        iconEmphasize: colors.accent,
        compForegroundPrimary: colors.textInverse,
        compBackgroundEmphasize: colors.accent,
        compDivider: colors.borderSubtle,
        compBackgroundPrimary: colors.bgSurface,
        compBackgroundSecondary: colors.bgSurfaceHigh,
        compBackgroundTertiary: colors.bgSurfaceHigh,
        backgroundPrimary: colors.bgBase,
        backgroundSecondary: colors.bgSurface,
        backgroundTertiary: colors.bgSurfaceHigh
      }
    };
  }
}
