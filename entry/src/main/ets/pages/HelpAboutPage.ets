import { COLORS, ColorTokens } from '../theme/Tokens';
import { SurfaceStyle } from '../theme/SurfaceStyles';
import { ActionButtonStyle } from '../theme/ControlStyles';
import { PageSurface } from '../components/PageSurface';
import { PageHeader } from '../components/PageHeader';
import { ROOT_PATH_STACK } from '../nav/RootNav';
import { SettingsChoice, SettingsPicker } from '../components/SettingsPicker';
import { bundleManager } from '@kit.AbilityKit';
import { SponsorContent } from '../components/SponsorContent';
import { FeedbackContent } from '../components/FeedbackContent';
import { OnboardingGuide } from '../components/OnboardingGuide';

@Component
export struct HelpAboutPage {
  @StorageProp('uiColors') colors: ColorTokens = COLORS;
  @Prop section: string = 'help';
  @State version: string = '';
  @State topic: string = 'start';
  @State guidePresented: boolean = false;
  private topics: SettingsChoice[] = [
    { id: 'start', label: '开始第一段对话' },
    { id: 'models', label: '连接服务商与选择模型' },
    { id: 'auxiliary', label: '辅助模型怎么用' },
    { id: 'world', label: '创造模式与状态栏' },
    { id: 'backup', label: '备份与恢复' }
  ];
  aboutToAppear(): void {
    try { this.version = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT).versionName; }
    catch (_) { this.version = ''; }
  }
  private title(): string {
    if (this.section === 'feedback') { return '反馈与建议'; }
    if (this.section === 'about') { return '关于 HarmonyTavern'; }
    if (this.section === 'sponsor') { return '赞助开发者'; }
    return '使用帮助';
  }
  private helpText(): string {
    if (this.topic === 'models') { return '在设置 → 模型与连接 → 服务商管理中选择服务，填写密钥与连接信息，保存并选择模型。自定义服务可填写服务方提供的基础地址与接口协议。'; }
    if (this.topic === 'auxiliary') { return '在辅助模型设置中展开选择内置 Qwen 或服务商管理里已配置的模型。辅助模型用于连接配置整理、普通对话故事草稿与创造模式手动状态生成，调用会产生所选服务的用量。'; }
    if (this.topic === 'world') { return '创建对话时选择创造模式，可选一本有启用条目的世界书；不选时会使用角色卡内置世界书。再填写状态栏需求。进入对话后可手动生成状态栏；未知数值不会自动当作满值。'; }
    if (this.topic === 'backup') { return '在设置 → 数据与同步 → 备份与恢复中管理备份。恢复前请核对备份来源和范围，重要故事建议定期保留副本。'; }
    return '先在资料库导入角色卡，再在聊天首页点击加号创建对话。选择角色和普通模式或创造模式；进入对应的模式设置，可开启剧情选项并选择每轮 2–6 个选项。普通模式也可让辅助模型先生成一份故事草稿。字体、字号、行距与正文留白都在设置 → 显示与外观 → 字体中调整。';
  }
  @Builder
  header() {
    PageHeader({ title: this.title(), subtitle: this.section === 'sponsor' ? '谢谢你对独立开发的支持' : '帮助与关于',
      onBack: (): void => { ROOT_PATH_STACK.pop(); } })
  }
  @Builder
  content() {
    Column({ space: 18 }) {
      if (this.section === 'help') {
        Button('重新查看新手引导').attributeModifier(new ActionButtonStyle(this.colors)).width('100%')
          .id('help-replay-onboarding').onClick((): void => { this.guidePresented = true; })
        SettingsPicker({ title: '使用指南', selectedId: this.topic, options: this.topics, marker: 'help-topic-picker',
          onSelect: (id: string): void => { this.topic = id; } })
        Text(this.helpText()).fontSize(15).fontColor(this.colors.textPrimary).lineHeight(26).width('100%')
      } else if (this.section === 'feedback') {
        FeedbackContent()
      } else if (this.section === 'sponsor') {
        SponsorContent()
      } else {
        Column({ space: 14 }) {
          Text('HarmonyTavern').fontSize(28).fontWeight(FontWeight.Bold).fontColor(this.colors.textPrimary).width('100%')
          Text('让故事自由生长').fontSize(16).fontColor(this.colors.textSecondary).width('100%')
          if (this.version !== '') { Text('版本 ' + this.version).fontSize(13).fontColor(this.colors.textSecondary).width('100%') }
          Text('在这里连接喜欢的模型，与角色开启故事，整理世界设定，保存属于你的对话。')
            .fontSize(15).fontColor(this.colors.textPrimary).lineHeight(26).width('100%')
        }.width('100%').padding(20).borderRadius(24).attributeModifier(new SurfaceStyle(this.colors, 24))
      }
    }.width('100%')
  }
  build() {
    PageSurface({ topBar: (): void => { this.header(); }, content: (): void => { this.content(); } })
      .bindContentCover($$this.guidePresented, this.guideCover(), {
        modalTransition: ModalTransition.NONE, backgroundColor: Color.Transparent,
        onWillDismiss: (): void => { this.guidePresented = false; }
      })
  }

  @Builder
  guideCover() {
    OnboardingGuide({ onFinish: (): void => { this.guidePresented = false; } })
  }
}
