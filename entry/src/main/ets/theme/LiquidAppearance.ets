import { ColorMetrics } from '@kit.ArkUI';
import { LiquidVector } from './LiquidContour';

export class LiquidAppearance {
  private static channels(color: ResourceColor): number[] {
    try {
      const resolved: ColorMetrics = ColorMetrics.resourceColor(color);
      return [resolved.alpha > 1 ? resolved.alpha : resolved.alpha * 255,
        resolved.red, resolved.green, resolved.blue];
    } catch (error) {
      return [0, 0, 0, 0];
    }
  }

  static blend(source: BackgroundEffectOptions, target: BackgroundEffectOptions,
    progress: number, inactiveColor: ResourceColor): LiquidVector {
    const amount: number = Math.max(0, Math.min(1, progress));
    const start: number[] = [source.radius, source.saturation ?? 1, source.brightness ?? 1,
      ...LiquidAppearance.channels(source.color ?? Color.Transparent)];
    const end: number[] = [target.radius, target.saturation ?? 1, target.brightness ?? 1,
      ...LiquidAppearance.channels(target.color ?? Color.Transparent)];
    return new LiquidVector([...start.map((value: number, index: number): number =>
      value + (end[index] - value) * amount), ...LiquidAppearance.channels(inactiveColor)]);
  }

  static tint(frame: LiquidVector, start: number = 3): string {
    return '#' + frame.values.slice(start, start + 4)
      .map((value: number): string => Math.max(0, Math.min(255, Math.round(value))).toString(16).padStart(2, '0'))
      .join('');
  }

  static effect(frame: LiquidVector): BackgroundEffectOptions {
    return {
      radius: Math.max(0, frame.values[0]),
      saturation: Math.max(0, frame.values[1]),
      brightness: Math.max(0, frame.values[2]),
      color: LiquidAppearance.tint(frame),
      policy: BlurStyleActivePolicy.FOLLOWS_WINDOW_ACTIVE_STATE,
      inactiveColor: LiquidAppearance.tint(frame, 7)
    };
  }
}
