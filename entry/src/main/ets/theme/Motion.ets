// Motion Token 与动效策略（P9-1）。
//
// 对应 DevEco 工程路径：entry/src/main/ets/theme/Motion.ets
//
// ============================ 来源与分层 ============================
// 按 harmonyos-design 的分层，本文件里的东西分三类，**不能混着标**：
//
// | 层 | 内容 | 来源 |
// | --- | --- | --- |
// | Evergreen（不随版本变） | 按压必须在 Down 立即反馈；离手动画从当前显示状态继续；
// |                          | 可被打断；动画必须表达关系；低运动替代 |
// | Versioned Platform（跟 API 版本走） | `curves.springMotion` / `TransitionEffect` /
// |                          | `geometryTransition` / `Navigation` 转场的可用性 |
// | Project Overlay（House Style） | 弹簧具体数值（0.28/0.62 等）、错开步长 28ms、
// |                          | 入场位移 18vp —— **这些不是华为官方数值** |
//
// 官方公开参考时长（H2，OpenHarmony UX）：简单颜色 100 / 很短动作 150 /
// 局部列表 200 / 短距离 250 / 复杂旋转 300 / 全屏 350ms。下面的 duration 沿用它们。
//
// ============================ 纠错：网上流传的错误 API ============================
// 参考视频的 AI 拆解里有一半 API 是编的，照抄会编译失败或行为错误：
//
// | 流传写法 | 真实情况 |
// | --- | --- |
// | `curves.springMotion(0.6, 1.2)` 标成 stiffness/damping | 签名是
// |   | `springMotion(response?, dampingFraction?, overlapDuration?)`：第一个参数是
// |   | **响应时间（秒）**，第三个才是重叠时长；**没有 stiffness**。1.2 当阻尼比越界 |
// | `.backdropBlur(15)` | ArkUI 没有此属性；等价 `backgroundBlurStyle()` 或 `backgroundEffect()` |
// | 容器 `.stroke()` / `.strokeWidth()` | 只有 `Rect`/`Circle`/`Path`/`Shape` 有；容器用 `.border()` |
// | `customNavContentTransition((isPop, ctx) => …)` | 签名不同：`(from, to, operation) => NavContentTransitionType`，
// |   | 且要自己接管全部帧；**本文件不用它**（见下） |
// | `bindSheet(isShow, builder, { modalTransition, position: Bottom })` | 形态不对：真实是
// |   | `.bindSheet(isShow, builder, options?: SheetOptions)`，`Bottom` 这种枚举不存在 |
//
// 对应 DevEco 工程路径：entry/src/main/ets/theme/Motion.ets
import { curves } from '@kit.ArkUI';
import { PersonalizationStore } from './PersonalizationStore';

/** 时长 Token（ms）。数值取自 H2 公开参考；`H2-reference` 标注来源。 */
export class Duration {
  /** 简单颜色变化（H2 参考） */
  static readonly instant: number = 100;
  /** 很短动作（H2 参考） */
  static readonly short: number = 150;
  /** 局部列表变化（H2 参考） */
  static readonly local: number = 200;
  /** 短距离运动（H2 参考） */
  static readonly move: number = 250;
  /** 长距离 / 全屏（H2 参考） */
  static readonly full: number = 350;
}

/**
 * 弹簧语义 Token。
 *
 * 参数语义（不要按"刚度/阻尼"理解）：
 *   response        一次震荡完成的时间，秒。越大越慢。
 *   dampingFraction 阻尼比。1 = 不震荡，<1 = 会过冲。
 *
 * House Style 取值理由：
 *   press  0.28/0.62 —— 按压要"快而干脆"，过冲一次就够，不能像橡皮糖
 *   panel  0.36/0.78 —— 面板体积大，慢了显贵，震荡多会晕
 *   enter  0.42/0.86 —— 入场要有"落定"，几乎不过冲
 *   pop    0.34/0.72 —— 选中胶囊轻弹一下
 */
export class Spring {
  static press(): ICurve {
    return curves.springMotion(0.28, 0.62);
  }

  static panel(): ICurve {
    return curves.springMotion(0.36, 0.78);
  }

  static enter(): ICurve {
    return curves.springMotion(0.42, 0.86);
  }

  static pop(): ICurve {
    return curves.springMotion(0.34, 0.72);
  }
}

/** 缩放 Token（H4 House Style，非官方数值）。 */
export class Scale {
  /** 卡片/按钮按下 */
  static readonly pressDown: number = 0.96;
  /** 大块区域按下：少压一点，避免"整块塌陷" */
  static readonly pressDownLarge: number = 0.985;
  /** 入场初始缩放 */
  static readonly enterFrom: number = 0.94;
  /** 列表项入场初始缩放（更克制） */
  static readonly enterFromList: number = 0.96;
  /** 正常 */
  static readonly identity: number = 1.0;
}

