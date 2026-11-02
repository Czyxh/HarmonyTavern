import { uiMaterial } from '@kit.ArkUI';
import { ColorTokens } from './Tokens';
import { glassLightColor } from './Glass';
import type { NativeGlassFactory } from './SystemGlass';
import { hilog } from '@kit.PerformanceAnalysisKit';

/** This file must remain behind SystemGlass.initialize's API-version guard. */
export class NativeGlassProvider implements NativeGlassFactory {
  private navigationMaterial: uiMaterial.ImmersiveMaterial | undefined = undefined;
  private navigationLevel: number = -1;
  private readingMaterial: uiMaterial.ImmersiveMaterial | undefined = undefined;
  private readingColors: ColorTokens | undefined = undefined;
  private readingLevel: number = -1;
  private navigationColors: ColorTokens | undefined = undefined;
  private lensMaterial: uiMaterial.ImmersiveMaterial | undefined = undefined;
  private stillLensMaterial: uiMaterial.ImmersiveMaterial | undefined = undefined;
  empty(): uiMaterial.Material { return uiMaterial.Material.empty; }

  supported(): boolean {
    const supported: boolean = uiMaterial.isImmersiveMaterialSupported();
    hilog.info(0, 'SystemGlass', 'API26 supported=%{public}s level=%{public}d', String(supported), uiMaterial.getGlobalMaterialLevel());
    return supported;
  }
  navigation(level: number, colors: ColorTokens): uiMaterial.ImmersiveMaterial {
    if (this.navigationMaterial && this.navigationLevel === level && this.navigationColors === colors) {
      return this.navigationMaterial;
    }
    this.navigationLevel = level; this.navigationColors = colors;
    this.navigationMaterial = new uiMaterial.ImmersiveMaterial({
      style: level === 0 ? uiMaterial.ImmersiveStyle.REGULAR :
        (level === 1 ? uiMaterial.ImmersiveStyle.THIN : uiMaterial.ImmersiveStyle.ULTRA_THIN),
      materialColor: glassLightColor(colors.dockTint, 0.22), applyShadow: true, interactive: false
    });
    return this.navigationMaterial;
  }
  reading(level: number, colors: ColorTokens): uiMaterial.ImmersiveMaterial {
    if (this.readingMaterial && this.readingColors === colors && this.readingLevel === level) { return this.readingMaterial; }
    this.readingColors = colors; this.readingLevel = level;
    // Keep the orb's explicit tint; denser diffusion separates long-form foreground text.
    this.readingMaterial = new uiMaterial.ImmersiveMaterial({
      style: level === 0 ? uiMaterial.ImmersiveStyle.REGULAR : uiMaterial.ImmersiveStyle.THIN,
      materialColor: glassLightColor(colors.dockTint, 0.22), applyShadow: true, interactive: false
    });
    return this.readingMaterial;
  }
  dialog(colors: ColorTokens): uiMaterial.ImmersiveMaterial {
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      materialColor: glassLightColor(colors.glassTint, 0.2), interactive: false, applyShadow: true
    });
  }
  lens(reduceMotion: boolean): uiMaterial.ImmersiveMaterial {
    const existing: uiMaterial.ImmersiveMaterial | undefined = reduceMotion ? this.stillLensMaterial : this.lensMaterial;
    if (existing) { return existing; }
    const material: uiMaterial.ImmersiveMaterial = new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.ULTRA_THIN, interactive: false, applyShadow: false,
      lightEffect: reduceMotion ? null : { color: Color.White }
    });
    if (reduceMotion) { this.stillLensMaterial = material; } else { this.lensMaterial = material; }
    return material;
  }
}
