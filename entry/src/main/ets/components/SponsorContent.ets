import { common } from '@kit.AbilityKit';
import { COLORS, ColorTokens } from '../theme/Tokens';
import { ActionButtonStyle, ActionTone } from '../theme/ControlStyles';
import { SegmentedPicker } from './SegmentedPicker';
import { saveBytes } from '../utils/ExportFiles';

@Component
export struct SponsorContent {
  @StorageProp('uiColors') colors: ColorTokens = COLORS;
  @State selectedIndex: number = 0;
  @State saving: boolean = false;
  @State saveMessage: string = '';
  @State saveFailed: boolean = false;

  private providerName(): string {
    return this.selectedIndex === 0 ? '支付宝' : '微信支付';
  }

  private qrResource(): Resource {
    return this.selectedIndex === 0 ? $r('app.media.sponsor_alipay_qr') : $r('app.media.sponsor_wechat_qr');
  }

  private async saveCard(): Promise<void> {
    if (this.saving) { return; }
    const provider: string = this.selectedIndex === 0 ? 'alipay' : 'wechat';
    const providerName: string = this.providerName();
    this.saving = true;
    this.saveMessage = '';
    this.saveFailed = false;
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const content: Uint8Array = await context.resourceManager.getRawFileContent('sponsor/' + provider + '_card.png');
      const bytes: Uint8Array = new Uint8Array(content.length);
      bytes.set(content);
      const saved: boolean = await saveBytes(context, 'HarmonyTavern-' + providerName + '-感谢支持.png', bytes.buffer as ArrayBuffer);
      this.saveMessage = saved ? '收款卡片已保存，谢谢你愿意支持这间小酒馆。' : '已取消保存，你的心意同样珍贵。';
    } catch (_) {
      this.saveFailed = true;
      this.saveMessage = '暂时无法保存，请重试。也可以截图保留收款码。';
    } finally {
      this.saving = false;
    }
  }

  build() {
    Column({ space: 20 }) {
      Column({ space: 12 }) {
        Row({ space: 12 }) {
          Image($r('app.media.sponsor_cup')).width(72).height(72).objectFit(ImageFit.Contain)
            .draggable(false).accessibilityLevel('no')
          Column({ space: 8 }) {
            Text('请开发者喝一杯').fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.colors.textPrimary).width('100%')
            Text('谢谢你，让故事继续发生。').fontSize(14).fontColor(this.colors.accent).width('100%')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%')
        Text('如果这间小酒馆为你带来过一点快乐，\n欢迎用一杯饮料的心意，支持它慢慢变好。')
          .fontSize(14).fontColor(this.colors.textSecondary).lineHeight(23).textAlign(TextAlign.Center).width('100%')
      }.width('100%').padding({ top: 4, left: 8, right: 8 })

      Column({ space: 14 }) {
        SegmentedPicker({ items: [{ glyph: '', label: '支付宝' }, { glyph: '', label: '微信支付' }],
          selectedIndex: this.selectedIndex, available: !this.saving, onSelect: (index: number): void => {
            this.selectedIndex = index;
            this.saveMessage = '';
            this.saveFailed = false;
          } }).id('sponsor-payment-method')
        Column({ space: 4 }) {
          Text(this.providerName() + '收款码').fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.colors.textPrimary)
          Text('金额随心，感谢每一份支持').fontSize(13).fontColor(this.colors.textSecondary)
        }.width('100%').accessibilityGroup(true)
        Image(this.qrResource()).width('100%').constraintSize({ maxWidth: 240 }).aspectRatio(1)
          .objectFit(ImageFit.Contain).interpolation(ImageInterpolation.None).backgroundColor('#FFFFFF')
          .draggable(false).id('sponsor-payment-qr').accessibilityText(this.providerName() + '赞助收款二维码')
        Text('用' + this.providerName() + '扫一扫，或保存卡片后识别二维码。')
          .fontSize(12).fontColor(this.colors.textSecondary).lineHeight(20).textAlign(TextAlign.Center).width('100%')
        Button(this.saving ? '正在保存…' : '保存' + this.providerName() + '收款卡片')
          .attributeModifier(new ActionButtonStyle(this.colors, ActionTone.Primary)).width('100%')
          .enabled(!this.saving).id('sponsor-save-card').onClick((): void => { this.saveCard(); })
        if (this.saveMessage !== '') {
          Text(this.saveMessage).fontSize(13).lineHeight(21).width('100%').textAlign(TextAlign.Center)
            .fontColor(this.saveFailed ? this.colors.danger : this.colors.accent).id('sponsor-save-message')
        }
      }.width('100%').padding(20).backgroundColor(this.colors.bgSurface).borderRadius(28)
        .border({ width: 0.8, color: this.colors.borderSubtle })

      Column({ space: 12 }) {
        Text('每一份心意，都很珍贵').fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.colors.textPrimary)
          .width('100%')
        Text('感谢你喜欢 HarmonyTavern，也谢谢你愿意支持独立开发。你的鼓励，会成为继续打磨体验、修复问题和完善功能的动力。')
          .fontSize(14).fontColor(this.colors.textSecondary).lineHeight(24).width('100%')
        Text('赞助完全自愿，量力而行。无论是否赞助，都谢谢你来到这里，愿你在酒馆里遇见喜欢的角色，写下属于自己的故事。')
          .fontSize(13).fontColor(this.colors.textSecondary).lineHeight(23).width('100%')
      }.width('100%').padding({ left: 8, right: 8 })
      Text('HarmonyTavern · 让故事自由生长').fontSize(12).fontColor(this.colors.textTertiary)
        .textAlign(TextAlign.Center).width('100%')
    }.width('100%').constraintSize({ maxWidth: 480 }).alignSelf(ItemAlign.Center)
  }
}
