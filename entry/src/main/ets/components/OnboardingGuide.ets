import { COLORS, ColorTokens } from '../theme/Tokens';
import { ActionButtonStyle, ActionTone } from '../theme/ControlStyles';
import { SurfaceStyle } from '../theme/SurfaceStyles';
import { iconTint } from '../theme/IconTint';
import { PageSurface } from './PageSurface';
import { PageHeader } from './PageHeader';
import { Duration, Spring } from '../theme/Motion';
import { MOTION_REDUCE_KEY } from '../theme/Motion';
import { FrameCallback } from '@kit.ArkUI';

class GuideFrame extends FrameCallback {
  private action: () => void;
  constructor(action: () => void) { super(); this.action = action; }
  onFrame(_frameTime: number): void { this.action(); }
}

interface GuideStep {
  title: string;
  subtitle: string;
  icon: Resource;
  points: string[];
  note: string;
}

const GUIDE_STEPS: GuideStep[] = [
  { title: '欢迎来到 HarmonyTavern', subtitle: '让故事，从你喜欢的方式开始', icon: $r('app.media.nav_chat'),
    points: ['聊天：创建对话，和角色一起推进故事。', '角色：查看、编辑或导入角色卡。', '资料库：整理世界书、聊天记录与创作资源。', '设置：管理模型连接、外观和数据备份。'],
    note: '这份引导不会替你改动模型、主题或现有聊天。' },
  { title: '先连接一个聊天模型', subtitle: '设置 → 模型与连接 → 服务商管理', icon: $r('app.media.icon_cloud'),
    points: ['选择服务商，填写你自己的 API 密钥与连接信息。', '添加并选择可用模型，保存后即可用于聊天。', '辅助模型在「辅助模型设置」中单独选择，用于配置整理、故事草稿和状态生成。'],
    note: '生成内容会把所需上下文发送给你选择的服务商，可能产生相应服务费用。请妥善保管密钥。' },
  { title: '认识你的第一位旅伴', subtitle: '角色 → 加号，或资料库 → 角色卡导入', icon: $r('app.media.nav_character'),
    points: ['可以先使用已有角色，也可以导入自己的角色卡。', '在角色管理里编辑名称、描述、开场白等设定。', '世界书用于补充背景与规则，可在资料库中导入、编辑。'],
    note: '导入前确认文件来源；你自己的角色设定和故事资料可以随时整理。' },
  { title: '开启一段对话', subtitle: '聊天首页 → 加号 → 创建聊天', icon: $r('app.media.nav_chat'),
    points: ['选择普通模式或创造模式；进入模式设置，可开启剧情选项并选择每轮 2–6 个选项。', '在底部输入消息，点击发送；生成时可以点击停止。', '输入栏旁的加号可添加图片、切换模型、搜索消息和查看摘要。', '每条消息下方可编辑内容，或从更多菜单重新生成。'],
    note: '普通聊天适合自由对话；创造模式适合需要世界状态的故事。' },
  { title: '把世界慢慢展开', subtitle: '创造模式，以及随时可用的帮助', icon: $r('app.media.icon_book'),
    points: ['创造模式需要世界书与状态需求，进入聊天后可生成状态。', '底部背包和状态图标可查看物品、生命与状态；侧边杯子展开任务、关系、装备和设置。', '在显示与外观里调整主题、字体和光感，换主题会保留磨砂设置。', '使用帮助可以重看引导；反馈与建议可找到 QQ 群。记得定期备份故事。'],
    note: '未知数值会保持未知。世界状态由所选模型辅助整理，请结合实际剧情判断。' }
];

@Component
export struct OnboardingGuide {
  @StorageProp('uiColors') colors: ColorTokens = COLORS;
  @StorageProp('systemTopInset') topInset: number = 0;
  @StorageProp('systemBottomInset') bottomInset: number = 0;
  @State step: number = 0;
  @State displayedStep: number = 0;
  @State contentOpacity: number = 1;
  @State contentOffset: number = 0;
  @StorageProp(MOTION_REDUCE_KEY) @Watch('motionChanged') reduceMotion: boolean = false;
  private revision: number = 0;
  private mounted: boolean = false;
  private guideScroller: Scroller = new Scroller();
  onFinish: () => void = (): void => {};

  aboutToAppear(): void { this.mounted = true; }
  aboutToDisappear(): void { this.mounted = false; this.revision++; }

  private motionChanged(): void {
    if (!this.reduceMotion) { return; }
    this.revision++;
    this.getUIContext().animateTo({ duration: 0 }, (): void => {
      this.displayedStep = this.step; this.contentOpacity = 1; this.contentOffset = 0;
    });
  }

