import { PersonalizationStore } from './PersonalizationStore';

export const READING_SIZE_KEY: string = 'readingFontSize';
export const READING_LINE_KEY: string = 'readingLineHeight';
export const READING_FONT_KEY: string = 'readingFontFamily';
export const READING_INSET_KEY: string = 'readingInset';

export class ReadingPreferences {
  static fontFamily(selected: string): string {
    return selected === 'serif' ? 'serif' : selected === 'monospace' ? 'monospace' : 'HarmonyOS Sans';
  }

  static setNumber(key: string, value: number): void {
    if (!Number.isFinite(value)) { return; }
    if (key === READING_SIZE_KEY) { PersonalizationStore.set(key, Math.max(13, Math.min(22, Math.round(value)))); }
    else if (key === READING_LINE_KEY) { PersonalizationStore.set(key, Math.max(1.5, Math.min(2.4, value))); }
    else if (key === READING_INSET_KEY) { PersonalizationStore.set(key, Math.max(8, Math.min(24, Math.round(value)))); }
  }

  static reset(): void {
    PersonalizationStore.set(READING_SIZE_KEY, 15);
    PersonalizationStore.set(READING_LINE_KEY, 1.5);
    PersonalizationStore.set(READING_FONT_KEY, 'system');
    PersonalizationStore.set(READING_INSET_KEY, 8);
  }
}
