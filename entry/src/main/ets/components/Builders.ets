import { iconTint } from '../theme/IconTint';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
// 共享渲染基元（P8-1）。
//
// 只做"重复出现 ≥3 次"的视觉片段，避免提前抽象。全局 @Builder 可跨文件复用，
// 比带 @BuilderParam 槽位的组件更轻，也不会削弱系统组件的状态与无障碍语义。
//
// 对应 DevEco 工程路径：entry/src/main/ets/components/Builders.ets
import { Radius, Spacing, Typography } from '../theme/Tokens';

/** 分组标题（列表上方的小标题）。 */
@Builder
export function SectionTitle(text: string, colors: ColorTokens = INITIAL_COLORS) {
  SectionTitleContent({ text: text })
}

/** 卡片容器外观：给 Column 用。 */
@Builder
export function cardSurface() {
  // 仅供 .attributeModifier 风格参考；本文件用显式属性，见 Card 组件。
}

/** 错误条：错误必须"文字 + 颜色"双信号（不靠颜色单独传递状态）。 */
@Builder
export function ErrorBanner(text: string, colors: ColorTokens = INITIAL_COLORS) {
  if (text !== '') {
    Row({ space: Spacing.sm }) {
      Image($r('app.media.icon_warning'))
        .width(18).height(18)
        .colorFilter(iconTint(colors.danger))
      Text(text)
        .fontSize(Typography.caption)
        .fontColor(colors.danger)
        .layoutWeight(1)
    }
    .width('100%')
    .padding(Spacing.md)
    .backgroundColor(colors.dangerContainer)
    .borderRadius(Radius.sm)
    .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
  }
}

/** 空列表引导：说明 + 可选操作提示。 */
@Builder
export function EmptyHint(title: string, hint: string, colors: ColorTokens = INITIAL_COLORS) {
  EmptyHintContent({ title: title, hint: hint })
}

/** 一行键值（诊断信息用）。 */
@Builder
export function KeyValueLine(label: string, value: string, colors: ColorTokens = INITIAL_COLORS) {
  KeyValueLineContent({ label: label, value: value })
}

/** 分割线。 */
@Builder
export function SubtleDivider(colors: ColorTokens = INITIAL_COLORS) {
  SubtleDividerContent({  })
}

/**
 * 错误条（可刷新版）。
 *
 * **为什么不是 @Builder**：`@Builder` 的按值参数在父组件重建时**不会**刷新——
 * 实测症状是「后端报错、hilog 里有 `command ... failed`，但界面上什么都没有」，
 * 排查了整整两轮才发现不是后端问题。改成 `@Prop` 组件后，父组件的 @State 一变
 * 子组件就跟着重渲染。全工程 23 处调用都改成 `ErrorBannerView({ text: this.errorText })`。
 */
@Component
export struct ErrorBannerView {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @Prop text: string;

  build() {
    if (this.text !== '') {
      Row({ space: Spacing.sm }) {
        Image($r('app.media.icon_warning'))
          .width(18).height(18)
          .colorFilter(iconTint(this.uiColors.danger))
        Text(this.text)
          .fontSize(Typography.caption)
          .fontColor(this.uiColors.danger)
          .layoutWeight(1)
      }
      .width('100%')
      .padding(Spacing.md)
      .backgroundColor(this.uiColors.dangerContainer)
      .borderRadius(Radius.sm)
    }
  }
}

@Component
struct SectionTitleContent {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @Prop text: string = '';

  build() {
    Text(this.text)
      .fontSize(Typography.subtitle)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.uiColors.textPrimary)
      .width('100%')
      .padding({ left: Spacing.xs, top: Spacing.md, bottom: Spacing.sm })
  }
}

@Component
struct EmptyHintContent {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @Prop title: string = '';
  @Prop hint: string = '';

  build() {
    Column({ space: Spacing.md }) {
      Image($r('app.media.icon_spark'))
        .width(40)
        .height(40)
        .colorFilter(iconTint(this.uiColors.accent))
        .margin({ bottom: 8 })
        .accessibilityLevel('no')
      Text(this.title)
        .fontSize(Typography.subtitle)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.uiColors.textPrimary)
      Text(this.hint)
        .fontSize(Typography.caption)
        .fontColor(this.uiColors.textTertiary)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ top: Spacing.xxl, bottom: Spacing.xxl })
    .alignItems(HorizontalAlign.Center)
  }
}

@Component
struct KeyValueLineContent {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @Prop label: string = '';
  @Prop value: string = '';

  build() {
    Row({ space: Spacing.sm }) {
      Text(this.label)
        .fontSize(Typography.micro)
        .fontColor(this.uiColors.textTertiary)
        .width(96)
      Text(this.value)
        .fontSize(Typography.micro)
        .fontColor(this.uiColors.textSecondary)
        .layoutWeight(1)
    }
    .width('100%')
  }
}

@Component
struct SubtleDividerContent {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;


  build() {
    Divider()
      .color(this.uiColors.borderSubtle)
      .strokeWidth(1)
      .margin({ left: Spacing.lg })
  }
}
