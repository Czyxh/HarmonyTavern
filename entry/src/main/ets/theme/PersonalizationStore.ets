import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';

export const STORY_WELCOME_DISMISSED_KEY: string = 'storyWelcomeDismissed';
export const CHAT_TOKEN_USAGE_KEY: string = 'chatShowTokenUsage';
export const CHAT_REASONING_KEY: string = 'chatShowReasoning';

interface PersonalizationValue {
  key: string;
  value: string | number | boolean;
}

const DEFAULTS: PersonalizationValue[] = [
  { key: 'onboardingCompletedVersion', value: 0 },
  { key: 'builtinAssistantSeedVersion', value: 0 },
  { key: STORY_WELCOME_DISMISSED_KEY, value: false },
  { key: CHAT_TOKEN_USAGE_KEY, value: false },
  { key: CHAT_REASONING_KEY, value: false },
  { key: 'appearanceBackground', value: 'paper' },
  { key: 'appearanceDisplayMode', value: 'system' },
  { key: 'appearanceFontScale', value: 1 },
  { key: 'readingFontSize', value: 15 },
  { key: 'readingLineHeight', value: 1.5 },
  { key: 'readingFontFamily', value: 'system' },
  { key: 'readingInset', value: 8 },
  { key: 'appearanceColorTransition', value: true },
  { key: 'lightSenseBlur', value: 4 },
  { key: 'immersiveLevel', value: 3 },
  { key: 'reduceMotion', value: false },
  { key: 'holdingEnabled', value: true },
  { key: 'holdingActionEnabled', value: true },
  { key: 'holdingLightEnabled', value: true },
  { key: 'customLightBackground', value: '#F4E5EB' },
  { key: 'customLightAccent', value: '#A34268' },
  { key: 'customDarkBackground', value: '#281E25' },
  { key: 'customDarkAccent', value: '#EDA1BC' }
];

export class PersonalizationStore {
  private static store: preferences.Preferences | undefined = undefined;

  static initialize(context: common.UIAbilityContext): void {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'personalization' });
      PersonalizationStore.store = store;
      for (const item of DEFAULTS) {
        const fallback: string | number | boolean = AppStorage.get<string | number | boolean>(item.key) ?? item.value;
        const saved: preferences.ValueType = store.getSync(item.key, fallback);
        const value: string | number | boolean = typeof saved === typeof item.value
          ? saved as string | number | boolean : item.value;
        AppStorage.setOrCreate(item.key, value);
        store.putSync(item.key, value);
      }
      PersonalizationStore.flush();
    } catch (error) {
      hilog.warn(0x0000, 'Personalization', 'Unable to load preferences: %{public}s', (error as Error).message);
    }
  }

  static set(key: string, value: string | number | boolean): void {
    AppStorage.setOrCreate(key, value);
    try {
      PersonalizationStore.store?.putSync(key, value);
      PersonalizationStore.flush();
    } catch (error) {
      hilog.warn(0x0000, 'Personalization', 'Unable to save preferences: %{public}s', (error as Error).message);
    }
  }

  private static flush(): void {
    PersonalizationStore.store?.flush().catch((error: Error) => {
      hilog.warn(0x0000, 'Personalization', 'Unable to flush preferences: %{public}s', error.message);
    });
  }
}
