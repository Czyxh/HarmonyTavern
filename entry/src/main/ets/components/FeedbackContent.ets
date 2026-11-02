import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { COLORS, ColorTokens } from '../theme/Tokens';
import { ActionButtonStyle, ActionTone } from '../theme/ControlStyles';
import { SurfaceStyle } from '../theme/SurfaceStyles';
import { saveBytes } from '../utils/ExportFiles';

export const FEEDBACK_QQ_GROUP: string = '1125678554';

@Component
export struct FeedbackContent {
  @StorageProp('uiColors') colors: ColorTokens = COLORS;
  @State saving: boolean = false;
  @State copying: boolean = false;
  @State message: string = '';
  @State failed: boolean = false;

  private async copyGroup(): Promise<void> {
    if (this.copying) { return; }
    this.copying = true;
    try {
      await pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, FEEDBACK_QQ_GROUP));
      this.getUIContext().getPromptAction().showToast({ message: '群号已复制，可在 QQ 中搜索加入' });
    } catch (_) {
      this.getUIContext().getPromptAction().showToast({ message: '复制失败，请长按群号手动复制' });
    } finally { this.copying = false; }
  }

  private async downloadQr(): Promise<void> {
    if (this.saving) { return; }
    this.saving = true;
    this.message = '';
    this.failed = false;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const original: Uint8Array = await context.resourceManager.getRawFileContent('feedback/qq_group.jpg');
      const bytes: Uint8Array = new Uint8Array(original.length);
      bytes.set(original);
      const saved: boolean = await saveBytes(context, 'HarmonyTavern-反馈QQ群-' + FEEDBACK_QQ_GROUP + '.jpg', bytes.buffer as ArrayBuffer);
      this.message = saved ? '二维码原图已保存到你选择的位置。' : '已取消保存。';
    } catch (_) {
      this.failed = true;
      this.message = '保存失败，请重试。也可以复制群号，在 QQ 中搜索加入。';
    } finally { this.saving = false; }
  }

  build() {
    Column({ space: 20 }) {
      Column({ space: 10 }) {
        Text('一起让酒馆更好用').fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.colors.textPrimary).width('100%')
        Text('遇到问题、有新的想法，欢迎来 QQ 群和我们聊聊。')
          .fontSize(15).lineHeight(25).fontColor(this.colors.textSecondary).width('100%')
      }.width('100%')
      Column({ space: 16 }) {
        Text('HarmonyTavern 交流与反馈').fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.colors.textPrimary)
        Text(FEEDBACK_QQ_GROUP).fontSize(27).fontWeight(FontWeight.Bold).fontColor(this.colors.accent)
          .copyOption(CopyOptions.LocalDevice).id('feedback-qq-number').accessibilityText('反馈 QQ 群号 ' + FEEDBACK_QQ_GROUP)
        Button(this.copying ? '正在复制…' : '复制QQ群号').width('100%')
          .attributeModifier(new ActionButtonStyle(this.colors, ActionTone.Primary))
          .enabled(!this.copying).id('feedback-copy-group').onClick((): void => { this.copyGroup(); })
        Button({ type: ButtonType.Normal }) {
          Image($r('app.media.feedback_qq_qr')).width('100%').aspectRatio(1).objectFit(ImageFit.Contain)
            .interpolation(ImageInterpolation.None).draggable(false).accessibilityLevel('no')
        }.width('100%').constraintSize({ maxWidth: 280 }).aspectRatio(1).padding(0)
          .backgroundColor('#FFFFFF').borderRadius(16).clip(true).enabled(!this.saving)
          .id('feedback-download-qr-image').accessibilityText('反馈群二维码，点击下载原图')
          .onClick((): void => { this.downloadQr(); })
        Text('点击二维码下载原图，也可以在 QQ 中搜索群号加入。')
          .fontSize(13).lineHeight(22).fontColor(this.colors.textSecondary).textAlign(TextAlign.Center).width('100%')
        Button(this.saving ? '正在保存…' : '下载二维码原图').width('100%')
          .attributeModifier(new ActionButtonStyle(this.colors)).enabled(!this.saving)
          .id('feedback-download-qr').onClick((): void => { this.downloadQr(); })
        if (this.message !== '') {
          Text(this.message).fontSize(13).lineHeight(22).fontColor(this.failed ? this.colors.danger : this.colors.accent)
            .width('100%').id('feedback-save-result')
        }
      }.width('100%').padding(20).attributeModifier(new SurfaceStyle(this.colors, 24))
      Column({ space: 10 }) {
        Text('反馈时可以带上这些信息').fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.colors.textPrimary).width('100%')
        Text('应用版本、设备型号、操作步骤，以及问题截图，能帮助我们更快定位问题。')
          .fontSize(14).lineHeight(24).fontColor(this.colors.textSecondary).width('100%')
        Text('发送截图或日志前，请遮住 API 密钥和私人聊天内容。')
          .fontSize(13).lineHeight(22).fontColor(this.colors.textSecondary).width('100%')
      }.width('100%')
    }.width('100%').constraintSize({ maxWidth: 520 }).alignSelf(ItemAlign.Center)
  }
}