  private moveTo(next: number): void {
    const target: number = Math.max(0, Math.min(GUIDE_STEPS.length - 1, next));
    if (target === this.step) { return; }
    const direction: number = target > this.step ? 1 : -1;
    const revision: number = ++this.revision;
    this.step = target;
    if (this.reduceMotion) { this.motionChanged(); return; }
    this.getUIContext().animateTo({ duration: Duration.instant, curve: Curve.EaseIn,
      onFinish: (): void => {
        if (!this.mounted || revision !== this.revision) { return; }
        this.getUIContext().animateTo({ duration: 0 }, (): void => {
          this.displayedStep = this.step; this.contentOffset = direction * 18;
        });
        this.getUIContext().postFrameCallback(new GuideFrame((): void => {
          if (!this.mounted || revision !== this.revision || this.reduceMotion) { return; }
          this.guideScroller.scrollEdge(Edge.Top);
          this.getUIContext().animateTo({ curve: Spring.enter() }, (): void => {
            this.contentOpacity = 1; this.contentOffset = 0;
          });
        }));
      }
    }, (): void => { this.contentOpacity = 0; this.contentOffset = -direction * 12; });
  }

  @Builder
  headerActions() {
    Button('跳过').attributeModifier(new ActionButtonStyle(this.colors)).width(64)
      .id('onboarding-skip').onClick((): void => { this.onFinish(); })
  }

  @Builder
  header() {
    PageHeader({ title: '初来酒馆', subtitle: '新手引导 · ' + (this.step + 1) + ' / ' + GUIDE_STEPS.length,
      showBack: this.step > 0, onBack: (): void => { this.moveTo(this.step - 1); },
      actions: (): void => { this.headerActions(); } })
  }

  @Builder
  content() {
    Column({ space: 24 }) {
      Row({ space: 6 }) {
        ForEach(GUIDE_STEPS, (guideStep: GuideStep, index: number) => {
          Column().height(4).layoutWeight(1).borderRadius(2)
            .backgroundColor(index <= this.step ? this.colors.accent : this.colors.borderSubtle)
            .animation({ duration: this.reduceMotion ? 0 : Duration.local, curve: Curve.EaseInOut })
            .accessibilityLevel('no')
        }, (item: GuideStep): string => item.title)
      }.width('100%')
      Scroll(this.guideScroller) {
      Column({ space: 20 }) {
      Column({ space: 16 }) {
        Image(GUIDE_STEPS[this.displayedStep].icon).width(48).height(48).colorFilter(iconTint(this.colors.accent)).accessibilityLevel('no')
        Text(GUIDE_STEPS[this.displayedStep].title).fontSize(26).fontWeight(FontWeight.Bold)
          .fontColor(this.colors.textPrimary).width('100%').id('onboarding-step-title')
        Text(GUIDE_STEPS[this.displayedStep].subtitle).fontSize(14).lineHeight(24)
          .fontColor(this.colors.textSecondary).width('100%')
      }.width('100%').alignItems(HorizontalAlign.Start)
      Column({ space: 18 }) {
        ForEach(GUIDE_STEPS[this.displayedStep].points, (point: string, index: number) => {
          Row({ space: 12 }) {
            Text(String(index + 1).padStart(2, '0')).fontSize(13).fontWeight(FontWeight.Medium)
              .fontColor(this.colors.accent).width(24)
            Text(point).fontSize(15).lineHeight(26).fontColor(this.colors.textPrimary).layoutWeight(1)
          }.width('100%').alignItems(VerticalAlign.Top)
        }, (point: string): string => point)
      }.width('100%').padding(20).attributeModifier(new SurfaceStyle(this.colors, 24))
      Text(GUIDE_STEPS[this.displayedStep].note).fontSize(13).lineHeight(23).fontColor(this.colors.textSecondary).width('100%')
      }.width('100%').opacity(this.contentOpacity).translate({ x: this.contentOffset })
      }.width('100%').layoutWeight(1).scrollBar(BarState.Off).align(Alignment.Top)
      Row({ space: 12 }) {
        if (this.step > 0) {
          Button('上一步').attributeModifier(new ActionButtonStyle(this.colors)).layoutWeight(1)
            .id('onboarding-previous').onClick((): void => { this.moveTo(this.step - 1); })
        }
        Button(this.step === GUIDE_STEPS.length - 1 ? '进入酒馆' : '下一步')
          .attributeModifier(new ActionButtonStyle(this.colors, ActionTone.Primary)).layoutWeight(2)
          .id('onboarding-next').onClick((): void => {
            if (this.step === GUIDE_STEPS.length - 1) { this.onFinish(); }
            else { this.moveTo(this.step + 1); }
          })
      }.width('100%')
      Text('之后可在「设置 → 使用帮助」重新查看。').fontSize(12).lineHeight(21).fontColor(this.colors.textTertiary).width('100%')
    }.width('100%').height('100%').constraintSize({ maxWidth: 560 }).alignSelf(ItemAlign.Center)
      .padding({ left: 20, right: 20, top: this.topInset + 104, bottom: Math.max(24, this.bottomInset + 12) })
  }

  build() {
    PageSurface({ topBar: (): void => { this.header(); }, content: (): void => { this.content(); }, scrollable: false, edgeFades: false })
  }
}
