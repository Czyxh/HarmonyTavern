import { UsageStatisticsPage } from './UsageStatisticsPage';
import { SettingsEntryRow } from '../components/SettingsEntryRow';
import { SurfaceStyle } from '../theme/SurfaceStyles';
import { LiquidMenuItem } from '../components/LiquidMenuItem';
import { ActionButtonStyle, ActionTone, InputFieldStyle } from '../theme/ControlStyles';
import { HeaderAction } from '../components/HeaderAction';
import { iconTint } from '../theme/IconTint';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { PageSurface } from '../components/PageSurface';
import { PageHeader } from '../components/PageHeader';
import { ChatDock, ChatDockAction, ChatDockState } from '../components/ChatDock';
import { OriginPanel } from '../components/OriginPanel';
import { ChatPanel } from '../components/ChatPanel';
import { OriginPanelState } from '../theme/OriginMotion';
import { PageFrame } from '../components/PageFrame';
import { SwingContent } from '../components/SwingContent';
import { IdentityAvatar } from '../components/IdentityAvatar';
// 首页（P8-1 重构）。
//
// 结构：Navigation 根容器 → 底部三 Tab（聊天 / 角色 / 更多）→ 详情页经 pageMap 压栈。
// 与旧版差异：
//   2. 后端初始化从"必须手点按钮"改为页面出现即自动执行（幂等），失败可重试；
//   3. 会话与角色各自有独立入口，不再把两件事塞在一个页面。
//
// 对应 DevEco 工程路径：entry/src/main/ets/pages/Index.ets
import { common, bundleManager } from '@kit.AbilityKit';
import { window, KeyboardAvoidMode } from '@kit.ArkUI';
import { curves } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Backend, BackendError, OhosPathsPayloadLike } from '../backend/Backend';
import { BundledMedia, MediaExtractionResult } from '../backend/BundledMedia';
import { ChatIntent, GroupIntent, StoryIntent, ROOT_PATH_STACK } from '../nav/RootNav';
import { StoryPage } from './StoryPage';
import { PersonalizationStore, STORY_WELCOME_DISMISSED_KEY } from '../theme/PersonalizationStore';
import { BuiltinAssistant } from '../backend/BuiltinAssistant';
import { ChatPage } from './ChatPage';
import { SettingsPage } from './SettingsPage';
import { AppearancePage } from './AppearancePage';
import { ExtensionPage } from './ExtensionPage';
import { CharactersPage } from './CharactersPage';
import { TauriSettingsPage } from './TauriSettingsPage';
import { McpPage } from './McpPage';
import { SkillsPage } from './SkillsPage';
import { AgentPage } from './AgentPage';
import { SyncPage } from './SyncPage';
import { PresetsPage } from './PresetsPage';
import { SecretsPage } from './SecretsPage';
import { UserPage } from './UserPage';
import { BackupPage } from './BackupPage';
import { DataPage } from './DataPage';
import { SettingsJsonPage } from './SettingsJsonPage';
import { ToolsPage } from './ToolsPage';
import { AssetsPage } from './AssetsPage';
import { WorldInfoPage } from './WorldInfoPage';
import { GroupPage } from './GroupPage';
import { GroupChatPage } from './GroupChatPage';
import { AdminPage } from './AdminPage';
import { WorldImportPage } from './WorldImportPage';
import { ChatImportPage } from './ChatImportPage';
import { JellyTabBar, JellyTabItem, JELLY_VISIBLE } from '../components/JellyTabBar';
import { GridEntryCard } from '../components/GridEntryCard';
import { entranceEffect, staggeredEntrance, parentTransitionGuard, Spring, Scale, Distance } from '../theme/Motion';
import { LS_BLUR_DEFAULT, LS_BLUR_KEY } from '../theme/LightSense';
import { IMMERSIVE_DEFAULT, IMMERSIVE_KEY } from '../theme/Immersive';
import { HOLDING_HAND_KEY, HOLDING_HAND_UNKNOWN, HOLDING_ENABLED_KEY, HOLDING_ACTION_KEY, HoldingPose } from '../theme/HoldingPose';
import { ModelInfoPage } from './ModelInfoPage';
import { AuxiliaryModelsPage } from './AuxiliaryModelsPage';
import { HelpAboutPage } from './HelpAboutPage';
import { OnboardingGuide } from '../components/OnboardingGuide';
import { OnboardingState } from '../theme/OnboardingState';
import { ChatStorePage } from './ChatStorePage';
import { Motion, Radius, Spacing, Touch, Typography } from '../theme/Tokens';
import { Appearance, BACKGROUND_DEFAULT, BACKGROUND_KEY } from '../theme/Appearance';
import { GLASS_CARD, GLASS_TAB_BAR, glassEffect, glassLightColor, Glass } from '../theme/Glass';
import { SystemGlass } from '../theme/SystemGlass';
import { SystemMaterialTray } from '../components/SystemMaterialTray';
import { EmptyHint, ErrorBannerView } from '../components/Builders';
import {
  BackendStatus,
  BootstrapMetadata,
  CharacterDto,
  ChatSearchResultDto,
} from '../backend/Types';
import { ChatSearchResult, RenameChatDto } from '../backend/AdminTypes';

const GLASS_ACTIVE_PILL: string = 'rgba(47,107,255,0.14)';

/** Tab 项（自绘玻璃栏用）。 */
/** 更多页的功能入口（数据化 → 才能做错开入场）。 */
interface MoreEntry {
  label: string;
  route: string;
  group: string;
  hint: string;
}

const SETTINGS_GROUPS: string[] = ['模型与连接', '外观与偏好', '身份与创作', '扩展与工具', '数据与同步', '帮助与关于'];
const MORE_ENTRIES: MoreEntry[] = [
  { label: '显示与外观', route: 'pages/AppearancePage', group: '外观与偏好', hint: '阅读配色、玻璃质感、字体与动态效果' },
  { label: '通用偏好', route: 'pages/TauriSettingsPage', group: '外观与偏好', hint: '应用行为、性能与网络偏好' },
  { label: '用户设定管理', route: 'pages/UserPage', group: '身份与创作', hint: '头像、昵称、人设与描述插入位置' },
  { label: '聊天与生成', route: 'pages/SettingsPage', group: '身份与创作', hint: '生成参数、系统提示词与创作设置' },
  { label: '回复预设', route: 'pages/PresetsPage', group: '身份与创作', hint: '为不同角色和故事保存回应风格' },
  { label: '创作资源', route: 'pages/AssetsPage', group: '身份与创作', hint: '整理故事中的图片、声音与文件' },
  { label: '服务商管理', route: 'pages/ProviderPage', group: '模型与连接', hint: '连接 AI 服务，配置端点与模型' },
  { label: '辅助模型设置', route: 'pages/AuxiliaryModelsPage', group: '模型与连接', hint: '选择内置助手或添加自己的辅助模型' },
  { label: '模型目录', route: 'pages/ModelInfoPage', group: '模型与连接', hint: '查看可用模型与服务状态' },
  { label: '使用统计', route: 'pages/UsageStatisticsPage', group: '模型与连接', hint: '聊天活动、模型调用与真实 Token 用量' },
  { label: '密钥管理', route: 'pages/SecretsPage', group: '模型与连接', hint: '管理模型服务凭据' },
  { label: '工具服务', route: 'pages/McpPage', group: '扩展与工具', hint: '通过 MCP 连接外部工具和服务' },
  { label: '技能', route: 'pages/SkillsPage', group: '扩展与工具', hint: '管理助手可使用的知识与能力' },
  { label: 'Agent', route: 'pages/AgentPage', group: '扩展与工具', hint: '自动任务与运行记录' },
  { label: '对话工具', route: 'pages/ToolsPage', group: '扩展与工具', hint: '快照与其他对话辅助工具' },
  { label: '酒馆扩展', route: 'pages/ExtensionPage', group: '扩展与工具', hint: '安装与管理扩展能力' },
  { label: '设备同步', route: 'pages/SyncPage', group: '数据与同步', hint: '在设备之间同步你的内容' },
  { label: '备份与恢复', route: 'pages/BackupPage', group: '数据与同步', hint: '为珍贵的故事留一份副本' },
  { label: '数据管理', route: 'pages/DataPage', group: '数据与同步', hint: '整理角色与聊天数据' },
  { label: '会话存储', route: 'pages/ChatStorePage', group: '数据与同步', hint: '历史记录与扩展数据' },
  { label: '使用帮助', route: 'pages/HelpPage', group: '帮助与关于', hint: '了解模型连接、对话与创造模式' },
  { label: '反馈与建议', route: 'pages/FeedbackPage', group: '帮助与关于', hint: 'QQ 交流反馈群 · 1125678554' },
  { label: '关于 HarmonyTavern', route: 'pages/AboutPage', group: '帮助与关于', hint: '认识酒馆与查看版本信息' },
  { label: '赞助开发者', route: 'pages/SponsorPage', group: '帮助与关于', hint: '请开发者喝一杯 · 感谢你的支持' }
];

interface TabItem {
  label: string;
  glyph: string;
}

const TAB_ITEMS: TabItem[] = [
  { label: '聊天', glyph: '◍' },
  { label: '角色', glyph: '☰' },
  { label: '资料库', glyph: '⌸' },
  { label: '设置', glyph: '⚙' }
];

