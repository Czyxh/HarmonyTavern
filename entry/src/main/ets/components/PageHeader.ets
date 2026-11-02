import { HeaderAction } from './HeaderAction';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { GLASS_HEADER_BUTTON, glassEffect } from '../theme/Glass';
import { LS_BLUR_DEFAULT, LS_BLUR_KEY } from '../theme/LightSense';
import { IMMERSIVE_DEFAULT, IMMERSIVE_KEY } from '../theme/Immersive';

@Builder
function noActions() {}

// Immediate touch-down feedback; opacity also works with reduced motion.
@Styles
function touchFeedbackNormal() {
  .opacity(1)
}

@Styles
function touchFeedbackPressed() {
  .opacity(0.68)
}

@Component
export struct PageHeader {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop showBack: boolean = true;
  @StorageProp(LS_BLUR_KEY) blurRadius: number = LS_BLUR_DEFAULT;
  @StorageProp(IMMERSIVE_KEY) immersiveLevel: number = IMMERSIVE_DEFAULT;
  @BuilderParam actions: () => void = noActions;
  onBack: () => void = (): void => {};

  build() {
    Row({ space: 12 }) {
      if (this.showBack) {
      HeaderAction({ icon: $r('app.media.icon_back'), label: '返回',
        onAction: async (): Promise<void> => { this.onBack(); } })
      }
      Column({ space: 3 }) {
        Text(this.title)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.uiColors.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.subtitle !== '') {
          Text(this.subtitle)
            .fontSize(12)
            .fontColor(this.uiColors.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      this.actions()
    }
    .width('100%')
    .height(72)
    .padding({ left: 16, right: 16 })
  }
}