/** 距离 Token（vp）。 */
export class Distance {
  /** 网格/卡片入场位移 */
  static readonly enterOffset: number = 18;
  /** 面板上滑距离 */
  static readonly sheetOffset: number = 320;
}

/** 错开（stagger）Token。 */
export class Stagger {
  /** 相邻项延迟（ms）：6~8 项时最舒服，项多了会显得慢 */
  static readonly stepMs: number = 28;
  /** 最多错开多少项：超过就不再加延迟，否则长列表最后一项要等好几秒 */
  static readonly maxItems: number = 8;

  static delayFor(index: number): number {
    const clamped: number = index < Stagger.maxItems ? index : Stagger.maxItems;
    return clamped * Stagger.stepMs;
  }
}

/**
 * 动效策略：低运动替代与降级开关。
 *
 * 官方《动画衔接》只讲"怎么接得顺"，不讲"有人不想要动画"。
 * 这里提供显式开关（设置页已接 AppStorage `reduceMotion`），
 * 开启后：入场退化为纯淡入 + 更短时长，错峰取消；弹簧按压也退化为直接状态切换。
 */
export const MOTION_REDUCE_KEY: string = 'reduceMotion';

export class MotionPolicy {
  static isReduceMotion(): boolean {
    const raw: ESObject = AppStorage.get(MOTION_REDUCE_KEY);
    return raw === true;
  }

  static setReduceMotion(enabled: boolean): void {
    PersonalizationStore.set(MOTION_REDUCE_KEY, enabled);
  }

  /** 兼容旧调用：错峰开 = 未开启"减少动态效果"。 */
  static isStaggerEnabled(): boolean {
    return !MotionPolicy.isReduceMotion();
  }
}

/**
 * 入场：淡入 + 上移 + 微放大。
 *
 * 曲线选择依据（官方《出现/消失转场》与《动画衔接》）：
 *   - 元素**进入视线**属于减速过程，官方错峰示例用 `Curve.Friction` + `delay`；
 *   - `springMotion` 的时长由曲线自身决定、且会继承正在运行的动画速度，
 *     适合"跟手 → 离手"和可打断的状态切换，不适合一次性入场（会显得弹）。
 * 所以入场用时长 + 减速曲线，弹簧只留给按压/选中这类可打断的微动效。
 */
export function entranceEffect(translateY: number): TransitionEffect {
  if (MotionPolicy.isReduceMotion()) {
    return TransitionEffect.OPACITY.animation({ duration: Duration.short, curve: Curve.Friction });
  }
  return TransitionEffect.OPACITY
    .combine(TransitionEffect.translate({ y: translateY }))
    .combine(TransitionEffect.scale({ x: Scale.enterFrom, y: Scale.enterFrom }))
    .animation({ duration: Duration.local, curve: Curve.Friction });
}

/** 列表项错开入场。`index` 用于算延迟；降低动态效果时退化为纯淡入。 */
export function staggeredEntrance(translateY: number, index: number): TransitionEffect {
  if (MotionPolicy.isReduceMotion()) {
    return TransitionEffect.OPACITY.animation({ duration: Duration.short, curve: Curve.Friction });
  }
  const appear: TransitionEffect = TransitionEffect.OPACITY
    .combine(TransitionEffect.translate({ y: translateY }))
    .combine(TransitionEffect.scale({ x: Scale.enterFromList, y: Scale.enterFromList }))
    .animation({
      duration: Duration.local,
      curve: Curve.Friction,
      delay: Stagger.delayFor(index)
    });
  const disappear: TransitionEffect = TransitionEffect.OPACITY
    .combine(TransitionEffect.translate({ y: translateY }))
    .combine(TransitionEffect.scale({ x: Scale.enterFromList, y: Scale.enterFromList }))
    .animation({ duration: Duration.short, curve: Curve.EaseIn });
  return TransitionEffect.asymmetric(appear, disappear);
}

/**
 * 父级转场守卫。
 *
 * 官方文档明确写了：**「消失时，如果不对方格的所有父控件添加转场效果，
 * 则方格的消失转场不会生效」**，官方示例给父控件挂 `TransitionEffect.opacity(0.99)`
 * 让父级有转场但不产生可见变化。我们给列表/网格容器挂这个，
 * 否则子项的退出动画永远是"瞬间消失"。
 */
export function parentTransitionGuard(): TransitionEffect {
  return TransitionEffect.opacity(0.999);
}

/** 面板（底部弹出）入场：从下往上 + 淡入。 */
export function sheetEffect(): TransitionEffect {
  if (MotionPolicy.isReduceMotion()) {
    return TransitionEffect.OPACITY.animation({ duration: Duration.short, curve: Curve.Friction });
  }
  return TransitionEffect.OPACITY
    .combine(TransitionEffect.translate({ y: Distance.sheetOffset }))
    .animation({ curve: Spring.panel() });
}
