import { ColorTokens } from './Tokens';
import { PersonalizationStore } from './PersonalizationStore';

export const CUSTOM_LIGHT_BACKGROUND: string = 'customLightBackground';
export const CUSTOM_LIGHT_ACCENT: string = 'customLightAccent';
export const CUSTOM_DARK_BACKGROUND: string = 'customDarkBackground';
export const CUSTOM_DARK_ACCENT: string = 'customDarkAccent';

export class CustomPalette {
  static initialize(): void {
    PersistentStorage.persistProp(CUSTOM_LIGHT_BACKGROUND, '#F4E5EB');
    PersistentStorage.persistProp(CUSTOM_LIGHT_ACCENT, '#A34268');
    PersistentStorage.persistProp(CUSTOM_DARK_BACKGROUND, '#281E25');
    PersistentStorage.persistProp(CUSTOM_DARK_ACCENT, '#EDA1BC');
  }

  static normalize(value: string): string {
    const trimmed: string = value.trim().replace(/^#/, '');
    if (/^[0-9a-fA-F]{6}$/.test(trimmed)) { return `#${trimmed.toUpperCase()}`; }
    if (/^[0-9a-fA-F]{3}$/.test(trimmed)) {
      return `#${trimmed.split('').map((digit: string) => digit + digit).join('').toUpperCase()}`;
    }
    return '';
  }

  static saved(dark: boolean, accent: boolean): string {
    const key: string = dark ? (accent ? CUSTOM_DARK_ACCENT : CUSTOM_DARK_BACKGROUND)
      : (accent ? CUSTOM_LIGHT_ACCENT : CUSTOM_LIGHT_BACKGROUND);
    const fallback: string = dark ? (accent ? '#EDA1BC' : '#281E25') : (accent ? '#A34268' : '#F4E5EB');
    return CustomPalette.normalize(AppStorage.get<string>(key) ?? '') || fallback;
  }

  static save(dark: boolean, background: string, accent: string): boolean {
    const base: string = CustomPalette.normalize(background);
    const primary: string = CustomPalette.normalize(accent);
    if (base === '' || primary === '') { return false; }
    PersonalizationStore.set(dark ? CUSTOM_DARK_BACKGROUND : CUSTOM_LIGHT_BACKGROUND, base);
    PersonalizationStore.set(dark ? CUSTOM_DARK_ACCENT : CUSTOM_LIGHT_ACCENT, primary);
    return true;
  }

  static channel(color: string, index: number): number {
    return parseInt(color.slice(1 + index * 2, 3 + index * 2), 16);
  }

  static fromChannels(red: number, green: number, blue: number): string {
    return '#' + [red, green, blue].map((value: number) =>
      Math.max(0, Math.min(255, Math.round(value))).toString(16).padStart(2, '0')).join('').toUpperCase();
  }

  static mix(base: string, target: string, amount: number): string {
    const channels: number[] = [0, 1, 2].map((index: number) =>
      CustomPalette.channel(base, index) * (1 - amount) + CustomPalette.channel(target, index) * amount);
    return CustomPalette.fromChannels(channels[0], channels[1], channels[2]);
  }

  static alpha(color: string, alpha: string): string {
    return `#${alpha}${color.slice(1)}`;
  }

  static luminance(color: string): number {
    const channels: number[] = [0, 1, 2].map((index: number) => {
      const value: number = CustomPalette.channel(color, index) / 255;
      return value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4);
    });
    return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722;
  }

  static contrast(first: string, second: string): number {
    const firstLight: number = CustomPalette.luminance(first);
    const secondLight: number = CustomPalette.luminance(second);
    return (Math.max(firstLight, secondLight) + 0.05) / (Math.min(firstLight, secondLight) + 0.05);
  }

  static readable(color: string, surfaces: string[], minimum: number = 4.5): string {
    const blackMinimum: number = Math.min(...surfaces.map((surface: string) => CustomPalette.contrast('#000000', surface)));
    const whiteMinimum: number = Math.min(...surfaces.map((surface: string) => CustomPalette.contrast('#FFFFFF', surface)));
    const target: string = blackMinimum >= whiteMinimum ? '#000000' : '#FFFFFF';
    for (let step: number = 0; step <= 100; step++) {
      const candidate: string = CustomPalette.mix(color, target, step / 100);
      if (surfaces.every((surface: string) => CustomPalette.contrast(candidate, surface) >= minimum)) { return candidate; }
    }
    return target;
  }

  static colors(background: string, primary: string): ColorTokens {
    const base: string = CustomPalette.normalize(background) || '#F4E5EB';
    const seed: string = CustomPalette.normalize(primary) || '#A34268';
    const dark: boolean = CustomPalette.luminance(base) < 0.179;
    const surface: string = CustomPalette.mix(base, dark ? '#000000' : '#FFFFFF', 0.14);
    const surfaceHigh: string = CustomPalette.mix(base, dark ? '#000000' : '#FFFFFF', 0.28);
    const accentContainer: string = CustomPalette.mix(base, dark ? '#000000' : '#FFFFFF', 0.2);
    const surfaces: string[] = [base, surface, surfaceHigh, accentContainer];
    const ink: string = CustomPalette.readable(dark ? '#F6EDF2' : '#30232A', surfaces, 7);
    const accent: string = CustomPalette.readable(seed, surfaces);
    const inverse: string = CustomPalette.readable('#FFFFFF', [accent]);
    const pressed: string = CustomPalette.readable(CustomPalette.mix(accent, inverse === '#FFFFFF' ? '#000000' : '#FFFFFF', 0.12), [inverse]);
    const highlight: string = dark ? '#F6EDF2' : '#FFFFFF';
    const dangerContainer: string = surfaceHigh;
    return {
      bgBase: base, bgSurface: surface, bgSurfaceHigh: surfaceHigh,
      borderSubtle: CustomPalette.mix(base, ink, 0.24), borderStrong: CustomPalette.mix(base, ink, 0.4),
      textPrimary: ink, textSecondary: CustomPalette.readable(CustomPalette.mix(ink, base, 0.25), surfaces),
      textTertiary: CustomPalette.readable(CustomPalette.mix(ink, base, 0.38), surfaces), textInverse: inverse,
      accent: accent, accentPressed: pressed, accentContainer: accentContainer,
      danger: CustomPalette.readable('#C44560', surfaces), dangerContainer: dangerContainer,
      success: CustomPalette.readable('#347654', surfaces), warning: CustomPalette.readable('#9B701B', surfaces),
      glassTint: CustomPalette.alpha(surface, 'B3'), glassEdge: CustomPalette.alpha(ink, '38'),
      dockTint: CustomPalette.alpha(surface, '66'), lensTint: CustomPalette.alpha(surface, '80'),
      headerButtonTint: CustomPalette.alpha(surface, 'A6'), highlight: CustomPalette.alpha(highlight, '80'),
      clear: CustomPalette.alpha(highlight, '00'), reflection: CustomPalette.alpha(accent, '24'),
      softShadow: CustomPalette.alpha(dark ? '#000000' : ink, '18')
    };
  }
}
