import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { resourceManager } from '@kit.LocalizationKit';
import { Appearance, APP_DARK_KEY, BACKGROUND_DEFAULT, BACKGROUND_KEY, COLOR_TRANSITION_KEY } from './Appearance';
import { ColorTokens } from './Tokens';
import { CustomPalette } from './CustomPalette';
import { PersonalizationStore } from './PersonalizationStore';

export const DISPLAY_MODE_KEY: string = 'appearanceDisplayMode';
export const FONT_SCALE_KEY: string = 'appearanceFontScale';

export class DisplayPreferences {
  private static context: common.ApplicationContext | undefined = undefined;
  private static mainWindow: window.Window | undefined = undefined;

  static initialize(context: common.ApplicationContext, systemDark: boolean): void {
    DisplayPreferences.context = context;
    PersistentStorage.persistProp(BACKGROUND_KEY, BACKGROUND_DEFAULT);
    PersistentStorage.persistProp(DISPLAY_MODE_KEY, 'system');
    PersistentStorage.persistProp(FONT_SCALE_KEY, 1);
    PersistentStorage.persistProp(COLOR_TRANSITION_KEY, true);
    CustomPalette.initialize();
    AppStorage.setOrCreate(APP_DARK_KEY, systemDark);
    DisplayPreferences.setMode(AppStorage.get<string>(DISPLAY_MODE_KEY) ?? 'system');
    DisplayPreferences.setFontScale(AppStorage.get<number>(FONT_SCALE_KEY) ?? 1);
    Appearance.onApplied = (colors: ColorTokens): void => { DisplayPreferences.updateBars(colors); };
  }

  static attachWindow(mainWindow: window.Window): void {
    DisplayPreferences.mainWindow = mainWindow;
    DisplayPreferences.updateBars(Appearance.colors(AppStorage.get<string>(BACKGROUND_KEY) ?? BACKGROUND_DEFAULT));
  }

  static modeLabel(mode: string): string {
    return mode === 'light' ? '浅色' : mode === 'dark' ? '深色' : '跟随系统';
  }

  static setMode(mode: string): boolean {
    if (!DisplayPreferences.context) { return false; }
    const selected: string = mode === 'light' || mode === 'dark' ? mode : 'system';
    const dark: boolean = selected === 'dark' || (selected === 'system' && DisplayPreferences.systemIsDark());
    try {
      DisplayPreferences.context.setColorMode(selected === 'light' ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
        : selected === 'dark' ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK : ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      PersonalizationStore.set(DISPLAY_MODE_KEY, selected);
      DisplayPreferences.configurationChanged(dark);
      return true;
    } catch (error) {
      return false;
    }
  }

  private static systemIsDark(): boolean {
    try {
      return resourceManager.getSysResourceManager().getConfigurationSync().colorMode === resourceManager.ColorMode.DARK;
    } catch (error) {
      return AppStorage.get<boolean>(APP_DARK_KEY) ?? false;
    }
  }

  static configurationChanged(dark: boolean): void {
    const mode: string = AppStorage.get<string>(DISPLAY_MODE_KEY) ?? 'system';
    AppStorage.setOrCreate(APP_DARK_KEY, mode === 'system' ? dark : mode === 'dark');
    Appearance.selectBackground(AppStorage.get<string>(BACKGROUND_KEY) ?? BACKGROUND_DEFAULT);
  }

  static setFontScale(scale: number): boolean {
    if (!DisplayPreferences.context) { return false; }
    const selected: number = Number.isFinite(scale) ? Math.max(0.85, Math.min(1.3, scale)) : 1;
    try {
      DisplayPreferences.context.setFontSizeScale(selected);
      PersonalizationStore.set(FONT_SCALE_KEY, selected);
      return true;
    } catch (error) {
      return false;
    }
  }

  private static updateBars(colors: ColorTokens): void {
    const mainWindow: window.Window | undefined = DisplayPreferences.mainWindow;
    if (!mainWindow) { return; }
    try {
      const lightIcons: boolean = typeof colors.bgBase === 'string'
        ? CustomPalette.luminance(CustomPalette.normalize(colors.bgBase) || '#EAE0CC') < 0.179
        : (AppStorage.get<boolean>(APP_DARK_KEY) ?? false);
      const content: string = lightIcons ? '#FFFFFF' : '#000000';
      mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000', navigationBarColor: '#00000000',
        statusBarContentColor: content, navigationBarContentColor: content,
        isStatusBarLightIcon: lightIcons, isNavigationBarLightIcon: lightIcons
      }).catch(() => {});
    } catch (error) {
      return;
    }
  }
}