const DOMAIN: number = 0x0000;
const TAG: string = 'HarmonyTavern';

/** 会话列表行（首页只展示摘要，避免把整份 messages 提到内存）。 */
interface ChatHomeRow {
  characterName: string;
  fileName: string;
  preview: string;
  count: number;
}

/** 卡片按下反馈：0.97 缩放属 House Style（H4），不是官方数值；只在可点卡片上用。 */
@Styles
function cardPressNormal() {
  .scale({ x: 1, y: 1 })
  .opacity(1)
}

@Styles
function cardPressPressed() {
  .scale({ x: 0.97, y: 0.97 })
  .opacity(0.92)
}

@Entry
@Component
struct Index {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @State dock: ChatDockState = new ChatDockState();
  @State @Watch('dockVisibilityChanged') dockMode: string = 'home';
  @State dockPresentationMode: string = 'home';
  @State dockPresence: number = 1;
  private dockPresenceTarget: number = 1;
  @StorageProp('systemMaterialAvailable') systemMaterialAvailable: boolean = false;
  @State chatReveal: number = 0;
  @State dockHeight: number = 56;
  @State dockActionOnRight: boolean = false;
  @StorageProp(HOLDING_HAND_KEY) @Watch('holdingHandChanged') holdingHand: number = HOLDING_HAND_UNKNOWN;
  @StorageProp(HOLDING_ENABLED_KEY) @Watch('holdingHandChanged') holdingEnabled: boolean = true;
  @StorageProp(HOLDING_ACTION_KEY) @Watch('holdingHandChanged') holdingAction: boolean = true;
  private dockActionInteracting: boolean = false;
  @StorageProp(IMMERSIVE_KEY) immersiveLevel: number = IMMERSIVE_DEFAULT;
  // ---- 首页状态 ----
  @State currentTab: number = 0;
  @State displayedTab: number = 0;
  /** 根容器实测宽度（vp），给底栏按断点算宽度用 */
  @State @Watch('dockVisibilityChanged') winWidthVp: number = 0;
  /** 状态栏高度（vp）。沉浸式下内容会铺到状态栏底下，靠这个值把内容让下来 */
  @State statusBarVp: number = 0;
  @State bottomBarVp: number = 0;
  @State spaceQuery: string = '';
  private uiWindow: window.Window | undefined = undefined;
  private avoidAreaListener: (data: window.AvoidAreaOptions) => void = (): void => this.refreshInsets();
  private keyboardHeightListener: (height: number) => void = (height: number): void => {
    if (this.uiWindow === undefined) { return; }
    try {
      const windowHeight: number = this.uiWindow.getWindowProperties().windowRect.height;
      AppStorage.setOrCreate('appWindowHeight', this.getUIContext().px2vp(windowHeight));
      AppStorage.setOrCreate('systemKeyboardTop', height > 0 ? this.getUIContext().px2vp(windowHeight - height) : 0);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Unable to refresh keyboard inset: %{public}s', (error as Error).message);
    }
  };

  private refreshInsets(): void {
    if (this.uiWindow === undefined) { return; }
    try {
      AppStorage.setOrCreate('appWindowHeight', this.getUIContext().px2vp(this.uiWindow.getWindowProperties().windowRect.height));
      AppStorage.setOrCreate('appWindowWidth', this.getUIContext().px2vp(this.uiWindow.getWindowProperties().windowRect.width));
      const systemArea: window.AvoidArea = this.uiWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const cutoutArea: window.AvoidArea = this.uiWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
      const navigationArea: window.AvoidArea = this.uiWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      this.statusBarVp = this.getUIContext().px2vp(Math.max(systemArea.topRect.height, cutoutArea.topRect.height));
      AppStorage.setOrCreate('systemTopInset', this.statusBarVp);
      this.bottomBarVp = this.getUIContext().px2vp(Math.max(systemArea.bottomRect.height, navigationArea.bottomRect.height));
      AppStorage.setOrCreate('systemBottomInset', this.bottomBarVp);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Unable to refresh UI insets: %{public}s', (error as Error).message);
    }
  }

  aboutToDisappear(): void {
    this.uiWindow?.off('avoidAreaChange', this.avoidAreaListener);
    this.uiWindow?.off('keyboardHeightChange', this.keyboardHeightListener);
    AppStorage.setOrCreate('systemKeyboardTop', 0);
  }
  /** 模糊强度：只要这个值变，整页重建 → 底栏/页头的 glassEffect 立即生效 */
  @StorageProp(LS_BLUR_KEY) blurRadius: number = LS_BLUR_DEFAULT;
  @StorageProp('reduceMotion') @Watch('dockVisibilityChanged') reduceMotion: boolean = false;
  @StorageProp(BACKGROUND_KEY) backgroundId: string = BACKGROUND_DEFAULT;

  /** 底部栏用果冻玻璃组件，它要 JellyTabItem[]，这里做一次显式转换 */
  @State jellyItems: JellyTabItem[] = TAB_ITEMS.map((item: TabItem): JellyTabItem => {
    const converted: JellyTabItem = { label: item.label, glyph: item.glyph };
    return converted;
  });
  @State ready: boolean = false;
  @State onboardingPresented: boolean = false;
  @State chatHistoryLoaded: boolean = false;
  @StorageProp(STORY_WELCOME_DISMISSED_KEY) storyWelcomeDismissed: boolean = false;
  @State initText: string = '正在初始化…';
  @State chatRows: ChatHomeRow[] = [];
  @State groupRows: ESObject[] = [];
  @State homeCreatePanel: OriginPanelState = new OriginPanelState();
  @State refreshingChats: boolean = false;
  @State charRows: CharacterDto[] = [];
  @State listError: string = '';
  @State busy: boolean = false;

  // ---- 会话管理（P8-4）----
  /** 搜索关键词（非空时列表切到搜索结果视图） */
  @State chatQuery: string = '';
  @State searchRows: ChatSearchResult[] = [];
  /** 会话行操作面板：''=关闭，'menu' | 'rename' | 'delete' */
  @State @Watch('chatActionChanged') actionMode: string = '';
  @State actionPanel: OriginPanelState = new OriginPanelState();
  @State actionCharacter: string = '';
  @State actionFile: string = '';
  @State renameText: string = '';

  @State statusText: string = '未初始化';
  @State mediaText: string = '';
  @State bootstrapText: string = '';
  @State pathsText: string = '';
  @State errorText: string = '';

  // P7 步骤 3c：LAN 配对请求确认（lan_sync:pair_request → 弹窗 → lan_sync_confirm_pairing）。
  private pairUnsub: (() => void) | null = null;

  aboutToAppear(): void {
    this.onboardingPresented = OnboardingState.shouldShow();
    // 沉浸式状态栏：EntryAbility 里已经 setWindowLayoutFullScreen(true)，
    // 所以必须自己把状态栏高度补成内边距，否则页头会被时间/电量压住。
    // 想让页面内容真的铺到状态栏下（完全沉浸）：把下面这行的赋值注释掉即可。
    try {
      window.getLastWindow(this.getUIContext().getHostContext()).then((win: window.Window) => {
        this.uiWindow = win;
        this.refreshInsets();
        win.on('avoidAreaChange', this.avoidAreaListener);
        win.on('keyboardHeightChange', this.keyboardHeightListener);
      }).catch((err: Error) => {
        hilog.warn(0x0000, 'Index', 'avoid area failed: %{public}s', err.message);
      });
    } catch (err) {
      // 拿不到就按 0 处理，页面顶到最上，不会崩
    }
    this.attachPairRequestListener();
    // 自动初始化：失败会显示在「更多」页并可重试，不需要用户先点按钮。
    this.ensureInitialized();

  }

  // ---- 初始化与数据加载 ----

  /** 幂等初始化：媒体抽取 → initialize → 等就绪 → 播撒默认内容 → 刷新首页数据。 */
  async ensureInitialized(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.listError = '';
    let step: string = '采集沙箱路径';
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      if (context === undefined || context === null || typeof context.filesDir !== 'string') {
        throw new Error('getHostContext() did not return a UIAbilityContext with filesDir');
      }
      const bundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT
      );
      const media: MediaExtractionResult = BundledMedia.ensureExtracted(context, bundleInfo.versionCode);
      this.mediaText = media.reused
        ? `媒体: 已就绪 ${media.declared} 个（复用 marker）`
        : `媒体: 已抽取 ${media.extracted} 个 / ${Math.round(media.totalBytes / 1024)} KB`;

      const payload: OhosPathsPayloadLike = {
        filesDir: context.filesDir,
        databaseDir: context.databaseDir,
        cacheDir: context.cacheDir,
        bundleName: context.applicationInfo.name,
        versionName: bundleInfo.versionName,
        bundledMediaDir: media.root
      };

      step = 'initialize';
      const status: BackendStatus = await Backend.initialize(payload);
      this.statusText =
        `ready=${status.ready} version=${status.version} services=${status.services} ` +
        `text=${status.bundledResources} media=${status.bundledMediaFiles}`;
      this.pathsText = `dataRoot=${status.dataRoot}`;

      step = 'wait_for_backend_ready';
      await Backend.waitForBackendReady();

