import { motion } from '@kit.MultimodalAwarenessKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PersonalizationStore } from './PersonalizationStore';

export const HOLDING_HAND_KEY: string = 'uiHoldingHand';
export const HOLDING_HAND_UNKNOWN: number = motion.HoldingHandStatus.UNKNOWN_STATUS;
export const HOLDING_ENABLED_KEY: string = 'holdingEnabled';
export const HOLDING_ACTION_KEY: string = 'holdingActionEnabled';
export const HOLDING_LIGHT_KEY: string = 'holdingLightEnabled';
export const HOLDING_AVAILABLE_KEY: string = 'holdingAvailable';

export class HoldingPose {
  private static subscribed: boolean = false;
  private static active: boolean = false;
  private static foreground: boolean = false;
  private static readonly listener: (status: motion.HoldingHandStatus) => void = (status: motion.HoldingHandStatus): void => {
    if (HoldingPose.active) { AppStorage.setOrCreate(HOLDING_HAND_KEY, status); }
  };

  static initialize(): void {
    PersistentStorage.persistProp(HOLDING_ENABLED_KEY, true);
    PersistentStorage.persistProp(HOLDING_ACTION_KEY, true);
    PersistentStorage.persistProp(HOLDING_LIGHT_KEY, true);
  }

  static enabled(key: string = HOLDING_ENABLED_KEY): boolean {
    return AppStorage.get<boolean>(key) ?? true;
  }

  static setEnabled(key: string, enabled: boolean): void {
    PersonalizationStore.set(key, enabled);
    HoldingPose.syncSubscription();
  }

  static start(): void {
    HoldingPose.foreground = true;
    HoldingPose.syncSubscription();
  }

  private static syncSubscription(): void {
    if (!HoldingPose.foreground || !HoldingPose.enabled() ||
      (!HoldingPose.enabled(HOLDING_ACTION_KEY) && !HoldingPose.enabled(HOLDING_LIGHT_KEY))) {
      HoldingPose.unsubscribe();
      return;
    }
    HoldingPose.active = true;
    if (HoldingPose.subscribed) { return; }
    AppStorage.setOrCreate(HOLDING_HAND_KEY, HOLDING_HAND_UNKNOWN);
    AppStorage.setOrCreate(HOLDING_AVAILABLE_KEY, false);
    if (!canIUse('SystemCapability.MultimodalAwareness.Motion')) { return; }
    try {
      motion.on('holdingHandChanged', HoldingPose.listener);
      HoldingPose.subscribed = true;
      AppStorage.setOrCreate(HOLDING_AVAILABLE_KEY, true);
    } catch (error) {
      hilog.warn(0x0000, 'HoldingPose', 'Holding-hand detection unavailable: %{public}s', (error as Error).message);
    }
  }

  static stop(): void {
    HoldingPose.foreground = false;
    HoldingPose.unsubscribe();
  }

  private static unsubscribe(): void {
    HoldingPose.active = false;
    AppStorage.setOrCreate(HOLDING_HAND_KEY, HOLDING_HAND_UNKNOWN);
    if (!HoldingPose.subscribed) { return; }
    try {
      motion.off('holdingHandChanged', HoldingPose.listener);
      HoldingPose.subscribed = false;
    } catch (error) {
      hilog.warn(0x0000, 'HoldingPose', 'Unable to release holding-hand detection: %{public}s', (error as Error).message);
    }
  }

  static lightPosition(status: number): number {
    if (status === motion.HoldingHandStatus.LEFT_HAND_HELD) { return 0.24; }
    if (status === motion.HoldingHandStatus.RIGHT_HAND_HELD) { return 0.76; }
    return 0.5;
  }

  /** Plus button keeps away from the holding hand. Both hands: plus stays on the left. */
  static actionOnRight(status: number, previous: boolean): boolean {
    if (status === motion.HoldingHandStatus.RIGHT_HAND_HELD) { return false; }
    if (status === motion.HoldingHandStatus.LEFT_HAND_HELD) { return true; }
    if (status === motion.HoldingHandStatus.BOTH_HANDS_HELD) { return false; }
    return previous;
  }

  /** Adventure cup sits on the holding hand's side. Both hands: cup stays on the right. */
  static cupOnRight(status: number, previous: boolean): boolean {
    if (status === motion.HoldingHandStatus.RIGHT_HAND_HELD) { return true; }
    if (status === motion.HoldingHandStatus.LEFT_HAND_HELD) { return false; }
    if (status === motion.HoldingHandStatus.BOTH_HANDS_HELD) { return true; }
    return previous;
  }
}
