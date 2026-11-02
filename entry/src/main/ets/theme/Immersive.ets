import { PersonalizationStore } from './PersonalizationStore';

export const IMMERSIVE_KEY: string = 'immersiveLevel';
export const IMMERSIVE_DEFAULT: number = 3;

export interface ImmersivePreset {
  label: string;
  hint: string;
  blurRadius: number;
  saturation: number;
  brightness: number;
  tint: ResourceColor;
  haloAlpha: number;
}

export const IMMERSIVE_PRESETS: ImmersivePreset[] = [
  { label: '轻柔', hint: '轻盈材质，专注阅读', blurRadius: 16, saturation: 1.08, brightness: 1.0,
    tint: $r('app.color.glassTint'), haloAlpha: 0.04 },
  { label: '均衡', hint: '柔和透光，清晰分层', blurRadius: 28, saturation: 1.15, brightness: 1.0,
    tint: $r('app.color.glassTint'), haloAlpha: 0.08 },
  { label: '通透', hint: '更丰富的光影层次', blurRadius: 40, saturation: 1.25, brightness: 1.02,
    tint: $r('app.color.glassTint'), haloAlpha: 0.12 },
  { label: '光场', hint: '流动高光与柔和反射；光源跟随可在智感握持中单独设置', blurRadius: 28, saturation: 1.32, brightness: 1.02,
    tint: $r('app.color.glassTint'), haloAlpha: 0.18 }
];

export class Immersive {
  static level(): number {
    return Immersive.clamp(AppStorage.get<number>(IMMERSIVE_KEY) ?? IMMERSIVE_DEFAULT);
  }

  private static clamp(level: number): number {
    return Number.isFinite(level) ? Math.max(0, Math.min(IMMERSIVE_PRESETS.length - 1, Math.round(level))) : IMMERSIVE_DEFAULT;
  }

  static presetOf(level: number): ImmersivePreset {
    return IMMERSIVE_PRESETS[Immersive.clamp(level)];
  }

  static preset(): ImmersivePreset {
    return Immersive.presetOf(Immersive.level());
  }

  static setLevel(level: number): void {
    PersonalizationStore.set(IMMERSIVE_KEY, Immersive.clamp(level));
  }

  static label(level: number): string {
    return Immersive.presetOf(level).label;
  }
}