      step = '播撒默认内容';
      const alreadySeeded: boolean = await Backend.isDefaultContentInitialized();
      await Backend.initializeDefaultContent();
      BuiltinAssistant.seed(context).catch((error: Error): void => { hilog.warn(DOMAIN, TAG, 'builtin assistant seed failed: %{public}s', error.message); });
      const meta: BootstrapMetadata = await Backend.getBootstrapMetadata();
      this.bootstrapText =
        `角色 ${meta.characters.length} / 分组 ${meta.groups.length} / 头像 ${meta.avatars.length}` +
        ` | 播撒前=${alreadySeeded}`;

      this.ready = true;
      this.initText = `就绪 · v${status.version}`;
      await this.reloadHome();
    } catch (err) {
      const message: string = (err as Error).message;
      this.ready = false;
      this.initText = `初始化失败[${step}]`;
      this.errorText = `失败[${step}]: ${message}`;
      hilog.error(DOMAIN, TAG, 'init failed at %{public}s: %{public}s', step, message);
    } finally {
      this.busy = false;
    }
  }

  /** 刷新首页两列表（会话 + 角色）。 */
  async reloadHome(): Promise<void> {
    this.listError = '';
    await this.loadChats();
    await this.loadCharacters();
  }

  async loadChats(): Promise<void> {
    try {
      const chats: ChatSearchResultDto[] = await Backend.listChatSummaries();
      this.chatRows = chats.map((chat: ChatSearchResultDto): ChatHomeRow => ({
        characterName: chat.character_name, fileName: chat.file_name,
        preview: chat.preview || '（空会话）', count: chat.message_count
      }));
      if (chats.length > 0) { PersonalizationStore.set(STORY_WELCOME_DISMISSED_KEY, true); }
      this.groupRows = await Backend.getAllGroups();
      if (this.groupRows.some((group: ESObject): boolean => {
        return ((group.chats as string[]) ?? []).length > 0 || ((group.chat_id as string) ?? '') !== '';
      })) { PersonalizationStore.set(STORY_WELCOME_DISMISSED_KEY, true); }
      this.chatHistoryLoaded = true;
    } catch (err) {
      this.listError = `读取会话失败：${(err as BackendError).message}`;
    }
  }

  async loadCharacters(): Promise<void> {
    try {
      const chars: CharacterDto[] = await Backend.getAllCharacters();
      this.charRows = chars;
    } catch (err) {
      this.listError = `读取角色失败：${(err as BackendError).message}`;
    }
  }

  // ---- 会话管理（P8-4）：搜索 / 重命名 / 备份 / 删除 ----

  /** 跨会话搜索消息内容（search_chats）。 */
  async runChatSearch(): Promise<void> {
    const query: string = this.chatQuery.trim();
    this.listError = '';
    if (query === '') {
      this.searchRows = [];
      return;
    }
    try {
      this.searchRows = await Backend.searchChats(query);
    } catch (err) {
      this.listError = `搜索失败：${(err as BackendError).message}`;
      this.searchRows = [];
    }
  }

  openChatAction(characterName: string, fileName: string, mode: string): void {
    this.actionCharacter = characterName;
    this.actionFile = fileName;
    this.renameText = fileName;
    this.actionMode = mode;
    const source: string = 'conversation-options-' + characterName + '/' + fileName;
    if (mode === 'menu') { this.actionPanel.openMenu(this.getUIContext(), source, 156, ['重命名', '备份', '删除']); }
    else { this.actionPanel.open(this.getUIContext(), source, 0.4); }
    this.listError = '';
  }

  clearChatAction(): void {
    this.actionPanel.close();
  }

  private chatActionChanged(): void {
    if (this.actionMode === '') { this.actionPanel.close(); }
  }

  @Builder
  chatActionCover() {
    Stack() {
      OriginPanel({ state: this.actionPanel, onClosed: (): void => {
        this.actionMode = '';
        this.actionCharacter = '';
        this.actionFile = '';
      }, content: (): void => { this.chatActionSurface(); } })
    }
    .width('100%').height('100%')
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }

  @Builder
  chatActionMenu() {
    Scroll() {
      Column({ space: 4 }) {
        LiquidMenuItem({ label: '重命名', onSelect: (): void => {
          const character: string = this.actionCharacter; const file: string = this.actionFile;
          this.actionPanel.select((): void => { this.openChatAction(character, file, 'rename'); });
        } })
        LiquidMenuItem({ label: '备份', available: !this.busy, onSelect: (): void => {
          const character: string = this.actionCharacter; const file: string = this.actionFile;
          this.actionPanel.select((): void => { this.actionCharacter = character; this.actionFile = file; this.backupChatRow(); });
        } })
        LiquidMenuItem({ label: '删除', destructive: true, onSelect: (): void => {
          const character: string = this.actionCharacter; const file: string = this.actionFile;
          this.actionPanel.select((): void => { this.openChatAction(character, file, 'delete'); });
        } })
      }.width('100%').padding(8)
        .onAreaChange((_previous: Area, area: Area): void => { this.actionPanel.fitMenuHeight(Number(area.height)); })
    }.width('100%').height('100%').scrollBar(BarState.Off)
  }

  @Builder
  chatActionSurface() {
    if (this.actionMode === 'menu') { this.chatActionMenu() }
    else { this.chatActionSheet() }
  }

  @Builder
  chatActionSheet() {
    ChatPanel({ title: this.actionMode === 'delete' ? '删除会话' : '重命名会话', managedLayout: true, onContentHeight: (height: number): void => { this.actionPanel.fitContentHeight(height); }, onClose: (): void => { this.actionPanel.close(); },
      content: (): void => { this.chatActionPanel(); } })
  }

  /** 重命名会话文件（rename_chat 的 dto 是 snake_case）。 */
  async renameChatRow(): Promise<void> {
    const next: string = this.renameText.trim();
    if (next === '' || next === this.actionFile) {
      this.listError = '新文件名不能为空或与原文件名相同';
      return;
    }
    this.busy = true;
    this.listError = '';
    try {
      const dto: RenameChatDto = {
        character_name: this.actionCharacter,
        old_file_name: this.actionFile,
        new_file_name: next
      };
      const result: string = await Backend.renameChat(dto);
      this.clearChatAction();
      await this.reloadHome();
      hilog.info(DOMAIN, TAG, 'renamed chat -> %{public}s', result);
    } catch (err) {
      this.listError = `重命名失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async backupChatRow(): Promise<void> {
    this.busy = true;
    this.listError = '';
    try {
      await Backend.backupChat(this.actionCharacter, this.actionFile);
      this.listError = '';
      this.clearChatAction();
    } catch (err) {
      this.listError = `备份失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async deleteChatRow(): Promise<void> {
    this.busy = true;
    this.listError = '';
    try {
      await Backend.deleteChat(this.actionCharacter, this.actionFile);
      this.clearChatAction();
      await this.reloadHome();
    } catch (err) {
      this.listError = `删除失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  /** 角色 → 新建会话（character_name 必须是文件 stem，见 P7 缺陷修复）。 */
  async startChatWith(character: CharacterDto): Promise<void> {
    if (this.busy) { return; }
    StoryIntent.request(this.chatKey(character), character.name, character.first_mes ?? '');
  }

  /** 聊天命令键 = 头像文件名去扩展名（内置角色 default_Seraphina ↔ 卡片名 Seraphina）。 */
  private chatKey(character: CharacterDto): string {
    const avatar: string = character.avatar === undefined ? '' : character.avatar;
    if (avatar === '') {
      return character.name;
    }
    const dot: number = avatar.lastIndexOf('.');
    return dot > 0 ? avatar.substring(0, dot) : avatar;
  }


  /** 注册 lan_sync:pair_request 处理器（单实例只挂一次）。 */
  private attachPairRequestListener(): void {
    if (this.pairUnsub !== null) {
      return;
    }
    this.pairUnsub = Backend.on('lan_sync:pair_request', (payload: ESObject): void => {
      this.showPairRequestDialog(payload);
    });
    hilog.info(DOMAIN, TAG, 'pair request listener attached');
  }

  /** 配对确认弹窗：接受/拒绝 → lan_sync_confirm_pairing 解析服务端 oneshot。 */
  private async showPairRequestDialog(payload: ESObject): Promise<void> {
    const requestId: string = payload['request_id'] as string;
    const peerName: string = payload['peer_device_name'] as string;
    const peerId: string = payload['peer_device_id'] as string;
    const peerIp: string = payload['peer_ip'] as string;
    hilog.info(DOMAIN, TAG, 'pair request: %{public}s %{public}s@%{public}s',
      requestId, peerName, peerIp);
    const accepted: boolean = await new Promise<boolean>((resolve: (value: boolean) => void) => {
      this.getUIContext().showAlertDialog({
        title: 'LAN 配对请求',
        message: `设备「${peerName}」（${peerId}，${peerIp}）请求与你配对并同步数据。是否接受？`,
        primaryButton: {
          value: '接受',
          action: () => { resolve(true); }
        },
        secondaryButton: {
          value: '拒绝',
          action: () => { resolve(false); }
        }
      });
    });
    try {
      await Backend.lanSyncConfirmPairing(requestId, accepted);
      hilog.info(DOMAIN, TAG, 'pairing respond: %{public}s accept=%{public}s',
        requestId, String(accepted));
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'pairing respond failed: %{public}s', (err as BackendError).message);
    }
  }


  // ---- UI ----

  private dockTransition(from: NavContentInfo, to: NavContentInfo,
    _operation: NavigationOperation): NavigationAnimatedTransition | undefined {
    const entering: boolean = from.index === -1 && to.name === 'pages/ChatPage';
    const leaving: boolean = from.name === 'pages/ChatPage' && to.index === -1;
    if (!entering && !leaving) {
      if (to.name === 'pages/ChatPage') { this.chatReveal = 1; }
      else if (from.name !== 'pages/ChatPage') { this.chatReveal = 0; }
      this.dockMode = to.index === -1 ? 'home' : (to.name === 'pages/ChatPage' ? 'chat' : 'hidden');
      return undefined;
    }
    return {
      timeout: 700,
      onTransitionEnd: (_success: boolean): void => {
        const names: string[] = ROOT_PATH_STACK.getAllPathName();
        const current: string = names.length > 0 ? names[names.length - 1] : '';
        this.dockMode = current === '' ? 'home' : (current === 'pages/ChatPage' ? 'chat' : 'hidden');
        this.chatReveal = current === 'pages/ChatPage' ? 1 : 0;
      },
      transition: (proxy: NavigationTransitionProxy): void => {
        this.getUIContext().animateTo({ duration: 0 }, (): void => {
          this.dockMode = entering ? 'chat' : 'home';
        });
        this.getUIContext().animateTo({
          duration: this.reduceMotion ? 0 : 320,
          curve: Curve.EaseInOut,
          onFinish: (): void => { proxy.finishTransition(); }
        }, (): void => {
          this.chatReveal = entering ? 1 : 0;
        });
      }
    };
  }

  private dockVisible(): boolean {
    return this.dockMode === 'chat' || (this.dockMode === 'home' && this.winWidthVp < 840);
  }

  private dockVisibilityChanged(): void {
    if (this.dockMode === 'home' || this.dockMode === 'chat') { this.dockPresentationMode = this.dockMode; }
    const target: number = this.dockVisible() ? 1 : 0;
    if (target === this.dockPresenceTarget && !this.reduceMotion) { return; }
    this.dockPresenceTarget = target;
    this.getUIContext().animateTo(this.reduceMotion ? { duration: 0 } : target === 1 ? {
      curve: curves.springMotion(0.42, 0.76, 0.08)
    } : {
      duration: 240, curve: curves.cubicBezierCurve(0.4, 0, 0.72, 0.22)
    }, (): void => { this.dockPresence = target; });
  }

  private nativeDockSurface(): boolean {
    return this.blurRadius > 0 && this.systemMaterialAvailable;
  }

  private dockWidth(): number {
    const homeWidth: number = Math.max(200, Math.min(380, this.winWidthVp - 40));
    const chatWidth: number = Math.max(200, Math.min(800, this.winWidthVp - 24));
    return homeWidth + (chatWidth - homeWidth) * this.chatReveal;
  }

  private holdingHandChanged(): void {
    if (this.dockActionInteracting) { return; }
    const onRight: boolean = this.holdingEnabled && this.holdingAction
      ? HoldingPose.actionOnRight(this.holdingHand, this.dockActionOnRight) : false;
    if (onRight === this.dockActionOnRight) { return; }
    this.getUIContext().animateTo({ duration: this.reduceMotion ? 0 : 220, curve: Curve.EaseInOut }, (): void => {
      this.dockActionOnRight = onRight;
    });
  }

  private dockInteractionChanged(active: boolean): void {
    this.dockActionInteracting = active;
    if (!active) { this.holdingHandChanged(); }
  }

  private openHomeCreate(source: string): void {
    if (!this.ready || this.busy) { return; }
    this.homeCreatePanel.openMenu(this.getUIContext(), source, 116, ['创建对话', '创建群聊']);
  }

  private async refreshChatHome(): Promise<void> {
    if (this.refreshingChats) { return; }
    this.refreshingChats = true;
    try { await this.reloadHome(); if (this.chatQuery !== '') { await this.runChatSearch(); }
      if (this.listError === '') { this.getUIContext().getPromptAction().showToast({ message: '聊天列表已刷新' }); }
    } finally { this.refreshingChats = false; }
  }

  @Builder
  homeCreateContent() {
    Scroll() {
      Column({ space: 4 }) {
        LiquidMenuItem({ label: '创建对话', onSelect: (): void => {
          this.homeCreatePanel.select((): void => { StoryIntent.request('', '', ''); });
        } })
        LiquidMenuItem({ label: '创建群聊', onSelect: (): void => {
          this.homeCreatePanel.select((): void => { GroupIntent.request(); ROOT_PATH_STACK.pushPathByName('pages/GroupPage', null); });
        } })
      }.width('100%').padding(8)
        .onAreaChange((_previous: Area, area: Area): void => {
          this.homeCreatePanel.fitMenuHeight(Number(area.height));
        })
    }.width('100%').height('100%').scrollBar(BarState.Off)
  }

  @Builder
  homeCreateCover() {
    OriginPanel({ state: this.homeCreatePanel, content: (): void => { this.homeCreateContent(); },
      onClosed: (): void => { this.dockInteractionChanged(false); } })
  }

  @Builder
  nativeChatComposer() {
    ChatDock({ state: this.dock })
  }

  @Builder
  floatingDock() {
    Row({ space: this.dockPresentationMode === 'chat' ? 8 : 0 }) {
      ChatDockAction({
        state: this.dock, revealed: this.dockPresentationMode === 'chat', onRight: this.dockActionOnRight,
        onInteractionChange: (active: boolean): void => { this.dockInteractionChanged(active); }
      })
        .margin({ bottom: 2 })
        .translate({ x: this.dockPresentationMode === 'chat' && this.dockActionOnRight ? this.dockWidth() - 52 : 0 })
      Column() {
        Stack() {
          if (this.dockPresentationMode === 'chat' && this.nativeDockSurface()) {
            SystemMaterialTray({ content: (): void => { this.nativeChatComposer(); } })
          } else {
          JellyTabBar({
            items: this.jellyItems, currentIndex: this.currentTab,
            containerWidthVp: this.winWidthVp, bare: true,
            onSelect: (index: number): void => { this.currentTab = index; }
          })
            .visibility(this.dockPresentationMode === 'chat' ? Visibility.None : Visibility.Visible)
            .enabled(this.dockPresentationMode === 'home')
            .accessibilityLevel(this.dockPresentationMode === 'home' ? 'auto' : 'no-hide-descendants')
          ChatDock({ state: this.dock })
            .visibility(this.dockPresentationMode === 'chat' ? Visibility.Visible : Visibility.None)
            .enabled(this.dockPresentationMode === 'chat')
            .accessibilityLevel(this.dockPresentationMode === 'chat' ? 'auto' : 'no-hide-descendants')
          }
        }
        .width('100%')
      }
      .padding(this.nativeDockSurface() ? 0 : 6)
      .layoutWeight(1)
      .constraintSize({ minHeight: 56 })
      .borderRadius(28)
      .backgroundEffect(this.nativeDockSurface() ? { radius: 0, color: Color.Transparent } :
        glassEffect(GLASS_TAB_BAR, this.blurRadius, this.immersiveLevel, this.uiColors))
      .linearGradient({
        angle: 155,
        colors: [[this.nativeDockSurface() ? this.uiColors.clear : glassLightColor(this.uiColors.highlight, 0.16), 0], [this.uiColors.clear, 0.45],
          [this.nativeDockSurface() ? this.uiColors.clear : glassLightColor(this.uiColors.reflection, 0.12), 1]]
      })
      .border({ radius: 28, width: this.nativeDockSurface() ? 0 : 0.8, color: this.uiColors.glassEdge })
      .clip(true)
      .shadow({ radius: this.nativeDockSurface() ? 0 : 18, color: this.uiColors.softShadow, offsetY: 6 })
      .translate({ x: this.dockPresentationMode === 'chat' && this.dockActionOnRight ? -60 : 0 })
    }
    .width(this.dockWidth())
    .constraintSize({ minHeight: 56 })
    .alignItems(VerticalAlign.Bottom)
    .onAreaChange((_previous: Area, current: Area) => {
      this.dockHeight = Number(current.height);
    })
    .margin({ bottom: this.bottomBarVp + 10 })
    .scale({ x: this.reduceMotion ? 1 : 0.56 + this.dockPresence * 0.44,
      y: this.reduceMotion ? 1 : 0.36 + this.dockPresence * 0.64, centerX: '50%', centerY: '100%' })
    .opacity(Math.max(0, Math.min(1, this.dockPresence * 1.7)))
    .translate({ y: (1 - this.dockPresence) * (this.dockHeight + this.bottomBarVp + 24) })
    .enabled(this.dockVisible())
    .hitTestBehavior(this.dockVisible() ? HitTestMode.Default : HitTestMode.None)
    .accessibilityLevel(this.dockVisible() ? 'auto' : 'no-hide-descendants')
  }

  @Builder
  chatTabSurfaceContent() {
      Column({ space: 0 }) {
      if (this.ready && this.groupRows.length > 0 && this.chatQuery === '') {
        Column({ space: 8 }) {
          Text('群聊').fontSize(15).fontColor(this.uiColors.textSecondary).width('100%')
          ForEach(this.groupRows, (group: ESObject) => {
            Button({ type: ButtonType.Normal }) {
              Row({ space: 12 }) {
                IdentityAvatar({ name: group.name as string, diameter: 44 })
                Column({ space: 4 }) {
                  Text(group.name as string).fontSize(17).fontColor(this.uiColors.textPrimary)
                  Text(`${((group.members as string[]) || []).length} 位角色 · 群聊`).fontSize(12).fontColor(this.uiColors.textSecondary)
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Image($r('app.media.icon_chevron')).width(16).height(16).colorFilter(iconTint(this.uiColors.textSecondary))
              }.width('100%').padding(12)
            }.width('100%').padding(0).backgroundColor(this.uiColors.bgSurface).borderRadius(20)
              .id('home-group-' + (group.id as string))
              .onClick((): void => { GroupIntent.request(group.id as string); ROOT_PATH_STACK.pushPathByName('pages/GroupPage', null); })
          }, (group: ESObject) => group.id as string)
        }.width('100%').padding({ left: 20, right: 20, top: 12, bottom: 12 })
      }
      
      if (this.chatQuery === '' && this.chatHistoryLoaded && !this.storyWelcomeDismissed) {
        Column() { this.welcomeCard() }
          .width('100%')
          .padding({ left: Spacing.lg, right: Spacing.lg })
      }

      // 全量内容搜索（search_chats）：跨会话找消息。
      Search({ placeholder: '寻找聊过的故事', value: this.chatQuery })
        .height(Touch.minTarget + 8)
        .margin({ left: Spacing.lg, right: Spacing.lg, bottom: Spacing.sm })
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .fontColor(this.uiColors.textPrimary)
        .placeholderColor(this.uiColors.textTertiary)
        .borderRadius(Radius.md)
        .onChange((value: string) => {
          this.chatQuery = value;
        })
        .onSubmit(() => {
          this.runChatSearch();
        })

      if (this.chatQuery !== '') {
        Row({ space: Spacing.sm }) {
          Text(`「${this.chatQuery}」命中 ${this.searchRows.length} 条`)
            .fontSize(Typography.caption)
            .fontColor(this.uiColors.textSecondary)
            .layoutWeight(1)
          Button('搜索', { type: ButtonType.Normal })
            .fontSize(Typography.caption)
            .height(28)
            .onClick(() => {
              this.runChatSearch();
            })
          .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      Button('清除', { type: ButtonType.Normal })
            .fontSize(Typography.caption)
            .height(28)
            .backgroundColor(this.uiColors.bgSurfaceHigh)
            .fontColor(this.uiColors.textSecondary)
            .onClick(() => {
              this.chatQuery = '';
              this.searchRows = [];
            })
        .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
        .width('100%')
        .padding({ left: Spacing.lg, right: Spacing.lg, bottom: Spacing.sm })
      }

      if (!this.ready) {
        EmptyHint(this.busy ? '正在打开酒馆…' : '暂时无法打开酒馆', this.initText, this.uiColors)
        if (!this.busy) {
          Button('重试', { type: ButtonType.Normal }).onClick(() => { this.ensureInitialized(); })
        .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
      } else if (this.chatQuery !== '' && this.searchRows.length > 0) {
        // 搜索结果视图
        Column({ space: Spacing.sm }) {
          ForEach(this.searchRows, (hit: ChatSearchResult) => {
            Column() {
              Column({ space: Spacing.xs }) {
                Text(hit.character_name)
                  .fontSize(Typography.subtitle)
                  .fontColor(this.uiColors.textPrimary)
                  .maxLines(1)
                Text(hit.preview_message ?? hit.last_message ?? hit.file_name)
                  .fontSize(Typography.caption)
                  .fontColor(this.uiColors.textSecondary)
                  .maxLines(2)
                Text(hit.file_name)
                  .fontSize(Typography.micro)
                  .fontColor(this.uiColors.textTertiary)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(Spacing.md)
              .backgroundColor(this.uiColors.bgSurface)
              .borderRadius(Radius.md)
              .attributeModifier(new SurfaceStyle(this.uiColors, Radius.md))
            }
            .onClick(() => {
              ChatIntent.request(hit.character_name, hit.file_name);
              ROOT_PATH_STACK.pushPathByName('pages/ChatPage', null);
            })
          }, (hit: ChatSearchResult) => `${hit.character_name}|${hit.file_name}|${hit.preview_message ?? ''}`)
        }
        .width('100%')
        .padding({ left: Spacing.lg, right: Spacing.lg })
      } else if (this.chatQuery !== '') {
        EmptyHint('没有命中', '换个关键词，或点「清除」回到全部会话', this.uiColors)
      } else if (this.chatRows.length === 0) {
        EmptyHint('故事还未开始', '选一个喜欢的角色，说出第一句话。', this.uiColors)
      } else {
        Column({ space: Spacing.sm }) {
          ForEach(this.chatRows, (row: ChatHomeRow, index: number) => {
            Column() {
              Row({ space: Spacing.md }) {
                IdentityAvatar({ name: row.characterName })
                Column({ space: Spacing.xs }) {
                  Row({ space: Spacing.sm }) {
                    Text(row.characterName)
                      .fontSize(Typography.subtitle)
                      .fontColor(this.uiColors.textPrimary)
                      .layoutWeight(1)
                      .maxLines(1)
                    Text(`${row.count} 条`)
                      .fontSize(Typography.micro)
                      .fontColor(this.uiColors.textTertiary)
                  }
                  .width('100%')

                  Text(row.preview)
                    .fontSize(Typography.caption)
                    .fontColor(this.uiColors.textSecondary)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')

                  Text(row.fileName)
                    .fontSize(Typography.micro)
                    .fontColor(this.uiColors.textTertiary)
                    .maxLines(1)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Button() {
                  Image($r('app.media.icon_more')).width(20).height(20).colorFilter(iconTint(this.uiColors.textSecondary))
                }
                  .width(44)
                  .height(44)
                  .accessibilityText('会话操作')
                  .id('conversation-options-' + row.characterName + '/' + row.fileName)
                  .backgroundColor(Color.Transparent)
                  .fontColor(this.uiColors.textSecondary)
                  .onClick(() => {
                    this.openChatAction(row.characterName, row.fileName, 'menu');
                  })
              }
              .width('100%')
              .padding(Spacing.md)
              .backgroundColor(this.uiColors.bgSurface)
              .borderRadius(Radius.md)
              .attributeModifier(new SurfaceStyle(this.uiColors, Radius.md))
              // 按下立即反馈（stateStyles 是同步改属性，不等抬手）；松手用弹簧回落
              .stateStyles({ normal: cardPressNormal, pressed: cardPressPressed })
              .animation(this.reduceMotion ? { duration: 0 } : { curve: Spring.press() })
              // 入场：弹簧 + 按 index 错开（列表项多时最后一项最多等 Stagger.maxItems 步）
              .transition(staggeredEntrance(8, index))
            }
            .onClick(() => {
              ChatIntent.request(row.characterName, row.fileName);
              ROOT_PATH_STACK.pushPathByName('pages/ChatPage', null);
            })
          }, (row: ChatHomeRow) => `${row.characterName}|${row.fileName}`)
        }
        .width('100%')
        .padding({ left: Spacing.lg, right: Spacing.lg })
      }

      ErrorBannerView({ text: this.listError })
    }
    .width('100%')
    }

  @Builder
  characterTabSurfaceContent() {
      Column({ space: 16 }) {
      
      Row({ space: 10 }) {
        Text('遇见另一种可能')
          .fontSize(17)
          .fontColor(this.uiColors.textSecondary)
          .layoutWeight(1)
        Button('管理角色', { type: ButtonType.Normal })
          .height(44)
          .fontSize(13)
          .backgroundColor(this.uiColors.accentContainer)
          .fontColor(this.uiColors.accent)
          .onClick(() => { ROOT_PATH_STACK.pushPathByName('pages/CharactersPage', null); })
        .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      HeaderAction({ label: '刷新', marker: 'index-refresh-1', available: true,
          onAction: async (): Promise<void> => { await this.reloadHome(); } })
      }
      .padding({ left: Spacing.lg, right: Spacing.lg })
      .width('100%')

      if (!this.ready) {
        EmptyHint('正在打开角色书架', this.initText, this.uiColors)
      } else if (this.charRows.length === 0) {
        EmptyHint('留一个位置给新朋友', '在「管理角色」中新建，或到「资料库」导入角色卡。', this.uiColors)
      } else {
        Grid() {
          ForEach(this.charRows, (character: CharacterDto) => {
            GridItem() {
              Column({ space: 14 }) {
                IdentityAvatar({ name: character.name, diameter: 72 })
                Text(character.name)
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.uiColors.textPrimary)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(character.first_mes || '等待你开启第一段故事')
                  .fontSize(13)
                  .lineHeight(21)
                  .fontColor(this.uiColors.textSecondary)
                  .maxLines(3)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
                Button('开始聊天', { type: ButtonType.Normal })
                  .width('100%')
                  .height(44)
                  .fontSize(14)
                  .backgroundColor(this.uiColors.accentContainer)
                  .fontColor(this.uiColors.accent)
                  .enabled(!this.busy)
                  .onClick(() => { this.startChatWith(character); })
              .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      }
              .width('100%')
              .height(282)
              .padding(20)
              .alignItems(HorizontalAlign.Start)
              .backgroundColor(this.uiColors.bgSurface)
              .borderRadius(28)
              .attributeModifier(new SurfaceStyle(this.uiColors, 28))
              .border({ width: 1, color: this.uiColors.borderSubtle })
            }
          }, (character: CharacterDto) => character.avatar || character.name)
        }
        .columnsTemplate(this.winWidthVp >= 1100 ? '1fr 1fr 1fr' : (this.winWidthVp >= 380 ? '1fr 1fr' : '1fr'))
        .columnsGap(12)
        .rowsGap(12)
        .padding({ left: Spacing.lg, right: Spacing.lg })
        .height(Math.ceil(this.charRows.length / (this.winWidthVp >= 1100 ? 3 : (this.winWidthVp >= 380 ? 2 : 1))) * 294 - 12)
        .enableScrollInteraction(false)
        .width('100%')
      }
      ErrorBannerView({ text: this.listError })
    }
    .width('100%')
    }

  @Builder
  moreTabSurfaceContent() {
      Column() {
      Column({ space: Spacing.sm }) {
        

        Search({ placeholder: '搜索设置、模型与创作工具', value: this.spaceQuery })
          .height(48).fontColor(this.uiColors.textPrimary)
          .placeholderColor(this.uiColors.textSecondary).backgroundColor(this.uiColors.headerButtonTint)
          .border({ width: 0.8, color: this.uiColors.glassEdge }).borderRadius(24)
          .margin({ left: 16, right: 16, bottom: 8 }).id('settings-search')
          .onChange((value: string): void => { this.spaceQuery = value; })
          .onSubmit((): void => { this.getUIContext().getFocusController().clearFocus(); })
        if (this.spaceQuery.trim() === '') { this.settingsOverview() }
        ForEach(SETTINGS_GROUPS, (group: string) => {
          if (this.spaceEntries(group).length > 0) {
            Column({ space: 10 }) {
              Text(group).fontSize(13).fontWeight(FontWeight.Medium)
                .fontColor(this.uiColors.textSecondary).width('100%').padding({ left: 8 })
              Column({ space: 0 }) {
                ForEach(this.spaceEntries(group), (entry: MoreEntry, index: number) => {
                  SettingsEntryRow({ label: entry.label, detail: entry.hint, icon: this.settingsIcon(entry.route),
                    marker: 'settings-entry-' + entry.route.substring(6), last: index === this.spaceEntries(group).length - 1,
                    onOpen: (): void => { this.openSettingsRoute(entry.route); } })
                }, (entry: MoreEntry) => entry.route)
              }.width('100%').backgroundColor(this.uiColors.bgSurface).borderRadius(26)
                .border({ width: 0.8, color: this.uiColors.borderSubtle }).clip(true)
            }.width('100%').padding({ left: 16, right: 16 }).margin({ top: 14, bottom: 6 })
          }
        }, (group: string) => group)
        if (MORE_ENTRIES.filter((entry: MoreEntry) =>
          (entry.label + entry.hint + entry.group).toLowerCase().includes(this.spaceQuery.trim().toLowerCase())).length === 0) {
          EmptyHint('暂时没有找到', '试试「外观」「模型」「备份」或「人设」。', this.uiColors)
        }

        ErrorBannerView({ text: this.listError })
        ErrorBannerView({ text: this.errorText })


        Text('HarmonyTavern · 让故事自由生长')
          .fontSize(Typography.micro)
          .fontColor(this.uiColors.textTertiary)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: Spacing.lg, bottom: Spacing.lg })
      }
      .width('100%')
    }
    .width('100%')
    }

  @Builder
  homeTabContent() {
    Tabs({ barPosition: BarPosition.End, index: this.displayedTab }) {
      TabContent() { this.chatTab() }
      TabContent() { this.characterTab() }
      TabContent() { AdminPage({
        embedded: true, showHeader: false,
        contentBottom: this.winWidthVp >= 840 ? 24 : this.bottomBarVp + 84
      }) }
      TabContent() { this.moreTab() }
    }
    .id('home-tab-content')
    .barHeight(0)
    .animationDuration(0)
    .scrollable(false)
    .width('100%').height('100%')
    .backgroundColor(this.uiColors.bgBase)
    .gesture(SwipeGesture({ direction: SwipeDirection.Horizontal }).onAction((event: GestureEvent): void => {
      const direction: number = Math.abs(event.angle) > 90 ? 1 : -1;
      this.currentTab = Math.max(0, Math.min(TAB_ITEMS.length - 1, this.currentTab + direction));
    }))
  }

  build() {
    WithTheme({ theme: Appearance.theme(this.backgroundId) }) {
      Stack({ alignContent: Alignment.Bottom }) {
        Navigation(ROOT_PATH_STACK) {
          Stack() {
            this.ambientLayer()
            Row() {
              if (this.winWidthVp >= 840) {
                JellyTabBar({
                  items: this.jellyItems, currentIndex: this.currentTab,
                  containerWidthVp: this.winWidthVp, rail: true,
                  onSelect: (index: number): void => { this.currentTab = index; }
                })
              }
              Column() {
                SwingContent({ activeIndex: this.currentTab, fillHeight: true,
                  onDisplay: (index: number): void => { this.displayedTab = index; },
                  content: (): void => { this.homeTabContent(); } })
              }
              .layoutWeight(1).height('100%').backgroundColor(this.uiColors.bgBase)
            }
            .width('100%')
            .height('100%')
          }
          .width('100%')
          .height('100%')
          .backgroundColor(this.uiColors.bgBase)
        }
        .navDestination(this.pageMap)
        .customNavContentTransition((from: NavContentInfo, to: NavContentInfo, operation: NavigationOperation) => {
          return this.dockTransition(from, to, operation);
        })
        .mode(NavigationMode.Stack)
        .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
        .hideTitleBar(true)
        .onNavBarStateChange((visible: boolean): void => { if (visible && this.ready) { this.reloadHome(); } })
        .width('100%')
        .height('100%')
        .backgroundColor(this.uiColors.bgBase)
        this.floatingDock()
        Column().width(0).height(0)
          .bindContentCover($$this.onboardingPresented, this.onboardingCover(), {
            modalTransition: ModalTransition.NONE, backgroundColor: Color.Transparent,
            onWillDismiss: (): void => { this.finishOnboarding(); }
          })
        Column().width(0).height(0)
          .bindContentCover($$this.homeCreatePanel.presented, this.homeCreateCover(), {
            modalTransition: ModalTransition.NONE, backgroundColor: Color.Transparent,
            onWillDismiss: (): void => { this.homeCreatePanel.close(); },
            onDisappear: (): void => { this.homeCreatePanel.dismissed(); this.dockInteractionChanged(false); }
          })
        if (this.dockMode === 'home' && this.currentTab === 0 && ROOT_PATH_STACK.size() === 0) {
          Row() {
            if (this.dockActionOnRight) { Blank() }
            HeaderAction({ icon: $r('app.media.icon_add'), label: '创建聊天', marker: 'chat-home-grip-add', refresh: false,
              available: this.ready && !this.busy,
              onAction: async (): Promise<void> => { this.dockInteractionChanged(true); this.openHomeCreate('chat-home-grip-add'); } })
            if (!this.dockActionOnRight) { Blank() }
          }.width('100%').height(44).padding({ left: 20, right: 20 })
            .margin({ bottom: this.bottomBarVp + 84 }).hitTestBehavior(HitTestMode.Transparent)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.uiColors.bgBase)
      .clip(true)
      .onAreaChange((_previous: Area, current: Area) => {
        this.winWidthVp = Number(current.width);
        AppStorage.setOrCreate('appWindowWidth', this.winWidthVp);
        AppStorage.setOrCreate('appViewportBottom', Number(current.globalPosition.y) + Number(current.height));
      })
      .onAppear(() => {
        this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
        this.holdingHandChanged();
      })
      .bindContentCover($$this.actionPanel.presented, this.chatActionCover(), {
        modalTransition: ModalTransition.NONE, backgroundColor: Color.Transparent,
        onWillDismiss: (_action: DismissContentCoverAction): void => { this.actionPanel.close(); },
        onDisappear: (): void => { this.actionPanel.dismissed(); }
      })
    }
  }

  @Builder
  ambientLayer() {
    Column()
      .width('100%')
      .height('100%')
      .linearGradient({
        angle: 155,
        colors: [[this.uiColors.bgBase, 0], [this.uiColors.bgBase, 1]]
      })
      .hitTestBehavior(HitTestMode.None)
      .accessibilityLevel('no')
  }

  private finishOnboarding(): void {
    OnboardingState.complete();
    this.onboardingPresented = false;
  }

  @Builder
  onboardingCover() {
    OnboardingGuide({ onFinish: (): void => { this.finishOnboarding(); } })
  }

  @Builder
  welcomeCard() {
    Row({ space: 16 }) {
      Column({ space: 10 }) {
        Text('故事，从一句话开始')
          .fontSize(23)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.uiColors.textPrimary)
        Text('遇见角色，续写只属于你的世界。')
          .fontSize(Typography.caption)
          .fontColor(this.uiColors.textSecondary)
        Button('开启新故事  ↗', { type: ButtonType.Normal })
          .fontSize(14)
          .height(44)
          .backgroundColor(this.uiColors.accent)
          .fontColor(this.uiColors.textInverse)
          .onClick(() => { this.currentTab = 1; })
      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Image($r('app.media.icon_spark'))
        .width(56)
        .height(56)
        .colorFilter(iconTint(this.uiColors.accent))
        .rotate({ angle: -12 })
        .accessibilityLevel('no')
    }
    .width('100%')
    .padding(22)
    .linearGradient({
      angle: 120,
      colors: [[this.uiColors.accentContainer, 0], [this.uiColors.bgSurfaceHigh, 1]]
    })
    .borderRadius(28)
    .border({ width: 1, color: this.uiColors.glassEdge })
    .margin({ bottom: 20 })
  }

  /** 聊天 Tab：会话列表 + 内容搜索 + 行级操作（重命名 / 备份 / 删除）。 */
  @Builder
  chatTabTopBar() {
    PageHeader({ title: '聊天', subtitle: `${this.chatRows.length} 段对话 · ${this.groupRows.length} 个群聊`, showBack: false }) {
      HeaderAction({ label: '刷新聊天', marker: 'chat-home-refresh', pending: this.refreshingChats,
        available: this.ready && !this.busy, onAction: async (): Promise<void> => { await this.refreshChatHome(); } })
      HeaderAction({ icon: $r('app.media.icon_add'), label: '创建聊天', marker: 'chat-home-header-add', refresh: false,
        available: this.ready && !this.busy,
        onAction: async (): Promise<void> => { this.openHomeCreate('chat-home-header-add'); } })
    }
  }

  @Builder
  chatTab() {
    PageSurface({ topBar: () => { this.chatTabTopBar(); }, horizontalInset: 0,
      bottomInset: this.winWidthVp >= 840 ? 24 : this.bottomBarVp + 84, content: () => { this.chatTabSurfaceContent(); } })
  }

  @Builder
  chatActionPanel() {
    Column({ space: Spacing.md }) {
      if (this.actionMode === 'rename') {
        TextInput({ text: this.renameText, placeholder: '新会话文件名（不含扩展名）' })
          .fontSize(Typography.body)
          .width('100%')
          .onChange((value: string) => { this.renameText = value; })
          .attributeModifier(new InputFieldStyle(this.uiColors))
        Button('确定重命名', { type: ButtonType.Normal })
          .width('100%')
          .enabled(!this.busy)
          .onClick(() => { this.renameChatRow(); })
          .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      } else if (this.actionMode === 'delete') {
        Text('删除后不可恢复，可先备份。确认删除这段会话？')
          .fontSize(Typography.caption)
          .lineHeight(22)
          .fontColor(this.uiColors.textSecondary)
          .width('100%')
        Button('确认删除', { type: ButtonType.Normal })
          .width('100%')
          .enabled(!this.busy)
          .onClick(() => { this.deleteChatRow(); })
          .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Danger))
      }
    }
    .width('100%')
    .padding(Spacing.md)
  }
  /** 角色 Tab：角色列表 + 一键新建会话 + 角色管理入口。 */
  @Builder
  characterTabTopBar() {
    this.tabHeader('角色', `${this.charRows.length} 位灵感伙伴`)
  }

  @Builder
  characterTab() {
    PageSurface({ topBar: () => { this.characterTabTopBar(); }, horizontalInset: 0,
      bottomInset: this.winWidthVp >= 840 ? 24 : this.bottomBarVp + 84, content: () => { this.characterTabSurfaceContent(); } })
  }

  @Builder
  moreTabTopBar() {
    PageHeader({ title: '设置', subtitle: '让酒馆成为你的样子', showBack: false,
      actions: (): void => { this.settingsHeaderActions(); } })
  }

  @Builder
  moreTab() {
    PageSurface({ topBar: () => { this.moreTabTopBar(); }, horizontalInset: 0,
      bottomInset: this.winWidthVp >= 840 ? 24 : this.bottomBarVp + 84, content: () => { this.moreTabSurfaceContent(); } })
  }

  private spaceEntries(group: string): MoreEntry[] {
    const query: string = this.spaceQuery.trim().toLowerCase();
    return MORE_ENTRIES.filter((entry: MoreEntry) =>
      entry.group === group && (entry.label + entry.hint + entry.group).toLowerCase().includes(query));
  }

  private openSettingsRoute(route: string): void {
    this.getUIContext().getFocusController().clearFocus();
    ROOT_PATH_STACK.pushPathByName(route, null);
  }

  private settingsIcon(route: string): Resource {
    if (route === 'pages/AppearancePage') { return $r('app.media.icon_appearance'); }
    if (route === 'pages/TauriSettingsPage') { return $r('app.media.icon_preferences'); }
    if (route === 'pages/UserPage') { return $r('app.media.icon_identity'); }
    if (route === 'pages/PresetsPage') { return $r('app.media.icon_presets'); }
    if (route === 'pages/SettingsPage') { return $r('app.media.icon_generation'); }
    if (route === 'pages/SecretsPage') { return $r('app.media.icon_key'); }
    if (route === 'pages/UsageStatisticsPage') { return $r('app.media.icon_status'); }
    if (route === 'pages/ModelInfoPage') { return $r('app.media.icon_model'); }
    if (route === 'pages/AuxiliaryModelsPage') { return $r('app.media.icon_assistant'); }
    if (route === 'pages/HelpPage') { return $r('app.media.icon_help'); }
    if (route === 'pages/AboutPage') { return $r('app.media.icon_info'); }
    if (route === 'pages/FeedbackPage') { return $r('app.media.icon_feedback'); }
    if (route === 'pages/SponsorPage') { return $r('app.media.icon_heart'); }
    if (route === 'pages/BackupPage') { return $r('app.media.icon_backup'); }
    if (route === 'pages/SyncPage') { return $r('app.media.icon_sync'); }
    if (route === 'pages/AssetsPage') { return $r('app.media.icon_assets'); }
    if (route === 'pages/DataPage') { return $r('app.media.icon_data'); }
    if (route === 'pages/ChatStorePage') { return $r('app.media.icon_history'); }
    if (route === 'pages/ProviderPage') { return $r('app.media.icon_cloud'); }
    if (route === 'pages/SkillsPage') { return $r('app.media.icon_skills'); }
    if (route === 'pages/ExtensionPage') { return $r('app.media.icon_extension'); }
    if (route === 'pages/McpPage') { return $r('app.media.icon_mcp'); }
    if (route === 'pages/ToolsPage') { return $r('app.media.icon_tools'); }
    if (route === 'pages/AgentPage') { return $r('app.media.icon_agent'); }
    return $r('app.media.icon_settings');
  }

  @Builder
  settingsHeaderActions() {
    HeaderAction({ label: '刷新设置概览', marker: 'settings-refresh', available: this.ready && !this.busy,
      onAction: async (): Promise<void> => { await this.reloadHome(); } })
  }

  @Builder
  settingsOverview() {
    Column() {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 20 }) {
        Row({ space: 12 }) {
          Text('HARMONY TAVERN').fontSize(10).letterSpacing(2).fontWeight(FontWeight.Medium)
            .fontColor(this.uiColors.accent).layoutWeight(1)
          Image($r('app.media.icon_cloud')).width(22).height(22).colorFilter(iconTint(this.uiColors.accent))
        }.width('100%')
        Column({ space: 7 }) {
          Text('服务商管理').fontSize(26).fontWeight(FontWeight.Bold).fontColor(this.uiColors.textPrimary)
          Text('连接 AI 服务，为故事选择合适的模型').fontSize(13).fontColor(this.uiColors.textSecondary)
        }.width('100%').alignItems(HorizontalAlign.Start)
        Row({ space: 18 }) {
          Text('端点 · 密钥 · 模型').fontSize(12).fontColor(this.uiColors.accent)
          Blank()
          Text('管理连接').fontSize(12).fontColor(this.uiColors.textPrimary)
          Image($r('app.media.icon_chevron')).width(13).height(13).colorFilter(iconTint(this.uiColors.textSecondary))
        }.width('100%')
      }.width('100%').padding(22).alignItems(HorizontalAlign.Start)
    }.width('100%').height('auto').padding(0).backgroundColor(this.uiColors.bgSurface)
      .linearGradient({ angle: 135, colors: [[this.uiColors.accentContainer, 0], [this.uiColors.bgSurface, 1]] })
      .border({ radius: 28, width: 0.8, color: this.uiColors.glassEdge }).borderRadius(28).clip(true)
      .stateStyles({ normal: cardPressNormal, pressed: cardPressPressed })
      .accessibilityText('服务商管理，配置 AI 服务端点、密钥与模型').id('settings-overview')
      .onClick((): void => { this.openSettingsRoute('pages/ProviderPage'); })
    }.width('100%').padding({ left: 16, right: 16, top: 4, bottom: 8 })
  }

  @Builder
  tabHeader(title: string, trailing: string) {
    PageHeader({ title: title, subtitle: trailing, showBack: false })
  }

  /** 两列网格里的功能入口（更多 Tab 用）。 */
  @Builder
  gridEntry(label: string, route: string, index: number) {
    // 外观 + 按压都由 GridEntryCard 负责：带 @BuilderParam 的组件在尾随 {} 之后
    // 不能再链属性（会报 Declaration or statement expected），所以做成专用组件。
    GridEntryCard({
      label: label,
      onTap: () => {

        ROOT_PATH_STACK.pushPathByName(route, null);
      }
    })
      // 入场：淡入 + 上移 + 微放大，按 index 错开
      .transition(staggeredEntrance(Distance.enterOffset, index))
  }

  /** 功能入口行。 */
  @Builder
  entryRow(label: string, route: string) {    Row({ space: Spacing.sm }) {
      Text(label)
        .fontSize(Typography.body)
        .fontColor(this.uiColors.textPrimary)
        .layoutWeight(1)
      Image($r('app.media.icon_chevron'))
        .width(18).height(18)
        .colorFilter(iconTint(this.uiColors.textTertiary))
    }
    .width('100%')
    .height(Touch.rowHeight)
    .padding({ left: Spacing.lg, right: Spacing.lg })
    .backgroundColor(this.uiColors.bgSurface)
    .borderRadius(Radius.md)
    .attributeModifier(new SurfaceStyle(this.uiColors, Radius.md))
    .margin({ left: Spacing.lg, right: Spacing.lg })
    .onClick(() => {
      ROOT_PATH_STACK.pushPathByName(route, null);
    })
  }

  /** 路由表（NavDestination）。 */
  @Builder
  pageMap(name: string) {
    if (name === 'pages/ChatPage') {
      NavDestination() {
        Column() {
          PageFrame() { ChatPage({ dock: this.dock, bottomInset: this.dockHeight + this.bottomBarVp + 24 }) }
        }
        .width('100%')
        .height('100%')
      }
      .hideTitleBar(true)
      .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
      .backgroundColor(this.uiColors.bgBase)
      .onBackPressed((): boolean => { return this.dock.preventBack; })
      .translate({ x: this.reduceMotion ? 0 : (1 - this.chatReveal) * this.winWidthVp })
    } else if (name === 'pages/HelpPage' || name === 'pages/FeedbackPage' || name === 'pages/AboutPage' || name === 'pages/SponsorPage') {
      NavDestination() {
        PageFrame() { HelpAboutPage({ section: name === 'pages/FeedbackPage' ? 'feedback' :
          name === 'pages/AboutPage' ? 'about' : name === 'pages/SponsorPage' ? 'sponsor' : 'help' }) }
      }
      .hideTitleBar(true)
      .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
      .backgroundColor(this.uiColors.bgBase)
    } else if (name === 'pages/AuxiliaryModelsPage') {
      NavDestination() {
        PageFrame() { AuxiliaryModelsPage() }
      }
      .hideTitleBar(true)
      .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
      .backgroundColor(this.uiColors.bgBase)
    } else if (name === 'pages/ProviderPage') {
      NavDestination() {
        PageFrame() { SettingsPage({ providerOnly: true }) }
      }
      .hideTitleBar(true)
      .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
      .backgroundColor(this.uiColors.bgBase)
    } else if (name === 'pages/AppearancePage') {
      NavDestination() {
        PageFrame() { AppearancePage() }
      }
      .hideTitleBar(true)
      .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
      .backgroundColor(this.uiColors.bgBase)
    } else if (name === 'pages/SettingsPage') {
      NavDestination() {
        PageFrame() { SettingsPage() }
      }
      .hideTitleBar(true)
      .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
      .backgroundColor(this.uiColors.bgBase)
    } else if (name === 'pages/ExtensionPage') {
      NavDestination() {
        PageFrame() { ExtensionPage() }
      }
      .hideTitleBar(true)
      .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
      .backgroundColor(this.uiColors.bgBase)
    } else if (name === 'pages/ChatStorePage') {
      NavDestination() {
        PageFrame() { ChatStorePage() }
      }
      .hideTitleBar(true)
      .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
      .backgroundColor(this.uiColors.bgBase)
    } else if (name === 'pages/UsageStatisticsPage') {
      NavDestination() { PageFrame() { UsageStatisticsPage() } }
        .hideTitleBar(true)
        .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
        .backgroundColor(this.uiColors.bgBase)
    } else if (name === 'pages/ModelInfoPage') {
      NavDestination() {
        PageFrame() { ModelInfoPage() }
      }
      .hideTitleBar(true)
      .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
      .backgroundColor(this.uiColors.bgBase)


    } else if (name === 'pages/AdminPage') {
      NavDestination() {
        PageFrame() { AdminPage() }
      }
      .hideTitleBar(true)
      .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
      .backgroundColor(this.uiColors.bgBase)
    } else if (name === 'pages/WorldImportPage') {
      NavDestination() {
        PageFrame() { WorldImportPage() }
      }
      .hideTitleBar(true)
      .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
      .backgroundColor(this.uiColors.bgBase)
    } else if (name === 'pages/ChatImportPage') {
      NavDestination() {
        PageFrame() { ChatImportPage() }
      }
      .hideTitleBar(true)
      .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
      .backgroundColor(this.uiColors.bgBase)
    } else if (name === 'pages/StoryPage') {
      NavDestination() { PageFrame() { StoryPage() } }.hideTitleBar(true)
        .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
        .backgroundColor(this.uiColors.bgBase)
        .onBackPressed((): boolean => { return AppStorage.get<boolean>('storySaving') ?? false; })
    } else if (name === 'pages/GroupChatPage') {
      NavDestination() { GroupChatPage() }.hideTitleBar(true)
    } else if (name === 'pages/GroupPage') {
      NavDestination() {
        PageFrame() { GroupPage() }
      }
      .hideTitleBar(true)
      .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
      .backgroundColor(this.uiColors.bgBase)
    } else if (name === 'pages/WorldInfoPage') {
      NavDestination() {
        PageFrame() { WorldInfoPage() }
      }
      .hideTitleBar(true)
      .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
      .backgroundColor(this.uiColors.bgBase)
    } else if (name === 'pages/AssetsPage') {
      NavDestination() {
        PageFrame() { AssetsPage() }
      }
      .hideTitleBar(true)
      .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
      .backgroundColor(this.uiColors.bgBase)
    } else if (name === 'pages/ToolsPage') {
      NavDestination() {
        PageFrame() { ToolsPage() }
      }
      .hideTitleBar(true)
      .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
      .backgroundColor(this.uiColors.bgBase)
    } else if (name === 'pages/SettingsJsonPage') {
      NavDestination() {
        PageFrame() { SettingsJsonPage() }
      }
      .hideTitleBar(true)
      .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
      .backgroundColor(this.uiColors.bgBase)
    } else if (name === 'pages/DataPage') {
      NavDestination() {
        PageFrame() { DataPage() }
      }
      .hideTitleBar(true)
      .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
      .backgroundColor(this.uiColors.bgBase)
    } else if (name === 'pages/BackupPage') {
      NavDestination() {
        PageFrame() { BackupPage() }
      }
      .hideTitleBar(true)
      .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
      .backgroundColor(this.uiColors.bgBase)
    } else if (name === 'pages/UserPage') {
      NavDestination() {
        PageFrame() { UserPage() }
      }
      .hideTitleBar(true)
      .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
      .backgroundColor(this.uiColors.bgBase)
    } else if (name === 'pages/SecretsPage') {
      NavDestination() {
        PageFrame() { SecretsPage() }
      }
      .hideTitleBar(true)
      .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
      .backgroundColor(this.uiColors.bgBase)
    } else if (name === 'pages/PresetsPage') {
      NavDestination() {
        PageFrame() { PresetsPage() }
      }
      .hideTitleBar(true)
      .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
      .backgroundColor(this.uiColors.bgBase)
    } else if (name === 'pages/SyncPage') {
      NavDestination() {
        PageFrame() { SyncPage() }
      }
      .hideTitleBar(true)
      .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
      .backgroundColor(this.uiColors.bgBase)
    } else if (name === 'pages/AgentPage') {
      NavDestination() {
        PageFrame() { AgentPage() }
      }
      .hideTitleBar(true)
      .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
      .backgroundColor(this.uiColors.bgBase)
    } else if (name === 'pages/SkillsPage') {
      NavDestination() {
        PageFrame() { SkillsPage() }
      }
      .hideTitleBar(true)
      .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
      .backgroundColor(this.uiColors.bgBase)
    } else if (name === 'pages/McpPage') {
      NavDestination() {
        PageFrame() { McpPage() }
      }
      .hideTitleBar(true)
      .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
      .backgroundColor(this.uiColors.bgBase)
    } else if (name === 'pages/TauriSettingsPage') {
      NavDestination() {
        PageFrame() { TauriSettingsPage() }
      }
      .hideTitleBar(true)
      .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
      .backgroundColor(this.uiColors.bgBase)
    } else if (name === 'pages/CharactersPage') {
      NavDestination() {
        PageFrame() { CharactersPage() }
      }
      .hideTitleBar(true)
      .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
      .backgroundColor(this.uiColors.bgBase)
    }
  }
}
