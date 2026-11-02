import type { uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { ColorTokens } from './Tokens';
export interface NativeGlassFactory {
  supported(): boolean;
  navigation(level: number, colors: ColorTokens): uiMaterial.ImmersiveMaterial;
  reading(level: number, colors: ColorTokens): uiMaterial.ImmersiveMaterial;
  dialog(colors: ColorTokens): uiMaterial.ImmersiveMaterial;
  lens(reduceMotion: boolean): uiMaterial.ImmersiveMaterial;
  empty(): uiMaterial.Material;
}

/** Load API 26 code only after the version guard, including the new native module itself. */
export class SystemGlass {
  private static factory: NativeGlassFactory | undefined = undefined;
  private static loading: Promise<boolean> | undefined = undefined;
  private static readonly refractionEnabled: boolean = true;
  static initialize(): Promise<boolean> {
    if (!SystemGlass.refractionEnabled) {
      SystemGlass.factory = undefined;
      AppStorage.setOrCreate('systemMaterialAvailable', false);
      return Promise.resolve(false);
    }
    if (deviceInfo.sdkApiVersion < 26) { return Promise.resolve(false); }
    if (!SystemGlass.loading) { SystemGlass.loading = SystemGlass.load(); }
    return SystemGlass.loading;
  }
  private static async load(): Promise<boolean> {
    try {
      const native = await import('./SystemGlassNative');
      const factory: NativeGlassFactory = new native.NativeGlassProvider();
      if (!factory.supported()) { return false; }
      SystemGlass.factory = factory;
      AppStorage.setOrCreate('systemMaterialAvailable', true);
      return true;
    } catch (_) { return false; }
  }
  static supported(): boolean { return SystemGlass.factory !== undefined; }
  static navigation(level: number, colors: ColorTokens): uiMaterial.ImmersiveMaterial | undefined {
    return SystemGlass.factory?.navigation(level, colors);
  }
  static reading(level: number, colors: ColorTokens): uiMaterial.ImmersiveMaterial | undefined {
    return SystemGlass.factory?.reading(level, colors);
  }
  static dialog(colors: ColorTokens): uiMaterial.ImmersiveMaterial | undefined {
    return SystemGlass.factory?.dialog(colors);
  }
  static empty(): uiMaterial.Material | undefined { return SystemGlass.factory?.empty(); }

  static lens(reduceMotion: boolean): uiMaterial.ImmersiveMaterial | undefined {
    return SystemGlass.factory?.lens(reduceMotion);
  }
}

/** Only used inside a native bottom TabBar, where public system materials can take effect. */
export class SystemLensStyle implements AttributeModifier<CommonAttribute> {
  private enabled: boolean;
  private reduceMotion: boolean;
  constructor(enabled: boolean, reduceMotion: boolean) {
    this.enabled = enabled; this.reduceMotion = reduceMotion;
  }
  applyNormalAttribute(node: CommonAttribute): void {
    if (this.enabled && SystemGlass.supported()) {
      node.systemMaterial(SystemGlass.lens(this.reduceMotion));
    }
  }
}

