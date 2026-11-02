import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { Appearance, BACKGROUND_DEFAULT } from '../theme/Appearance';
import { LS_BLUR_DEFAULT, LS_BLUR_KEY } from '../theme/LightSense';
import { IMMERSIVE_DEFAULT, IMMERSIVE_KEY } from '../theme/Immersive';
import { HoldingPose } from '../theme/HoldingPose';
import { DisplayPreferences } from '../theme/DisplayPreferences';
import { PersonalizationStore } from '../theme/PersonalizationStore';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    HoldingPose.stop();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 持久化外观偏好：模糊强度重启后还在（AppStorage 本身不落盘）
    PersistentStorage.persistProp(LS_BLUR_KEY, LS_BLUR_DEFAULT);
    PersistentStorage.persistProp(IMMERSIVE_KEY, IMMERSIVE_DEFAULT);
    PersistentStorage.persistProp('appearanceLightFieldDefaultApplied', false);
    if (!AppStorage.get<boolean>('appearanceLightFieldDefaultApplied')) {
      AppStorage.setOrCreate(LS_BLUR_KEY, LS_BLUR_DEFAULT);
      AppStorage.setOrCreate(IMMERSIVE_KEY, IMMERSIVE_DEFAULT);
      AppStorage.setOrCreate('appearanceLightFieldDefaultApplied', true);
    }
    PersistentStorage.persistProp('reduceMotion', false);
    PersistentStorage.persistProp('appearanceBackground', 'paper');
    PersistentStorage.persistProp('appearancePaperDefaultApplied', false);
    if (!AppStorage.get<boolean>('appearancePaperDefaultApplied')) {
      AppStorage.setOrCreate('appearanceBackground', 'paper');
      AppStorage.setOrCreate('appearancePaperDefaultApplied', true);
    }
    PersistentStorage.persistProp('providerPreferences', '[]');
    PersistentStorage.persistProp('auxiliaryModels', '[]');
    PersistentStorage.persistProp('auxiliaryModelId', 'builtin');
    PersistentStorage.persistProp('activeProviderId', 'deepseek');
    HoldingPose.initialize();
    PersonalizationStore.initialize(this.context);
    DisplayPreferences.initialize(this.context.getApplicationContext(),
      this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    Appearance.selectBackground(AppStorage.get<string>('appearanceBackground') ?? BACKGROUND_DEFAULT);
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.getMainWindow().then((mainWindow: window.Window) => {
      mainWindow.setWindowLayoutFullScreen(true).catch((err: Error) => {
        hilog.warn(DOMAIN, 'testTag', 'setWindowLayoutFullScreen failed: %{public}s', err.message);
      });
      DisplayPreferences.attachWindow(mainWindow);
    }).catch((err: Error) => {
      hilog.warn(DOMAIN, 'testTag', 'getMainWindow failed: %{public}s', err.message);
    });

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onConfigurationUpdate(configuration: Configuration): void {
    if (configuration.colorMode !== undefined && configuration.colorMode !== ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET) {
      DisplayPreferences.configurationChanged(configuration.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    }
  }

  onWindowStageDestroy(): void {
    HoldingPose.stop();
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    HoldingPose.start();
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    HoldingPose.stop();
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
