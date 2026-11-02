import { ColorMetrics } from '@kit.ArkUI';
import { drawing } from '@kit.ArkGraphics2D';

export function iconTint(color: ResourceColor): drawing.ColorFilter {
  let resolved: ColorMetrics = ColorMetrics.rgba(64, 64, 64);
  try {
    resolved = ColorMetrics.resourceColor(color);
  } catch (error) {
    resolved = ColorMetrics.rgba(64, 64, 64);
  }
  return drawing.ColorFilter.createBlendModeColorFilter({
    alpha: Math.round(Math.max(0, Math.min(1, resolved.alpha)) * 255),
    red: resolved.red, green: resolved.green, blue: resolved.blue
  }, drawing.BlendMode.SRC_IN);
}
