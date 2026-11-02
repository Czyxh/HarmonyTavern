import { PersonalizationStore } from './PersonalizationStore';

export const ONBOARDING_VERSION_KEY: string = 'onboardingCompletedVersion';
export const ONBOARDING_VERSION: number = 1;

export class OnboardingState {
  static shouldShow(): boolean {
    return (AppStorage.get<number>(ONBOARDING_VERSION_KEY) ?? 0) < ONBOARDING_VERSION;
  }

  static complete(): void {
    PersonalizationStore.set(ONBOARDING_VERSION_KEY, ONBOARDING_VERSION);
  }
}
