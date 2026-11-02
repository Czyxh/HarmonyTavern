import { PersonalizationStore } from './PersonalizationStore';

export const LS_BLUR_KEY: string = 'lightSenseBlur';
export const LS_BLUR_DEFAULT: number = 4;
export const LS_BLUR_REFERENCE: number = 28;
export const LS_BLUR_MIN: number = 0;
export const LS_BLUR_MAX: number = 60;

export class LightSense {
  static blurRadius(): number {
    const value: number = AppStorage.get<number>(LS_BLUR_KEY) ?? LS_BLUR_DEFAULT;
    return Number.isFinite(value) ? Math.max(LS_BLUR_MIN, Math.min(LS_BLUR_MAX, value)) : LS_BLUR_DEFAULT;
  }

  static setBlurRadius(value: number): void {
    PersonalizationStore.set(LS_BLUR_KEY, Number.isFinite(value)
      ? Math.max(LS_BLUR_MIN, Math.min(LS_BLUR_MAX, value)) : LS_BLUR_DEFAULT);
  }

  static effectiveRadius(specRadius: number): number {
    return Math.min(48, specRadius * LightSense.blurRadius() / LS_BLUR_REFERENCE);
  }
}
