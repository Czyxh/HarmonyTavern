import { RpgBubbleStyle, RpgConversationStyle } from '../theme/RpgBubbleStyle';
import { Appearance, BACKGROUND_DEFAULT, BACKGROUND_KEY } from '../theme/Appearance';
import { SurfaceStyle } from '../theme/SurfaceStyles';
import { SystemGlass } from '../theme/SystemGlass';
import { ActionButtonStyle, ActionTone, InputFieldStyle, TextAreaFieldStyle } from '../theme/ControlStyles';
import { SettingsPage } from './SettingsPage';
import { NativeSettings, NativePreferences, NativePreferencesSnapshot, defaultNativePreferences } from '../backend/NativePreferences';
import { NativeContext, ContextStatus, ContextPlan } from '../backend/NativeContext';
import { ChatMessageSource, ChatMessageRow } from '../components/ChatMessageSource';
import { iconTint } from '../theme/IconTint';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { PROVIDERS, ProviderEntry, ProviderConfig, ProviderPreferences, ProviderSecretState } from '../backend/ProviderCatalog';
import { IdentityAvatar } from '../components/IdentityAvatar';
import { SCROLL_EDGE_OPTIONS, SCROLL_NESTED_OPTIONS } from '../theme/ScrollFeedback';
import { ChatPanel } from '../components/ChatPanel';
import { OriginPanel } from '../components/OriginPanel';
import { OriginMotion, OriginPanelState } from '../theme/OriginMotion';
import { LiquidMenuItem } from '../components/LiquidMenuItem';
import { GLASS_HEADER, GLASS_MENU, glassEffect } from '../theme/Glass';
import { ChatDockState } from '../components/ChatDock';
import { LS_BLUR_DEFAULT, LS_BLUR_KEY } from '../theme/LightSense';
import { IMMERSIVE_DEFAULT, IMMERSIVE_KEY } from '../theme/Immersive';
// P5 聊天页 + P7 步骤 3 增强（重试 / 摘要）。
//
// 覆盖的链路（全部走 P5 Rust 侧已落地的 116 条命令 + P7 新包装的摘要命令）：
//   1. 聊天列表：get_all_chats → 点开 → get_chat 渲染历史消息；
//   2. 发送：add_message 持久化 → start_chat_completion_stream（游标契约）→
//      轮询 read_chat_completion_stream_decoded 追加文本 → Done 后把助手消息 add_message 回聊天；
//   3. 端点授权三步握手第 ② 步：命令返回 unauthorized + "endpoint_authorization_required|<端点>"
//      时，ArkTS 弹 AlertDialog（文案照搬上游 user_endpoint_access.rs 的 zh-CN 拷贝，
//      含 http:// 明文额外警告），用户同意后调 grant_user_endpoint_access 再重试。
//   4. 重试（swipe-lite）：不重复落库用户消息，用现有上下文重新生成，追加一条新助手回复；
//   5. 摘要：打开聊天时 get_character_chat_summary 读取（preview 即摘要文本），「摘要」按钮切换显示。
//
// 本页是「能跑起来的第一版」，故意不做的：系统提示词装配、多角色/多模态、滑动、总结 ——
// 这些是后续阶段的内容，不在本页堆假逻辑。
//
// 对应 DevEco 工程路径：entry/src/main/ets/pages/ChatPage.ets
import { hilog } from '@kit.PerformanceAnalysisKit';
import { FrameCallback } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { Backend, BackendError } from '../backend/Backend';
import { AuxiliaryModels } from '../backend/AuxiliaryModels';
import { BrandIcon } from '../components/BrandIcon';
import { RpgBackdrop } from '../components/RpgBackdrop';
import { RpgThemes } from '../theme/RpgThemes';
import { SettingsPicker } from '../components/SettingsPicker';
import { WorldModelPicker } from '../components/WorldModelPicker';
import { WorldJournalSidebar } from '../components/WorldJournalSidebar';
import { WorldJournalDock } from '../components/WorldJournalDock';
import { HOLDING_HAND_KEY, HOLDING_HAND_UNKNOWN, HOLDING_ENABLED_KEY, HOLDING_ACTION_KEY, HoldingPose } from '../theme/HoldingPose';
import { ChatFileOps } from '../backend/ChatFileOps';
import { ChatIntent, StoryIntent, ROOT_PATH_STACK } from '../nav/RootNav';
import { NativeStory, StorySettings, StoryReply, StoryOption, StoryChoices, defaultStorySettings, storyChoicesEnabled } from '../backend/NativeStory';
import { StreamingText } from '../components/StreamingText';
import { ReadingPreferences, READING_SIZE_KEY, READING_LINE_KEY, READING_FONT_KEY, READING_INSET_KEY } from '../theme/ReadingPreferences';
import { NativeWorld, WorldStateReport, WorldStatePlan, WorldReplyPlan, WorldItem, worldNeedsInitialization } from '../backend/NativeWorld';
import { WorldStatusHud, WorldStatusDetails, emptyWorldState } from '../components/WorldStatus';
import { PersonalizationStore, CHAT_TOKEN_USAGE_KEY, CHAT_REASONING_KEY } from '../theme/PersonalizationStore';
import { HeaderAction } from '../components/HeaderAction';
import { Radius, Typography } from '../theme/Tokens';
import { ErrorBannerView, EmptyHint } from '../components/Builders';
import { MOTION_REDUCE_KEY } from '../theme/Motion';
import {
  CharacterDto,
  ChatCompletionStreamReadResultDecodedDto,
  ChatDto,
  ChatMessageDto,
  ChatSearchResultDto,
  DecodedPart,
  GenerateRequestDto,
  RuntimePathsDto,
  TokenUsage
} from '../backend/Types';

const DOMAIN: number = 0x0002;
const TAG: string = 'HarmonyTavern';

/** 端点授权提示的前缀（与 Rust 侧 chat_completion.rs 的常量一致）。 */
const ENDPOINT_AUTH_REQUIRED_PREFIX: string = 'endpoint_authorization_required|';

/** 轮询间隔（毫秒）。上游流是游标契约，这个节奏对国产 provider 足够。 */
const POLL_INTERVAL_MS: number = 80;

interface ChatListItem {
  characterName: string;
  fileName: string;
  preview: string;
  messageCount: number;
}

class ChatLayoutFrame extends FrameCallback {
  private action: () => void;

  constructor(action: () => void) {
    super();
    this.action = action;
  }

  onIdle(_timeLeft: number): void { this.action(); }
}

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
export struct ChatPage {
  @StorageProp(READING_SIZE_KEY) readingSize: number = 15;
  @StorageProp(READING_LINE_KEY) readingLine: number = 1.5;
  @StorageProp(READING_FONT_KEY) readingFont: string = 'system';
  @StorageProp(READING_INSET_KEY) readingInset: number = 8;
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @StorageProp(BACKGROUND_KEY) backgroundId: string = BACKGROUND_DEFAULT;
  @ObjectLink dock: ChatDockState;
  @Prop @Watch('messageViewportChanged') bottomInset: number = 100;
  @StorageProp('systemTopInset') topInset: number = 0;
  @State avatarRoot: string = '';
  @State panel: OriginPanelState = new OriginPanelState();
  @State menuOrigin: OriginPanelState = new OriginPanelState();
  @State activePanel: string = '';
  private modelBackHandler: () => boolean = (): boolean => false;
  @State promptPreview: string = '';
  private editorSourceId: string = '';
  @StorageProp(LS_BLUR_KEY) blurRadius: number = LS_BLUR_DEFAULT;
  @StorageProp(IMMERSIVE_KEY) immersiveLevel: number = IMMERSIVE_DEFAULT;
  @StorageProp(MOTION_REDUCE_KEY) reduceMotion: boolean = false;
  @State messageViewportHeight: number = 600;
  @State chatList: ChatListItem[] = [];
  @State chatListText: string = '加载中…';
  @State @Watch('syncDock') openChat: ChatDto | null = null;
  @State @Watch('messagesChanged') messages: ChatMessageDto[] = [];
  private messageSource: ChatMessageSource = new ChatMessageSource();
  private scrollFramePending: boolean = false;
  @StorageProp(CHAT_REASONING_KEY) showReasoning: boolean = false;
  @State streamReasoning: string = '';
  @State reasoningExpanded: number = -1;
  private reasoningTruncated: boolean = false;
  @State generationDraft: NativePreferences = defaultNativePreferences();
  private generationSnapshot: NativePreferencesSnapshot | undefined = undefined;
  @State generationLoading: boolean = false;
  @State generationSaving: boolean = false;
  @State generationError: string = '';
  @State contextBusy: boolean = false;
  @State contextInfo: ContextStatus | undefined = undefined;
  @State contextError: string = '';
  @State contextApplying: boolean = false;
  private settingsLoadRevision: number = 0;
  private contextRequest: string = '';
  private contextRevision: number = 0;
  @State @Watch('syncDock') inputText: string = '';
  @State model: string = 'deepseek-chat';
  @State source: string = 'deepseek';
  @State providerId: string = 'deepseek';
  @State customUrl: string = '';
  @State statusText: string = '';
  @State errorText: string = '';
  // 流式状态
  @State streamText: string = '';
  @StorageProp(CHAT_TOKEN_USAGE_KEY) showTokenUsage: boolean = false;
  private streamUsage: TokenUsage | undefined = undefined;
  private streamUsageComplete: boolean = false;
  private streamFormat: string = 'openai_compatible';
  @State @Watch('syncDock') streaming: boolean = false;
  // 生成中脉冲点的透明度（1 与 0.25 之间循环）：表达仍在进行，不阻塞交互。
  @State pulseOpacity: number = 1;
  private streamId: string = '';
  private replyModel: string = '';
  private replyRequestKey: string = '';
  private afterSeq: number = 0;
  private pollTimer: number = -1;
  private pollRunning: boolean = false;
  // P7 步骤 3：摘要 + 重试 + 多模态图片
  @State chatSummary: string = '';
  @State @Watch('syncDock') summaryVisible: boolean = false;
  @State @Watch('syncDock') attachedImages: string[] = [];
  private lastUserMes: string = '';
  // P7 步骤 7 修复：真机 0 聊天时「发送」静默无反应（openChat=null 直接 return）。
  // 补角色列表 + create_chat 入口，让用户能在页内建聊天后发送。
  @State characters: CharacterDto[] = [];
  @State charactersText: string = '角色加载中…';
  // P8-18 消息编辑
  @State busy: boolean = false;
  @State @Watch('editSelectionChanged') editIndex: number = -1;
  // P8-25：会话内检索（search_character_chat_messages）
  @State @Watch('syncDock') searchOpen: boolean = false;
  @State searchQuery: string = '';
  @State searchHits: ESObject[] = [];
  @State searchNote: string = '';
  @State focusIndex: number = -1;
  @State editText: string = '';
  /** 新建聊天时的 ST user_name（SillyTavern 默认 User；persona 装配不在本阶段）。 */
  @State userName: string = 'User';
  /** 消息区滚动控制器：新消息/流式追加后自动滚到底（否则回复落在屏幕外像「没反应」）。 */
  private msgScroller: Scroller = new Scroller();
  private followLatest: boolean = true;
  private chatPreferences: NativePreferences = defaultNativePreferences();
  @State @Watch('syncDock') preparingGeneration: boolean = false;
  @State @Watch('syncDock') committingReply: boolean = false;
  @State story: StorySettings = defaultStorySettings();
  @State worldReport: WorldStateReport = { status: 'missing', message: '尚未生成世界状态。' };
  private worldReportKey: string = '';
  @State worldBusy: boolean = false;
  @State worldApplying: boolean = false;
  @State worldError: string = '';
  private worldRequest: string = '';
  private worldRevision: number = 0;
  private worldLoadRevision: number = 0;
  private worldAutomatic: boolean = false;
  @State worldSettingsSaving: boolean = false;
  @State worldSidebarRight: boolean = true;
  @State worldSidebarSection: string = 'quests';
  @State worldControlsExpanded: boolean = false;
  @State worldItemBusy: boolean = false;
  @StorageProp(HOLDING_HAND_KEY) holdingHand: number = HOLDING_HAND_UNKNOWN;
  @StorageProp(HOLDING_ENABLED_KEY) holdingEnabled: boolean = true;
  @StorageProp(HOLDING_ACTION_KEY) holdingAction: boolean = true;
  private generationWorldConfig: string = '';
  @State storyChoices: StoryOption[] = [];
  @State choicesLoading: boolean = false;
  @State choicesError: string = '';
  @State @Watch('syncDock') replyNeedsSave: boolean = false;
  private choiceTurn: string = '';
  private choicesRevision: number = 0;
  private generationRevision: number = 0;
  @State generatingChoiceStream: boolean = false;
  @State userAvatar: string = '';
  @StorageProp('storyRevision') @Watch('reloadStory') storyRevision: number = 0;

  private async reloadStory(): Promise<void> {
    const chat: ChatDto | null = this.openChat;
    if (chat === null) { return; }
    try {
      const story: StorySettings = await NativeStory.get(chat.character_name, chat.file_name);
      if (this.mounted && this.openChat === chat) {
        this.story = story;
        this.loadWorldStatus();
        if (this.generatingChoiceStream) { this.cancelActiveStream(); this.streamText = ''; }
        this.refreshStoryChoices();
      }
    } catch (error) { this.errorText = '故事设置读取失败：' + (error as Error).message; }
  }

  private latestChoices(): StoryOption[] {
    if (!storyChoicesEnabled(this.story)) { return []; }
    for (let index: number = this.messages.length - 1; index >= 0; index--) {
      if (this.messages[index].is_system) { continue; }
      return this.messages[index].is_user ? [] : this.storyChoices;
    }
    return this.storyChoices;
  }

  private cancelActiveStream(): void {
    this.choicesRevision++;
    this.generationRevision++;
    this.stopPolling();
    const streamId: string = this.streamId;
    this.streamId = '';
    this.streaming = false;
    this.generatingChoiceStream = false;
    this.choicesLoading = false;
    if (streamId !== '') { Backend.closeChatCompletionStream(streamId).catch((): void => {}); }
  }

  private async refreshStoryChoices(): Promise<void> {
    const chat: ChatDto | null = this.openChat;
    if (chat === null || !this.mounted || this.streaming || this.preparingGeneration || this.committingReply || this.replyNeedsSave) { return; }
    const revision: number = ++this.choicesRevision;
    this.storyChoices = [];
    this.choicesError = '';
    this.choicesLoading = storyChoicesEnabled(this.story);
    if (!storyChoicesEnabled(this.story)) { return; }
    try {
      const current: StoryChoices = await NativeStory.choices(chat.character_name, chat.file_name);
      if (!this.mounted || this.openChat !== chat || revision !== this.choicesRevision) { return; }
      if (!current.needs_options) { return; }
      this.choiceTurn = current.turn;
      if (current.options.length >= 2) { this.storyChoices = current.options; return; }
      await this.loadCustomConfig();
      await this.loadChatPreferences();
      const dto: GenerateRequestDto = await this.buildDto(chat, this.messages, true);
      if (!this.mounted || this.openChat !== chat || revision !== this.choicesRevision) { return; }
      this.generatingChoiceStream = true;
      await this.startStreamWithAuth(chat.character_name, chat.file_name, dto);
      if (this.openChat === chat && revision === this.choicesRevision && !this.streaming) {
        this.generatingChoiceStream = false;
        this.choicesError = this.errorText || '选项尚未生成，可以重试或直接输入回复。';
      }
    } catch (error) {
      if (this.mounted && this.openChat === chat && revision === this.choicesRevision) {
        this.generatingChoiceStream = false;
        this.choicesError = '选项准备失败：' + (error as Error).message;
      }
    } finally {
      if (this.mounted && this.openChat === chat && revision === this.choicesRevision && !this.streaming) {
        this.choicesLoading = false;
        this.messageViewportChanged();
      }
    }
  }

  private chooseStoryOption(choice: StoryOption): void {
    if (this.busy || this.streaming || this.preparingGeneration || this.committingReply) { return; }
    if (this.inputText.trim() !== '' || this.attachedImages.length > 0) {
      this.getUIContext().getPromptAction().showToast({ message: '请先发送或清空当前草稿，再选择剧情选项' });
      return;
    }
    this.inputText = choice.reply;
    this.send(choice.reply);
  }

  private visibleStreamText(): string {
    let end: number = this.streamText.length;
    const markers: string[] = [];
    if (storyChoicesEnabled(this.story)) { markers.push('<story_options>'); }
    if (this.story.mode === 'world') { markers.push('<world_state>'); }
    for (const marker of markers) {
      const start: number = this.streamText.indexOf(marker);
      if (start >= 0) { end = Math.min(end, start); }
      for (let count: number = marker.length - 1; count > 0; count--) {
        if (this.streamText.endsWith(marker.substring(0, count))) { end = Math.min(end, this.streamText.length - count); break; }
      }
    }
    return this.streamText.substring(0, end);
  }

  private async loadChatPreferences(): Promise<void> {
    const snapshot = await NativeSettings.get();
    this.chatPreferences = snapshot.preferences;
    this.userAvatar = snapshot.avatar_path === '' ? '' : 'file://' + snapshot.avatar_path;
    this.userName = this.chatPreferences.user_name;
  }

  private async confirmMessageDelete(): Promise<boolean> {
    if (!this.chatPreferences.confirm_message_delete) { return true; }
    return new Promise<boolean>((resolve) => {
      this.getUIContext().showAlertDialog({ title: '删除消息', message: '确定删除这条消息？',
        primaryButton: { value: '取消', action: (): void => { resolve(false); } },
        secondaryButton: { value: '删除', action: (): void => { resolve(true); } },
        cancel: (): void => { resolve(false); }
      });
    });
  }
  private readingScroll: boolean = false;
  private layoutRevision: number = 0;
  private mounted: boolean = false;

  private scrollToBottom(): void {
    this.followLatest = true;
    this.messageViewportChanged();
  }

  private messagesChanged(): void {
    this.messageSource.replace(this.messages);
    if (this.story.mode === 'world') { this.loadWorldStatus(); }
  }

  private messageViewportChanged(): void {
    if (!this.mounted || !this.followLatest || this.scrollFramePending) { return; }
    this.scrollFramePending = true;
    const revision: number = this.layoutRevision;
    this.getUIContext().postFrameCallback(new ChatLayoutFrame((): void => {
      this.scrollFramePending = false;
      if (!this.mounted || revision !== this.layoutRevision || !this.followLatest) { return; }
      try {
        this.msgScroller.scrollEdge(Edge.Bottom);
      } catch (error) {
        return;
      }
    }));
  }

  aboutToAppear(): void {
    this.mounted = true;
    // 后端未初始化（进程恢复/直接冷启到本页）：回首页走完整初始化流程。
    if (!Backend.isReady()) {
      this.statusText = '后端未就绪，跳回首页初始化…';
      ROOT_PATH_STACK.pop();
      return;
    }
    this.loadChatPreferences().catch((error: Error): void => { this.errorText = error.message; });
    this.loadChatList();
    this.loadCharacters();
    this.loadCustomConfig();
    this.consumeChatIntent();
  }

  /**
   * 消费首页「新建会话」留下的一次性意图（P8-1）：直接打开该会话，
   * 而不是让用户在列表里再点一次。意图读取后即清空。
   */
  private async consumeChatIntent(): Promise<void> {
    const intent: string = ChatIntent.take();
    if (intent === '') {
      return;
    }
    const sep: number = intent.indexOf('|');
    if (sep <= 0) {
      return;
    }
    await this.openSelectedChat(intent.substring(0, sep), intent.substring(sep + 1));
  }

  /** 角色列表（get_all_characters deep：带 first_mes 作为新聊天开场白）。 */
  async loadCharacters(): Promise<void> {
    try {
      this.characters = await Backend.getAllCharacters();
      this.charactersText = this.characters.length === 0
        ? '无角色（先在首页初始化默认内容或导入角色）'
        : `角色 ${this.characters.length} 个（点角色新建聊天）`;
    } catch (err) {
      const message: string = (err as BackendError).message;
      this.charactersText = `角色加载失败：${message}`;
      hilog.error(DOMAIN, TAG, 'loadCharacters failed: %{public}s', message);
    }
  }

  /**
   * 聊天命令的 character_name 是**文件 stem**（avatar 去扩展名），不是显示名：
   * 默认角色文件是 `default_Seraphina.png`（内嵌卡片名却是 Seraphina），
   * `find_by_name` 按 `<name>.png` 定位文件——直接传显示名会 `Character not found`。
   * 导入角色的文件名=名字，此时 stem 与显示名相同，两种来源都安全。
   */
  private chatKey(character: CharacterDto): string {
    const avatar: string = character.avatar !== undefined ? character.avatar : '';
    if (avatar !== '') {
      const dot: number = avatar.lastIndexOf('.');
      return dot > 0 ? avatar.substring(0, dot) : avatar;
    }
    return character.name;
  }

  /** chat.character_name（stem）→ 显示名（角色列表里能对上时用卡片名）。 */
  private displayName(characterName: string): string {
    for (let i = 0; i < this.characters.length; i++) {
      const character: CharacterDto = this.characters[i];
      if (this.chatKey(character) === characterName) {
        return character.name;
      }
    }
    return characterName;
  }

  /** 新建聊天并打开：create_chat → openChat/messages → 刷新列表。 */
  async createChatFor(character: CharacterDto): Promise<void> {
    if (this.streaming || this.busy || this.preparingGeneration || this.committingReply) { return; }
    this.panel.close();
    StoryIntent.request(this.chatKey(character), character.name, character.first_mes ?? '');
  }

  async loadCustomConfig(): Promise<void> {
    try {
      const state: Record<string, ProviderSecretState[]> = await Backend.readSecretState() as Record<string, ProviderSecretState[]>;
      ProviderPreferences.hydrate(state);
      this.selectSource(PROVIDERS.indexOf(ProviderPreferences.active()));
    } catch (err) {
      this.errorText = '读取服务配置失败：' + (err as Error).message;
    }
  }

  selectSource(index: number): void {
    const provider: ProviderEntry = PROVIDERS[index];
    const config: ProviderConfig = ProviderPreferences.get(provider);
    this.providerId = provider.id;
    this.source = provider.source;
    this.model = config.model;
    this.customUrl = config.url;
    ProviderPreferences.activate(provider.id);
  }

  aboutToDisappear(): void {
    this.dock.preventBack = false;
    this.dock.panelOpen = false;
    this.mounted = false;
    this.settingsLoadRevision++;
    this.layoutRevision++;
    this.cancelContext();
    this.cancelWorld();
    this.cancelActiveStream();
  }

  async loadChatList(): Promise<void> {
    try {
      const chats: ChatSearchResultDto[] = await Backend.listChatSummaries();
      this.chatList = chats.map((chat: ChatSearchResultDto): ChatListItem => ({
        characterName: chat.character_name,
        fileName: chat.file_name,
        preview: chat.preview || '（空）',
        messageCount: chat.message_count
      }));
      this.chatListText = `共 ${this.chatList.length} 个聊天`;
    } catch (err) {
      const message: string = (err as BackendError).message;
      this.chatListText = `加载失败：${message}`;
      hilog.error(DOMAIN, TAG, 'loadChatList failed: %{public}s', message);
    }
  }

  private editSelectionChanged(): void {
    if (this.editIndex >= 0) { this.openPanel('editor', this.editorSourceId); }
    else if (this.activePanel === 'editor') { this.panel.close(); }
  }

  private closeMessageEditor(): void {
    this.panel.close();
  }

  private openPanel(kind: string, sourceId: string): void {
    this.activePanel = kind;
    if (kind === 'chat-settings') { this.loadGenerationSettings(); }
    if (kind === 'context') { this.loadContextStatus(); }
    if (kind.startsWith('world-')) { this.loadWorldStatus(); }
    this.dock.panelOpen = true;
    this.panel.open(this.getUIContext(), sourceId, kind === 'editor' || kind === 'model' ? 0.9 : 0.75,
      sourceId === 'chat-model-anchor' ? 'bottom' : 'orb');
  }

  private panelClosed(): void {
    this.dock.panelOpen = false;
    if (this.activePanel === 'context' && this.contextBusy && !this.contextApplying) { this.cancelContext(); }
    if (this.activePanel.startsWith('world-') && this.worldBusy && !this.worldApplying && !this.worldAutomatic) { this.cancelWorld(); }
    const editing: boolean = this.activePanel === 'editor';
    if (this.activePanel === 'model') { this.loadCustomConfig(); }
    this.activePanel = '';
    this.searchOpen = false;
    this.summaryVisible = false;
    if (editing) { this.editIndex = -1; this.editText = ''; }
  }

  private beginMessageEdit(message: ChatMessageDto, index: number, sourceId: string): void {
    if (this.openChat === null || this.replyNeedsSave || this.streaming || this.preparingGeneration || this.committingReply || this.generatingChoiceStream) { return; }
    this.editorSourceId = sourceId;
    this.editText = message.mes;
    this.editIndex = index;
  }

  async saveEdit(): Promise<void> {
    if (this.openChat === null || this.editIndex < 0) {
      return;
    }
    const chat: ChatDto = this.openChat as ChatDto;
    this.busy = true;
    this.errorText = '';
    try {
      await ChatFileOps.editMessage(chat.character_name, chat.file_name, this.editIndex, this.editText);
      this.statusText = `已保存第 ${this.editIndex + 1} 条消息`;
      this.editIndex = -1;
      this.editText = '';
      await this.openSelectedChat(chat.character_name, chat.file_name);
    } catch (err) {
      this.errorText = `保存失败：${(err as Error).message}`;
    } finally {
      this.busy = false;
    }
  }

  async deleteMessage(index: number): Promise<void> {
    if (this.openChat === null) {
      return;
    }
    if (this.busy || this.streaming || this.preparingGeneration || this.replyNeedsSave || this.committingReply || this.generatingChoiceStream) { return; }
    const chat: ChatDto = this.openChat as ChatDto;
    this.busy = true;
    this.errorText = '';
    try {
      await this.loadChatPreferences();
      if (!await this.confirmMessageDelete()) { return; }
      if (this.openChat !== chat || this.streaming) { return; }
      await ChatFileOps.deleteMessage(chat.character_name, chat.file_name, index);
      this.statusText = `已删除第 ${index + 1} 条消息`;
      await this.openSelectedChat(chat.character_name, chat.file_name);
    } catch (err) {
      this.errorText = `删除失败：${(err as Error).message}`;
    } finally {
      this.busy = false;
    }
  }

  /** 从这里重新生成：截断该条及之后 → 重新起流生成一条。 */
  async regenerateFrom(index: number): Promise<void> {
    if (this.openChat === null || this.replyNeedsSave || this.streaming || this.preparingGeneration || this.committingReply || this.busy || this.generatingChoiceStream) {
      return;
    }
    const chat: ChatDto = this.openChat as ChatDto;
    this.busy = true;
    this.errorText = '';
    try {
      const removed: number = await ChatFileOps.deleteMessagesFrom(chat.character_name, chat.file_name, index);
      await this.openSelectedChat(chat.character_name, chat.file_name);
      this.statusText = `已回退 ${removed} 条，重新生成…`;
      await this.retry();
    } catch (err) {
      this.errorText = `重新生成失败：${(err as Error).message}`;
    } finally {
      this.busy = false;
    }
  }

  async openSelectedChat(characterName: string, fileName: string): Promise<void> {
    if (this.committingReply || this.replyNeedsSave || this.preparingGeneration) {
      this.getUIContext().getPromptAction().showToast({ message: this.replyNeedsSave ? '请先保存已收到的回复，再切换对话' : '正在处理当前对话，请稍候' });
      return;
    }
    this.cancelActiveStream();
    this.storyChoices = [];
    this.choicesError = '';
    this.replyNeedsSave = false;
    this.reasoningExpanded = -1;
    this.streamText = '';
    this.streamUsage = undefined;
    this.streamUsageComplete = false;
    this.streamReasoning = '';
    this.reasoningTruncated = false;
    this.errorText = '';
    this.statusText = '';
    const revision: number = this.choicesRevision;
    try {
      const chat: ChatDto = await Backend.getChat(characterName, fileName);
      if (!this.mounted || revision !== this.choicesRevision) { return; }
      this.openChat = chat;
      this.worldControlsExpanded = false;
      this.messages = chat.messages;
      this.story = defaultStorySettings();
      await this.reloadStory();
      this.scrollToBottom();
      this.statusText = `${this.displayName(characterName)}/${fileName} · ${chat.message_count} 条`;
      this.loadSummary(characterName, fileName);
    } catch (err) {
      const message: string = (err as BackendError).message;
      this.errorText = `打开聊天失败：${message}`;
      hilog.error(DOMAIN, TAG, 'openChat failed: %{public}s', message);
    }
  }

  /** 读取聊天摘要（preview 即摘要文本；无摘要时服务端返回空 preview）。 */
  private async loadSummary(characterName: string, fileName: string): Promise<void> {
    this.chatSummary = '';
    try {
      const summary: ChatSearchResultDto =
        await Backend.getCharacterChatSummary(characterName, fileName);
      this.chatSummary = summary.preview;
      hilog.info(DOMAIN, TAG, 'chat summary loaded: %{public}d chars',
        summary.preview.length);
    } catch (err) {
      this.chatSummary = `摘要读取失败：${(err as BackendError).message}`;
      hilog.error(DOMAIN, TAG, 'loadSummary failed: %{public}s', (err as BackendError).message);
    }
  }

  /** 组装 provider payload（chat_completion_source 决定走哪个 provider）。 */
  private providerDto(messages: ChatMessageDto[]): GenerateRequestDto {
    const dto: GenerateRequestDto = {
      chat_completion_source: this.source,
      model: this.model,
      stream: true,
      include_reasoning: undefined,
      messages: messages.map((message: ChatMessageDto): ESObject => ({
        role: message.is_system ? 'system' : (message.is_user ? 'user' : 'assistant'),
        content: message.mes
      }))
    };
    const provider: ProviderEntry = PROVIDERS.find((entry: ProviderEntry) => entry.id === this.providerId) ?? PROVIDERS[0];
    const config: ProviderConfig = ProviderPreferences.get(provider);
    if (provider.source === 'custom') { config.url = Backend.normalizeBaseUrl(this.customUrl); }
    ProviderPreferences.apply(dto, provider, config);
    return dto;
  }

  private async buildDto(chat: ChatDto, messages: ChatMessageDto[], choicesOnly: boolean = false, pendingMessage: string = ''): Promise<GenerateRequestDto> {
    const dto: GenerateRequestDto = this.providerDto([]);
    if (!choicesOnly && this.story.mode === 'world') {
      const plan: WorldReplyPlan = await NativeWorld.prepareReply(chat.character_name, chat.file_name, dto, pendingMessage);
      this.generationWorldConfig = plan.expectedConfig;
      return plan.dto;
    }
    this.generationWorldConfig = '';
    return choicesOnly ? await NativeStory.prepareChoices(chat.character_name, chat.file_name, dto) :
      await NativeSettings.prepareChat(chat.character_name, dto, chat.file_name, pendingMessage);
  }

  /**
   * 重试（swipe-lite）：不重复落库用户消息，用现有上下文重新生成，
   * 完成后追加一条新助手回复（无 update_message 命令，旧回复保留）。
   */
  async retry(): Promise<void> {
    if (this.generatingChoiceStream || this.choicesLoading) { this.cancelActiveStream(); }
    if (this.streaming || this.preparingGeneration || this.committingReply || this.openChat === null || this.replyNeedsSave) { return; }
    this.storyChoices = [];
    this.choicesError = '';
    this.preparingGeneration = true;
    const revision: number = ++this.generationRevision;
    const chat: ChatDto = this.openChat as ChatDto;
    this.errorText = '';
    this.statusText = '重试中…（可点「停止」中断）';
    try {
      await this.loadChatPreferences();
      if (!this.mounted || this.openChat !== chat || revision !== this.generationRevision) { return; }
      const dto: GenerateRequestDto = await this.buildDto(chat, this.messages);
      if (!this.mounted || this.openChat !== chat || revision !== this.generationRevision) { return; }
      await this.startStreamWithAuth(chat.character_name, chat.file_name, dto);
    } catch (err) {
      if (!this.mounted || this.openChat !== chat || revision !== this.generationRevision) { return; }
      this.streaming = false;
      this.errorText = `重试失败：${(err as BackendError).message}`;
      this.statusText = '';
    } finally {
      this.preparingGeneration = false;
      if (!this.streaming && !this.replyNeedsSave) { this.refreshStoryChoices(); }
    }
  }

  /**
   * 附加图片（多模态输入）：相册选图 → 读字节 → base64 →
   * upload_user_image 写入当前角色聊天的 user_uploaded_images 目录。
   * 后续生成对多模态模型会自动带入该目录图片（SillyTavern 语义）。
   * △ 需在 DevEco 编译验证：PhotoViewPicker.select 的 MIMEType 枚举 /
   * fileIo 读 media-library uri / util.Base64Helper 实例化。
   */
  private async attachImage(): Promise<void> {
    if (this.openChat === null) {
      return;
    }
    const chat: ChatDto = this.openChat as ChatDto;
    try {
      const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const options: photoAccessHelper.PhotoSelectOptions = {
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      };
      const result: photoAccessHelper.PhotoSelectResult = await picker.select(options);
      const uri: string = result.photoUris.length > 0 ? result.photoUris[0] : '';
      if (uri === '') {
        return;
      }
      const file: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const stat: fs.Stat = fs.statSync(file.fd);
      const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);
      fs.closeSync(file);
      const bytes: Uint8Array = new Uint8Array(buffer);
      const b64: string = new util.Base64Helper().encodeToStringSync(bytes);
      const dot: number = uri.lastIndexOf('.');
      const ext: string = dot >= 0 ? uri.substring(dot + 1) : 'jpg';
      const upload = await Backend.uploadUserImage({
        imageBase64: b64,
        format: ext,
        filename: `chat_${Date.now()}.${ext}`,
        chName: chat.character_name
      });
      this.attachedImages.push(upload.path);
      this.statusText = `已附加图片：${upload.path}`;
      hilog.info(DOMAIN, TAG, 'image attached: %{public}s', upload.path);
    } catch (err) {
      const message: string = (err as Error).message;
      this.statusText = `附加图片失败：${message}`;
      hilog.error(DOMAIN, TAG, 'attachImage failed: %{public}s', message);
    }
  }

  /** 发送：持久化用户消息 → 起流 → 轮询解码流。 */
  async send(selectedReply: string = ''): Promise<void> {
    const frozenInput: string = selectedReply !== '' ? selectedReply : this.inputText;
    const chat: ChatDto | null = this.openChat;
    if (this.generatingChoiceStream || this.choicesLoading) { this.cancelActiveStream(); }
    if (this.streaming || this.preparingGeneration || this.committingReply || this.replyNeedsSave) { return; }
    if (chat === null) { this.statusText = '请先选择或新建一段对话'; return; }
    if (frozenInput.trim() === '') { return; }
    this.choicesRevision++;
    const revision: number = ++this.generationRevision;
    this.preparingGeneration = true;
    try { await this.loadChatPreferences(); }
    catch (error) { this.errorText = (error as Error).message; this.preparingGeneration = false; return; }
    if (!this.mounted || this.openChat !== chat || revision !== this.generationRevision) { this.preparingGeneration = false; return; }
    const input: string = this.chatPreferences.trim_spaces ? frozenInput.trim() : frozenInput;
    this.errorText = '';
    this.statusText = '生成中…（可点「停止」中断）';

    try {
      const dto: GenerateRequestDto = await this.buildDto(chat, this.messages, false, input);
      if (!this.mounted || this.openChat !== chat || revision !== this.generationRevision) { return; }
      const updated: ChatDto = await Backend.addMessage(chat.character_name, chat.file_name, {
        name: this.chatPreferences.user_name,
        isUser: true,
        isSystem: false,
        sendDate: new Date().toISOString(),
        mes: input
      });
      if (!this.mounted || this.openChat !== chat || revision !== this.generationRevision) { return; }
      this.messages = updated.messages;
      this.storyChoices = [];
      this.choicesError = '';
      this.scrollToBottom();
      if (this.inputText === frozenInput) { this.inputText = ''; }
      this.lastUserMes = input;

      await this.startStreamWithAuth(chat.character_name, chat.file_name, dto);
    } catch (err) {
      if (!this.mounted || this.openChat !== chat || revision !== this.generationRevision) { return; }
      const message: string = (err as BackendError).message;
      // 网络层错误（DNS/连接/超时）单独提示，其余按原样上屏。
      if (message.includes('target service address') || message.includes('timed out')
        || message.includes('Could not connect') || message.includes('proxy')) {
        this.errorText = `发送失败：${message}\n（DNS/网络层失败：域名可能拼写不对，或该地址在当前网络不可达；海外中转需代理，内网地址需同网段）`;
      } else {
        this.errorText = `发送失败：${message}`;
      }
      this.statusText = '';
      hilog.error(DOMAIN, TAG, 'send failed: %{public}s', message);
    } finally {
      this.preparingGeneration = false;
      if (!this.streaming && !this.replyNeedsSave) { this.refreshStoryChoices(); }
    }
  }

  /** 起流，遇到端点未授权时走三步握手（弹窗 → grant → 重试）。 */
  private async startStreamWithAuth(
    characterName: string, fileName: string, dto: GenerateRequestDto
  ): Promise<void> {
    const streamId: string = `ht_${Date.now()}_${Math.floor(Math.random() * 100000)}`;
    const chat: ChatDto | null = this.openChat;
    if (!this.mounted || chat === null || chat.character_name !== characterName || chat.file_name !== fileName) { return; }
    this.streamId = streamId;
    this.replyModel = dto.model || this.model;
    this.replyRequestKey = streamId;
    this.afterSeq = 0;
    this.streamText = '';
    this.streamUsage = undefined;
    this.streamUsageComplete = false;
    this.streamReasoning = '';
    this.reasoningTruncated = false;
    const protocol: string = dto.custom_api_format ?? dto.opencode_api_format ?? '';
    this.streamFormat = protocol === 'gemini_generate_content' || protocol === 'gemini' ? 'gemini' :
      (protocol === 'openai_responses' || protocol === 'claude_messages' || protocol === 'gemini_interactions') ? protocol :
      dto.chat_completion_source === 'claude' ? 'claude_messages' :
      dto.chat_completion_source === 'makersuite' || dto.chat_completion_source === 'vertexai' ? 'gemini' : 'openai_compatible';
    this.streaming = true;
    // 启动脉冲（1 → 0.25 循环），停止时由 streaming=false 让点消失。
    this.pulseOpacity = 0.25;
    try {
      await Backend.startChatCompletionStream(streamId, dto);
    } catch (err) {
      if (!this.mounted || this.streamId !== streamId || this.openChat !== chat) {
        Backend.closeChatCompletionStream(streamId).catch((): void => {});
        return;
      }
      const backendError: BackendError = err as BackendError;
      // 信封 message 形如 "Unauthorized: endpoint_authorization_required|<端点>"
      // （errors.rs `#[error("Unauthorized: {0}")]`），用 indexOf 定位前缀再截端点。
      const prefixIndex: number = backendError.message.indexOf(ENDPOINT_AUTH_REQUIRED_PREFIX);
      if (backendError.code === 'unauthorized' && prefixIndex >= 0) {
        const endpoint: string =
          backendError.message.substring(prefixIndex + ENDPOINT_AUTH_REQUIRED_PREFIX.length);
        const granted: boolean = await this.confirmEndpoint(endpoint);
        if (!this.mounted || this.streamId !== streamId || this.openChat !== chat) { return; }
        if (!granted) {
          this.streaming = false;
          this.statusText = '已取消：未授权端点';
          return;
        }
        // 第 ③ 步：授予后重试原命令。
        try {
          await Backend.grantUserEndpointAccess(endpoint);
          if (!this.mounted || this.streamId !== streamId || this.openChat !== chat) { return; }
          await Backend.startChatCompletionStream(streamId, dto);
        } catch (retryErr) {
          if (!this.mounted || this.streamId !== streamId || this.openChat !== chat) {
            Backend.closeChatCompletionStream(streamId).catch((): void => {});
            return;
          }
          this.streaming = false;
          this.errorText = `重试失败：${(retryErr as BackendError).message}`;
          return;
        }
      } else {
        this.streaming = false;
        this.errorText = `起流失败：${backendError.message}`;
        return;
      }
    }
    if (!this.mounted || this.streamId !== streamId || this.openChat !== chat) {
      Backend.closeChatCompletionStream(streamId).catch((): void => {});
      return;
    }
    this.startPolling();
  }

  private appendStreamBatch(text: string[], reasoning: string[]): void {
    if (text.length > 0) { this.streamText += text.join(''); text.length = 0; }
    if (reasoning.length > 0) {
      const combined: string = this.streamReasoning + reasoning.join('');
      this.reasoningTruncated = this.reasoningTruncated || combined.length > 60000;
      let limit: number = Math.min(combined.length, 60000);
      if (limit > 0 && combined.charCodeAt(limit - 1) >= 0xD800 && combined.charCodeAt(limit - 1) <= 0xDBFF) { limit--; }
      this.streamReasoning = combined.substring(0, limit);
      reasoning.length = 0;
    }
    if (this.chatPreferences.auto_scroll_chat_to_bottom && this.followLatest) { this.messageViewportChanged(); }
  }

  private receiveUsage(update: TokenUsage): void {
    const prompt: number | undefined = update.prompt_tokens ?? this.streamUsage?.prompt_tokens;
    const completion: number | undefined = update.completion_tokens ?? this.streamUsage?.completion_tokens;
    const sum: number | undefined = prompt !== undefined && completion !== undefined ? prompt + completion : undefined;
    this.streamUsage = {
      prompt_tokens: prompt,
      completion_tokens: completion,
      total_tokens: update.total_tokens ?? (sum !== undefined && Number.isSafeInteger(sum) ? sum : this.streamUsage?.total_tokens)
    };
  }

  /** 游标轮询：每次读 afterSeq 之后的新事件，追加文本。 */
  private startPolling(): void {
    if (this.pollRunning) {
      return;
    }
    this.pollRunning = true;
    const streamId: string = this.streamId;
    const tick = async (): Promise<void> => {
      if (!this.pollRunning || !this.streaming || !this.mounted || this.streamId !== streamId) {
        return;
      }
      try {
        const result: ChatCompletionStreamReadResultDecodedDto =
          await Backend.readChatCompletionStreamDecoded(streamId, this.afterSeq, this.streamFormat);
        if (!this.pollRunning || !this.mounted || this.streamId !== streamId) { return; }
        const reasoningChunks: string[] = [];
        const textChunks: string[] = [];
        for (const event of result.events) {
          if (event.type === 'chunk') {
            this.afterSeq = event.seq;
            let text = '';
            let reasoning = '';
            for (const part of event.parts) {
              if (part.kind === 'text') {
                text += part.text;
              } else if (part.kind === 'reasoning') {
                reasoning += part.text;
              } else if (part.kind === 'usage') {
                this.receiveUsage(part.usage);
              }
              // tool_call / stop / raw 第一版不渲染正文，raw 仍会进日志。
              if (part.kind === 'raw') {
                hilog.warn(DOMAIN, TAG, 'unparsed stream chunk: %{public}d characters', part.data.length);
              }
            }
            if (text !== '') { textChunks.push(text); }
            if (reasoning !== '') { reasoningChunks.push(reasoning); }
          } else if (event.type === 'done') {
            this.afterSeq = event.seq;
            this.appendStreamBatch(textChunks, reasoningChunks);
            this.streamUsageComplete = true;
            await this.finalizeStream();
            return;
          } else if (event.type === 'error') {
            this.appendStreamBatch(textChunks, reasoningChunks);
            this.finishStreamError(`流错误：${event.message}`);
            return;
          }
        }
        this.appendStreamBatch(textChunks, reasoningChunks);
        // A terminal status can precede the last batch (64 events per read).
        // Drain until its terminal event arrives; otherwise late usage/text would be lost.
        if (result.status !== 'running' && result.events.length === 0) {
          if (result.status === 'done') {
            this.streamUsageComplete = true;
            await this.finalizeStream();
          } else {
            this.finishStreamError(result.status === 'cancelled' ? '生成已中断' : '生成失败');
          }
          return;
        }
        this.pollTimer = setTimeout(tick, POLL_INTERVAL_MS);
      } catch (err) {
        if (!this.mounted || this.streamId !== streamId) { return; }
        this.finishStreamError(`读取流失败：${(err as BackendError).message}`);
      }
    };
    this.pollTimer = setTimeout(tick, POLL_INTERVAL_MS);
  }

  private stopPolling(): void {
    this.pollRunning = false;
    if (this.pollTimer >= 0) {
      clearTimeout(this.pollTimer);
      this.pollTimer = -1;
    }
  }

  private finishStreamError(message: string): void {
    const choices: boolean = this.generatingChoiceStream;
    this.cancelActiveStream();
    if (choices) {
      this.streamText = '';
      this.choicesError = message;
      this.statusText = '选项准备中断，可以重试或自由输入';
    } else {
      this.errorText = message;
      this.replyNeedsSave = this.streamText.trim() !== '';
      this.statusText = this.replyNeedsSave ? '回复中断，已保留收到的内容' : '生成失败，可以重新生成';
      if (!this.replyNeedsSave) { this.refreshStoryChoices(); }
    }
  }

  private async finalizeStream(): Promise<void> {
    const choices: boolean = this.generatingChoiceStream;
    const chat: ChatDto | null = this.openChat;
    const text: string = this.streamText;
    const turn: string = this.choiceTurn;
    this.cancelActiveStream();
    if (chat === null) { return; }
    if (choices) {
      this.streamText = '';
      this.committingReply = true;
      this.choicesLoading = true;
      try {
        const result: StoryChoices = await NativeStory.commitChoices(chat.character_name, chat.file_name, turn, text);
        if (this.mounted && this.openChat === chat) {
          this.storyChoices = result.options;
          this.choicesError = '';
          this.statusText = '轮到你了';
        }
      } catch (error) {
        if (this.mounted && this.openChat === chat) { this.choicesError = '选项准备失败：' + (error as Error).message; }
      } finally {
        this.committingReply = false;
        this.choicesLoading = false;
        this.messageViewportChanged();
      }
      return;
    }
    if (text.trim() === '') {
      this.streamText = '';
      this.statusText = '完成（无输出）';
      if (this.streamReasoning !== '') { this.errorText = '模型只返回了思考内容，没有正文；请检查回复长度上限或降低推理强度。'; }
      this.refreshStoryChoices();
      return;
    }
    await this.persistNarrativeReply();
  }

  private async persistNarrativeReply(): Promise<void> {
    const chat: ChatDto | null = this.openChat;
    if (chat === null || this.committingReply || this.streaming || this.streamText.trim() === '') { return; }
    this.committingReply = true;
    this.replyNeedsSave = false;
    try {
      const reply: StoryReply = await NativeStory.commit(chat.character_name, chat.file_name, this.streamText,
        this.streamUsage, this.streamUsageComplete, this.streamReasoning, this.reasoningTruncated, this.generationWorldConfig, this.replyModel, this.replyRequestKey);
      if (!this.mounted || this.openChat !== chat) { return; }
      this.messages = reply.chat.messages;
      this.streamText = '';
      this.streamReasoning = '';
      this.reasoningTruncated = false;
      this.statusText = '完成';
      this.errorText = '';
      if (this.chatPreferences.auto_scroll_chat_to_bottom && this.followLatest) { this.messageViewportChanged(); }
      await this.loadChatList();
    } catch (error) {
      if (this.mounted && this.openChat === chat) {
        this.replyNeedsSave = true;
        this.errorText = '回复尚未保存：' + (error as Error).message;
        this.statusText = '内容已保留，请重试保存';
      }
    } finally {
      this.committingReply = false;
      if (this.mounted && this.openChat === chat && !this.replyNeedsSave) { this.refreshStoryChoices(); }
    }
    if (this.mounted && this.openChat === chat && !this.replyNeedsSave && this.streamUsageComplete &&
      this.story.mode === 'world' && (this.story.world_update_mode ?? 'auxiliary') === 'auxiliary') {
      await this.generateWorld(true);
    }
  }

  /** 会话内检索：命中 {index, role, snippet}；点一下把气泡高亮并标出条号。 */
  async runChatSearch(): Promise<void> {
    const query: string = this.searchQuery.trim();
    if (query === '' || this.openChat === null) {
      this.searchNote = '先打开一个聊天再搜';
      return;
    }
    this.busy = true;
    this.searchNote = '';
    try {
      const hits: ESObject[] = await Backend.searchCharacterChatMessages(
        this.openChat.character_name, this.openChat.file_name, query, 50);
      this.searchHits = hits;
      if (hits.length === 0) {
        this.searchNote = '没有命中';
      } else {
        // 命中详情直接写进状态行：老聊天页排版很紧，单独的结果区会被挤出可视区，
        // 所以这里是「看得见」的那一份摘要（真·结果列表在 hits 行里）。
        let summary: string = `命中 ${hits.length} 条`;
        const shown: number = hits.length < 2 ? hits.length : 2;
        for (let i = 0; i < shown; i++) {
          summary += `　${this.hitLabel(hits[i])}`;
        }
        this.searchNote = summary;
        this.statusText = summary;
      }
    } catch (err) {
      this.searchNote = `搜索失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  hitIndex(hit: ESObject): number {
    return (hit.index as number) ?? -1;
  }

  hitLabel(hit: ESObject): string {
    const index: number = this.hitIndex(hit);
    const role: string = (hit.role as string) ?? '';
    const snippet: string = (hit.snippet as string) ?? (hit.text as string) ?? '';
    return `#${index} ${role} · ${snippet}`;
  }

  /** 端点授权确认弹窗（zh-CN 文案，照搬上游 user_endpoint_access.rs）。 */
  private async confirmEndpoint(endpoint: string): Promise<boolean> {
    const httpWarning: string = endpoint.startsWith('http://')
      ? '\n此 HTTP 连接未加密，传输内容可能被观察或修改。' : '';
    const message: string =
      `端点：${endpoint}\n\n` +
      '第三方扩展也可能发起此请求。仅当这是你刚刚配置并认识的端点时继续；' +
      'TauriTavern 可能向它发送 API 密钥、提示词和聊天内容。该端点后续将保持信任，请谨慎授权。' +
      httpWarning;
    // P7 步骤 4：AlertDialog.show → UIContext.showAlertDialog（UIContext 绑定当前窗口，
    // 避免无窗口上下文时告警）。primaryButton/secondaryButton 签名与全局版一致。
    return new Promise<boolean>((resolve: (value: boolean) => void) => {
      this.getUIContext().showAlertDialog({
        title: '允许连接到自定义端点？',
        alignment: DialogAlignment.Center,
        transition: OriginMotion.dialog(this.getUIContext(), 'chat-send-anchor'),
        message: message,
        backgroundColor: Color.Transparent,
        backgroundEffect: glassEffect(GLASS_MENU, this.blurRadius, this.immersiveLevel, this.uiColors),
        systemMaterial: SystemGlass.dialog(this.uiColors),
        primaryButton: {
          value: '信任并连接',
          fontColor: this.uiColors.textInverse,
          backgroundColor: this.uiColors.accent,
          action: () => { resolve(true); }
        },
        secondaryButton: {
          value: '取消',
          fontColor: this.uiColors.textPrimary,
          backgroundColor: this.uiColors.bgSurfaceHigh,
          action: () => { resolve(false); }
        }
      });
    });
  }

  @Builder
  conversationPicker() {
    Button('聊天生成设置', { type: ButtonType.Normal })
      .attributeModifier(new ActionButtonStyle(this.uiColors)).width('100%').constraintSize({ minHeight: 48 })
      .id('chat-settings-entry').onClick((): void => { this.activePanel = 'chat-settings'; this.loadGenerationSettings(); })
    Text('继续故事').fontSize(15).fontWeight(FontWeight.Bold).fontColor(this.uiColors.textPrimary)
    Text(this.chatListText).fontSize(13).fontColor(this.uiColors.textSecondary)
    ForEach(this.chatList, (item: ChatListItem) => {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 12 }) {
          IdentityAvatar({ name: this.displayName(item.characterName), source: this.avatarSource(item.characterName), diameter: 42 })
          Column({ space: 5 }) {
            Text(this.displayName(item.characterName)).fontSize(16).fontWeight(FontWeight.Medium)
              .fontColor(this.uiColors.textPrimary).width('100%').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(item.preview || '还没有消息').fontSize(13).fontColor(this.uiColors.textSecondary)
              .width('100%').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(`${item.messageCount} 条消息 · ${item.fileName}`).fontSize(12).fontColor(this.uiColors.textSecondary)
              .width('100%').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          if (this.openChat?.character_name === item.characterName && this.openChat?.file_name === item.fileName) {
            Text('当前').fontSize(12).fontColor(this.uiColors.accent)
          }
        }.width('100%')
      }
      .width('100%').padding(16)
      .backgroundColor(this.uiColors.headerButtonTint)
      .border({ width: 0.8, color: this.uiColors.glassEdge })
      .borderRadius(20)
      .stateStyles({ normal: touchFeedbackNormal, pressed: touchFeedbackPressed })

      .onClick(() => {
        this.panel.close();
        this.openSelectedChat(item.characterName, item.fileName);
      })
    }, (item: ChatListItem) => `${item.characterName}/${item.fileName}`)
    Text('开启新故事').fontSize(15).fontWeight(FontWeight.Bold).fontColor(this.uiColors.textPrimary)
    Text(this.charactersText).fontSize(13).fontColor(this.uiColors.textSecondary)
    ForEach(this.characters, (character: CharacterDto) => {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 12 }) {
          IdentityAvatar({ name: character.name, source: this.avatarSource(this.chatKey(character)), diameter: 40 })
          Text(character.name).fontSize(15).fontColor(this.uiColors.textPrimary).layoutWeight(1)
            .textAlign(TextAlign.Start).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          Image($r('app.media.icon_add')).width(24).height(24).colorFilter(iconTint(this.uiColors.accent))
        }.width('100%')
      }
      .width('100%').padding(14)
      .backgroundColor(this.uiColors.headerButtonTint)
      .border({ width: 0.8, color: this.uiColors.glassEdge })
      .borderRadius(20)
      .enabled(!this.streaming)
      .stateStyles({ normal: touchFeedbackNormal, pressed: touchFeedbackPressed })

      .onClick(() => { this.createChatFor(character); })
    }, (character: CharacterDto) => character.name)
  }

  @Builder
  conversationSheet() {
    ChatPanel({ title: '选择一段故事', subtitle: '继续之前的对话，或与角色开启新故事', managedLayout: true,
      onContentHeight: (height: number): void => { this.panel.fitContentHeight(height); },
      onClose: (): void => { this.panel.close(); },
      content: (): void => { this.conversationPicker(); } })
  }

  private async loadGenerationSettings(): Promise<void> {
    const revision: number = ++this.settingsLoadRevision;
    this.generationLoading = true;
    this.generationSnapshot = undefined;
    this.generationError = '';
    try {
      const snapshot: NativePreferencesSnapshot = await NativeSettings.get();
      if (!this.mounted || revision !== this.settingsLoadRevision) { return; }
      this.generationSnapshot = snapshot;
      this.generationDraft = snapshot.preferences;
    } catch (error) {
      if (this.mounted && revision === this.settingsLoadRevision) { this.generationError = (error as Error).message; }
    } finally { if (revision === this.settingsLoadRevision) { this.generationLoading = false; } }
  }

  private async saveGenerationSettings(): Promise<void> {
    if (this.generationSaving || this.generationLoading || this.preparingGeneration || this.streaming || !this.generationSnapshot) { return; }
    this.generationSaving = true;
    this.preparingGeneration = true;
    this.generationError = '';
    try {
      const snapshot: NativePreferencesSnapshot = await NativeSettings.save(this.generationDraft, this.generationSnapshot.revision);
      if (!this.mounted) { return; }
      this.generationSnapshot = snapshot;
      this.generationDraft = snapshot.preferences;
      this.chatPreferences = snapshot.preferences;
      this.getUIContext().getPromptAction().showToast({ message: '聊天生成设置已保存' });
    } catch (error) { if (this.mounted) { this.generationError = (error as Error).message + '；如设置已变化，请重新读取后再保存。'; } }
    finally { this.generationSaving = false; this.preparingGeneration = false; }
  }

  private async loadWorldStatus(): Promise<void> {
    const chat: ChatDto | null = this.openChat;
    const revision: number = ++this.worldLoadRevision;
    const key: string = chat === null ? '' : chat.character_name + '/' + chat.file_name;
    const retained: WorldStateReport = this.worldReportKey === key ? this.worldReport : { status: 'missing', message: '' };
    this.worldReportKey = key;
    this.worldReport = { status: 'loading', message: '读取世界状态中…', state: retained.state };
    if (chat === null || this.story.mode !== 'world') {
      this.worldReport = { status: 'disabled', message: '' };
      return;
    }
    try {
      const report: WorldStateReport = await NativeWorld.status(chat.character_name, chat.file_name);
      if (this.mounted && this.openChat === chat && revision === this.worldLoadRevision) { this.worldReport = report; }
    } catch (error) {
      if (this.mounted && this.openChat === chat && revision === this.worldLoadRevision) {
        this.worldReport = { status: retained.state === undefined ? 'error' : 'stale', message: (error as Error).message, state: retained.state };
        this.worldError = '读取状态失败：' + (error as Error).message;
      }
    }
  }

  private cancelWorld(): void {
    if (this.worldApplying) { return; }
    this.worldRevision++;
    const request: string = this.worldRequest;
    this.worldRequest = '';
    if (this.worldBusy) { this.preparingGeneration = false; this.worldError = '已取消，原状态未更改。'; }
    this.worldBusy = false;
    if (request !== '') { Backend.cancelChatCompletionGeneration(request).catch((): void => {}); }
  }

  private async generateWorld(automatic: boolean = false): Promise<void> {
    if (this.worldBusy || this.worldSettingsSaving || this.streaming || this.preparingGeneration || this.committingReply || this.replyNeedsSave || this.openChat === null || this.story.mode !== 'world') { return; }
    const chat: ChatDto = this.openChat;
    const revision: number = ++this.worldRevision;
    this.worldBusy = true;
    this.worldAutomatic = automatic;
    this.preparingGeneration = true;
    this.worldError = '';
    const request: string = 'world_ui_' + Date.now();
    this.worldRequest = request;
    try {
      const route: GenerateRequestDto = await AuxiliaryModels.route({ messages: [] }, false, this.story.world_model_id ?? '');
      if (!this.mounted || revision !== this.worldRevision || this.openChat !== chat) { return; }
      const plan: WorldStatePlan = await NativeWorld.prepare(chat.character_name, chat.file_name, route, automatic);
      if (!this.mounted || revision !== this.worldRevision || this.openChat !== chat) { return; }
      let response: ESObject;
      try { response = await Backend.generateChatCompletion(request, plan.dto); }
      catch (error) {
        const marker: string = 'endpoint_authorization_required|';
        const message: string = (error as Error).message;
        const position: number = message.indexOf(marker);
        if (position < 0) { throw new Error(message); }
        if (!this.mounted || revision !== this.worldRevision) { return; }
        const endpoint: string = message.substring(position + marker.length).trim();
        const trusted: boolean = await new Promise<boolean>((resolve) => {
          this.getUIContext().showAlertDialog({ title: '信任端点', message: '生成界面会发送所选世界书、人物资料与当前聊天上下文到 ' + endpoint,
            primaryButton: { value: '取消', action: (): void => { resolve(false); } },
            secondaryButton: { value: '信任并连接', action: (): void => { resolve(true); } }, cancel: (): void => { resolve(false); } });
        });
        if (!trusted || !this.mounted || revision !== this.worldRevision) { return; }
        await Backend.grantUserEndpointAccess(endpoint);
        if (!this.mounted || revision !== this.worldRevision || this.openChat !== chat) { return; }
        response = await Backend.generateChatCompletion(request, plan.dto);
      }
      if (!this.mounted || revision !== this.worldRevision || this.openChat !== chat) { return; }
      this.worldApplying = true;
      const report: WorldStateReport = await NativeWorld.commit(chat.character_name, chat.file_name, plan.expectedTurn, response);
      this.worldLoadRevision++;
      if (this.mounted && revision === this.worldRevision && this.openChat === chat) {
        this.worldReport = report;
        this.statusText = automatic ? '本轮状态已由辅助模型更新' : '已根据世界书生成状态界面，聊天原文未更改';
      }
    } catch (error) {
      if (this.mounted && revision === this.worldRevision) { this.worldError = '界面生成失败，原状态未更改：' + (error as Error).message; }
    } finally {
      if (revision === this.worldRevision) {
        this.worldApplying = false; this.worldBusy = false; this.worldAutomatic = false; this.worldRequest = ''; this.preparingGeneration = false;
      }
    }
  }

  private async saveWorldModel(id: string): Promise<void> {
    const chat: ChatDto | null = this.openChat;
    if (chat === null || this.worldBusy || this.worldSettingsSaving || this.streaming || this.preparingGeneration || this.committingReply || this.replyNeedsSave) { return; }
    this.worldSettingsSaving = true; this.preparingGeneration = true; this.worldError = '';
    try {
      const draft: StorySettings = JSON.parse(JSON.stringify(this.story)) as StorySettings;
      draft.world_model_id = id;
      const saved: StorySettings = await NativeStory.save(chat.character_name, chat.file_name, draft);
      if (this.mounted && this.openChat === chat) { this.story = saved; }
    } catch (error) {
      if (this.mounted && this.openChat === chat) { this.worldError = '模型选择未保存：' + (error as Error).message; }
    } finally { this.worldSettingsSaving = false; this.preparingGeneration = false; }
  }

  private cupSide: boolean = true;
  private journalOnRight(): boolean {
    if (this.story.world_sidebar_side === 'left') { return false; }
    if (this.story.world_sidebar_side === 'right') { return true; }
    if (!this.holdingEnabled || !this.holdingAction) { return true; }
    this.cupSide = HoldingPose.cupOnRight(this.holdingHand, this.cupSide);
    return this.cupSide;
  }

  private openWorldSidebar(section: string = 'quests', onRight?: boolean, sourceId: string = 'chat-world-journal'): void {
    this.worldSidebarSection = section;
    this.worldSidebarRight = onRight ?? this.journalOnRight();
    this.worldControlsExpanded = section === 'settings';
    this.getUIContext().getFocusController().clearFocus();
    this.openPanel('world-' + section, sourceId);
  }

  private itemActionsAvailable(): boolean {
    return this.worldReport.status === 'ready' && !this.worldItemBusy && !this.worldBusy && !this.worldSettingsSaving &&
      !this.streaming && !this.preparingGeneration && !this.committingReply && !this.replyNeedsSave && !this.busy;
  }

  private async applyWorldItem(index: number, action: string): Promise<void> {
    const chat: ChatDto | null = this.openChat;
    const state = this.worldReport.state;
    if (chat === null || state === undefined || !this.itemActionsAvailable()) { return; }
    this.worldItemBusy = true; this.preparingGeneration = true; this.worldError = '';
    this.worldLoadRevision++;
    try {
      const report: WorldStateReport = await NativeWorld.itemAction(chat.character_name, chat.file_name, state, index, action);
      if (this.mounted && this.openChat === chat) {
        this.worldReport = report;
        if (action === 'use') { this.getUIContext().getPromptAction().showToast({ message: '已使用一件，具体效果随剧情确认' }); }
      }
    } catch (error) {
      if (this.mounted && this.openChat === chat) { this.worldError = (error as Error).message; }
    } finally { this.worldItemBusy = false; this.preparingGeneration = false; }
  }

  private selectWorldItem(index: number, action: string): void {
    const item: WorldItem | undefined = this.worldReport.state?.inventory[index];
    if (item === undefined || !this.itemActionsAvailable()) { return; }
    if (action !== 'discard') { this.applyWorldItem(index, action); return; }
    const state = this.worldReport.state;
    this.getUIContext().showAlertDialog({ title: '丢弃 ' + item.name,
      message: '将丢弃这一项的全部数量。',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: { value: '丢弃', action: (): void => {
        if (this.worldReport.state === state) { this.applyWorldItem(index, action); }
      } } });
  }

  @Builder
  worldStateContent(section: string = 'status') {
    if (worldNeedsInitialization(this.worldReport)) {
    Text(this.worldReport.message).fontSize(13).fontColor(this.uiColors.textSecondary).lineHeight(22).width('100%')
    Text('资料：' + this.story.world_books.join('、')).fontSize(13).fontColor(this.uiColors.textSecondary).width('100%')
    if (this.story.world_ui_request !== '') {
      Text('界面需求：' + this.story.world_ui_request).fontSize(14).fontColor(this.uiColors.textPrimary).lineHeight(22).width('100%')
    }
    }
    if (this.worldError !== '') { Text(this.worldError).fontSize(14).fontColor(this.uiColors.danger).width('100%') }
    Row({ space: 4 }) {
      Text(this.worldBusy ? '正在更新…' : this.worldReport.status === 'stale' ? '上次快照 · 本轮待确认' : '状态')
        .fontSize(13).fontColor(this.uiColors.textSecondary).layoutWeight(1)
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.icon_settings')).width(17).height(17).colorFilter(iconTint(this.uiColors.textSecondary))
      }.width(32).height(32).backgroundColor(Color.Transparent).accessibilityText('展开或收起状态栏模型设置')
        .id('world-controls-toggle').onClick((): void => { this.worldControlsExpanded = !this.worldControlsExpanded; })
      Button({ type: ButtonType.Circle }) {
        if (this.worldBusy) { LoadingProgress().width(18).height(18).color(this.uiColors.accent) }
        else { Image($r('app.media.icon_refresh')).width(17).height(17).colorFilter(iconTint(this.uiColors.textSecondary)) }
      }.width(32).height(32).padding(0).backgroundColor(Color.Transparent)
        .enabled(!this.worldBusy && !this.worldSettingsSaving && !this.streaming && !this.preparingGeneration && !this.replyNeedsSave && !this.committingReply)
        .accessibilityText('重新生成界面，会使用状态栏模型').id('world-generate').onClick((): void => { this.generateWorld(); })
      if (this.worldBusy) {
        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.icon_stop')).width(17).height(17).colorFilter(iconTint(this.uiColors.textSecondary))
        }.width(32).height(32).backgroundColor(Color.Transparent).enabled(!this.worldApplying)
          .accessibilityText('取消状态生成').id('world-generate-cancel').onClick((): void => { this.cancelWorld(); })
      }
    }.width('100%')
    if (worldNeedsInitialization(this.worldReport) || this.worldControlsExpanded) {
    WorldModelPicker({ selectedId: this.story.world_model_id ?? '',
      available: !this.worldBusy && !this.worldSettingsSaving && !this.streaming && !this.preparingGeneration && !this.replyNeedsSave && !this.committingReply,
      onSelect: (id: string): void => { this.saveWorldModel(id); } })
    }
    if (this.worldSettingsSaving) { Text('正在保存模型选择…').fontSize(12).fontColor(this.uiColors.textSecondary) }
    if (worldNeedsInitialization(this.worldReport)) {
    Text((this.story.world_update_mode === 'manual' ? '当前仅手动更新。' : this.story.world_update_mode === 'inline' ?
      '当前随主回复更新，会增加主模型状态指令与输出用量。' : '完整回复后由状态栏模型单独提取，不向主模型添加状态指令或 JSON。辅助请求仍会计费。') +
      '状态不是实时模拟器；持续时间不随设备时钟扣减，未知值不填 0。更新方式可在“故事与聊天模式”修改。')
      .fontSize(12).fontColor(this.uiColors.textSecondary).lineHeight(21).width('100%')
    }
    if (this.worldReport.state !== undefined && section !== 'settings') {
      WorldStatusDetails({ state: this.worldReport.state, section: section, actionsAvailable: this.itemActionsAvailable(),
        onItemAction: (index: number, action: string): void => { this.selectWorldItem(index, action); } })
    }
  }

  private async loadContextStatus(): Promise<void> {
    const chat: ChatDto | null = this.openChat;
    this.contextInfo = undefined;
    this.contextError = '';
    if (chat === null) { return; }
    try {
      const status: ContextStatus = await NativeContext.status(chat.character_name, chat.file_name);
      if (this.mounted && this.openChat === chat) { this.contextInfo = status; }
    } catch (error) { if (this.mounted && this.openChat === chat) { this.contextError = (error as Error).message; } }
  }

  private cancelContext(): void {
    if (this.contextApplying) { return; }
    this.contextRevision++;
    const request: string = this.contextRequest;
    this.contextRequest = '';
    if (this.contextBusy) { this.preparingGeneration = false; this.contextError = '已取消精简，原上下文未更改。'; }
    this.contextBusy = false;
    if (request !== '') { Backend.cancelChatCompletionGeneration(request).catch((): void => {}); }
  }

  private async compactContext(): Promise<void> {
    if (this.contextBusy || this.streaming || this.preparingGeneration || this.committingReply || this.replyNeedsSave || this.openChat === null) { return; }
    const chat: ChatDto = this.openChat;
    const revision: number = ++this.contextRevision;
    this.contextBusy = true;
    this.preparingGeneration = true;
    this.contextError = '';
    const request: string = 'compact_' + Date.now();
    this.contextRequest = request;
    try {
      await this.loadCustomConfig();
      const plan: ContextPlan = await NativeContext.prepare(chat.character_name, chat.file_name, this.providerDto([]));
      if (!this.mounted || revision !== this.contextRevision || this.openChat !== chat) { return; }
      let response: ESObject;
      try { response = await Backend.generateChatCompletion(request, plan.dto); }
      catch (error) {
        const marker: string = 'endpoint_authorization_required|';
        const message: string = (error as Error).message;
        const position: number = message.indexOf(marker);
        if (position < 0) { throw new Error(message); }
        if (!this.mounted || revision !== this.contextRevision) { return; }
        const endpoint: string = message.substring(position + marker.length).trim();
        const trusted: boolean = await new Promise<boolean>((resolve) => {
          this.getUIContext().showAlertDialog({ title: '信任端点', message: '精简会发送待摘要的历史到 ' + endpoint,
            primaryButton: { value: '取消', action: (): void => { resolve(false); } },
            secondaryButton: { value: '信任并连接', action: (): void => { resolve(true); } }, cancel: (): void => { resolve(false); } });
        });
        if (!trusted || !this.mounted || revision !== this.contextRevision) { return; }
        await Backend.grantUserEndpointAccess(endpoint);
        if (!this.mounted || revision !== this.contextRevision) { return; }
        response = await Backend.generateChatCompletion(request, plan.dto);
      }
      if (!this.mounted || revision !== this.contextRevision || this.openChat !== chat) { return; }
      this.contextApplying = true;
      this.contextInfo = await NativeContext.commit(chat.character_name, chat.file_name, plan.expectedTurn, response);
      this.statusText = '上下文已精简，聊天原文完整保留';
    } catch (error) {
      if (this.mounted && revision === this.contextRevision) { this.contextError = '精简失败，原上下文未更改：' + (error as Error).message; }
    } finally {
      if (revision === this.contextRevision) {
        this.contextApplying = false; this.contextBusy = false; this.contextRequest = ''; this.preparingGeneration = false;
      }
    }
  }

  private async resetContext(): Promise<void> {
    const chat: ChatDto | null = this.openChat;
    if (chat === null || this.contextBusy || this.streaming || this.preparingGeneration) { return; }
    this.preparingGeneration = true;
    this.contextError = '';
    try { this.contextInfo = await NativeContext.reset(chat.character_name, chat.file_name); }
    catch (error) { this.contextError = (error as Error).message; }
    finally { this.preparingGeneration = false; }
  }

  @Builder
  contextContent() {
    Text('用事实摘要替代较早历史，保留最近至少 8 条原文；聊天记录不会被删除。摘要可能遗漏细节，可随时恢复完整上下文。')
      .fontSize(14).fontColor(this.uiColors.textSecondary).lineHeight(23).width('100%')
    if (this.contextInfo !== undefined) {
      Text(this.contextInfo.stale ? '历史已修改，旧摘要自动失效，当前使用完整上下文。' :
        this.contextInfo.active ? '已摘要 ' + this.contextInfo.covered + ' / ' + this.contextInfo.total + ' 条消息' : '尚未精简，正在使用完整历史')
        .fontSize(15).fontColor(this.uiColors.textPrimary).width('100%')
      Text('历史正文字符：' + this.contextInfo.original_chars + ' → ' + this.contextInfo.sent_chars + '（不是 Token 实际计费）')
        .fontSize(13).fontColor(this.uiColors.textSecondary).width('100%')
      if (this.contextInfo.summary !== '') {
        Text(this.contextInfo.summary).fontSize(14).fontColor(this.uiColors.textPrimary).lineHeight(23).width('100%')
      }
    }
    if (this.contextError !== '') { Text(this.contextError).fontSize(14).fontColor(this.uiColors.danger).width('100%') }
    Button(this.contextBusy ? '正在精简…' : '调用当前模型精简（额外消耗 Token）')
      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary)).width('100%').height('auto').constraintSize({ minHeight: 48 })
      .enabled(!this.contextBusy && !this.streaming && !this.preparingGeneration && !this.replyNeedsSave)
      .id('chat-compact-run').onClick((): void => { this.compactContext(); })
    if (this.contextBusy) {
      Button(this.contextApplying ? '正在应用摘要…' : '取消精简').attributeModifier(new ActionButtonStyle(this.uiColors))
        .width('100%').enabled(!this.contextApplying).onClick((): void => { this.cancelContext(); })
    }
    Button('恢复完整上下文').attributeModifier(new ActionButtonStyle(this.uiColors)).width('100%')
      .enabled(!this.contextBusy && !this.streaming && !this.preparingGeneration).id('chat-compact-reset')
      .onClick((): void => { this.resetContext(); })
    Text('每次处理一段较早历史；超长对话可重复精简。模型或网络失败不会应用摘要。人物卡、世界书、故事设置仍会按原配置发送。')
      .fontSize(13).fontColor(this.uiColors.textSecondary).lineHeight(21).width('100%')
  }

  @Builder
  generationControls() {
    if (this.generationLoading) { LoadingProgress().width(24).height(24).color(this.uiColors.accent) }
    if (this.generationError !== '') {
      Text(this.generationError).fontSize(13).fontColor(this.uiColors.danger).width('100%')
      Button('重新读取生成设置').attributeModifier(new ActionButtonStyle(this.uiColors)).width('100%')
        .onClick((): void => { this.loadGenerationSettings(); })
    }
    Column({ space: 14 }) {
      Text('回复长度上限 · Token').fontSize(15).fontColor(this.uiColors.textPrimary).width('100%')
      TextInput({ text: String(this.generationDraft.max_tokens) }).type(InputType.Number)
        .attributeModifier(new InputFieldStyle(this.uiColors)).id('chat-output-limit')
        .onChange((value: string): void => { this.generationDraft.max_tokens = Number(value); })
      Text('上下文长度预算 · 输入 Token（本地估算）').fontSize(15).fontColor(this.uiColors.textPrimary).width('100%')
      TextInput({ text: String(this.generationDraft.context_tokens) }).type(InputType.Number)
        .attributeModifier(new InputFieldStyle(this.uiColors)).id('chat-context-limit')
        .onChange((value: string): void => { this.generationDraft.context_tokens = Number(value); })
      Text('输入预算 1024–1048576；输出上限 1–131072，实际受模型限制。超过输入预算会提示精简，不静默截掉历史。模型总窗口通常需同时容纳输入与输出。')
        .fontSize(12).fontColor(this.uiColors.textSecondary).lineHeight(20).width('100%')
      SettingsPicker({ title: '推理强度', marker: 'chat-reasoning-effort', selectedId: this.generationDraft.reasoning_effort,
        options: [{ id: 'auto', label: '模型默认' }, { id: 'low', label: '低' },
          { id: 'medium', label: '中' }, { id: 'high', label: '高' }],
        onSelect: (id: string): void => { this.generationDraft.reasoning_effort = id; } })
      Text('仅支持推理的模型生效；不同服务商可能映射为预算或忽略，不支持时请选“模型默认”。高强度可能增加延迟与 Token，部分模型的回复上限包含思考 Token。')
        .fontSize(12).fontColor(this.uiColors.textSecondary).lineHeight(20).width('100%')
      Text('温度 · ' + this.generationDraft.temperature.toFixed(2)).fontSize(15).fontColor(this.uiColors.textPrimary).width('100%')
      Slider({ value: this.generationDraft.temperature, min: 0, max: 2, step: 0.05 }).width('100%')
        .onChange((value: number): void => { this.generationDraft.temperature = value; })
      Text('Top‑P · ' + this.generationDraft.top_p.toFixed(2)).fontSize(15).fontColor(this.uiColors.textPrimary).width('100%')
      Slider({ value: this.generationDraft.top_p, min: 0, max: 1, step: 0.05 }).width('100%')
        .onChange((value: number): void => { this.generationDraft.top_p = value; })
      this.generationSwitch('自动跟随最新消息', this.generationDraft.auto_scroll_chat_to_bottom,
        (value: boolean): void => { this.generationDraft.auto_scroll_chat_to_bottom = value; })
      this.generationSwitch('删除消息前确认', this.generationDraft.confirm_message_delete,
        (value: boolean): void => { this.generationDraft.confirm_message_delete = value; })
      this.generationSwitch('去除发送内容首尾空白', this.generationDraft.trim_spaces,
        (value: boolean): void => { this.generationDraft.trim_spaces = value; })
      Button(this.generationSaving ? '保存中…' : '保存生成设置（所有聊天）')
        .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary)).width('100%').id('chat-generation-save')
        .enabled(!this.streaming && !this.preparingGeneration).onClick((): void => { this.saveGenerationSettings(); })
    }.width('100%').enabled(!this.generationLoading && !this.generationSaving && this.generationSnapshot !== undefined)
  }

  @Builder
  generationSwitch(label: string, value: boolean, changed: (enabled: boolean) => void) {
    Row({ space: 12 }) {
      Text(label).fontSize(15).fontColor(this.uiColors.textPrimary).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: value }).selectedColor(this.uiColors.accent).accessibilityText(label).onChange(changed)
    }.width('100%').constraintSize({ minHeight: 48 })
  }

  @Builder
  chatSettingsContent() {
    Button('返回会话列表', { type: ButtonType.Normal })
      .attributeModifier(new ActionButtonStyle(this.uiColors)).width('100%').constraintSize({ minHeight: 48 })
      .id('chat-settings-back').onClick((): void => { this.activePanel = 'conversations'; })
    Row({ space: 16 }) {
      Column({ space: 6 }) {
        Text('显示每次回复的 Token 用量').fontSize(16).fontColor(this.uiColors.textPrimary)
        Text('在 AI 回复下显示输入、输出与合计').fontSize(13).fontColor(this.uiColors.textSecondary)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: this.showTokenUsage }).selectedColor(this.uiColors.accent)
        .accessibilityText('显示每次回复的 Token 用量').id('chat-token-usage-toggle')
        .onChange((enabled: boolean): void => { PersonalizationStore.set(CHAT_TOKEN_USAGE_KEY, enabled); })
    }.width('100%').padding({ top: 8, bottom: 8 })
    this.generationSwitch('显示模型返回的思考过程', this.showReasoning,
      (value: boolean): void => { PersonalizationStore.set(CHAT_REASONING_KEY, value); })
    Text('仅显示接口实际返回的 reasoning 或思考摘要，不获取隐藏思维链。显示开关不改变模型推理能力，也不会节省已发生的推理费用；思考内容不回传为后续上下文。部分接口需要先选择非默认推理强度才返回思考内容。')
      .fontSize(12).fontColor(this.uiColors.textSecondary).lineHeight(20).width('100%')
    this.generationControls()
    Text('显示设置对所有聊天生效，并在重启后保留。关闭只隐藏用量，不删除已经记录的数据。')
      .fontSize(13).fontColor(this.uiColors.textSecondary).lineHeight(21).width('100%')
    Text('仅记录服务商实际返回的用量，不用字数估算；旧记录、开场白或接口未返回时显示“未提供”，不会算作 0。输入包含本次提交的历史与背景。')
      .fontSize(13).fontColor(this.uiColors.textSecondary).lineHeight(21).width('100%')
    Text('这里显示正文回复请求的用量，不含单独生成剧情选项、摘要等额外请求；Token 数量不等于实际扣费。中断请求的已返回用量会标记为未完整结束。')
      .fontSize(13).fontColor(this.uiColors.textSecondary).lineHeight(21).width('100%')
  }

  @Builder
  modelSheet() {
    SettingsPage({ providerOnly: true, embedded: true, initialProviderId: this.providerId,
      readOnly: this.streaming || this.preparingGeneration,
      onEmbeddedBackHandler: (handler: () => boolean): void => { this.modelBackHandler = handler; },
      onClose: (): void => { this.panel.close(); },
      onProviderChanged: (): void => { this.loadCustomConfig(); } })
  }

  @Builder
  messageEditorContent() {
    TextArea({ text: this.editText, placeholder: '消息正文' })
      .fontSize(16).fontColor(this.uiColors.textPrimary).placeholderColor(this.uiColors.textSecondary)
      .height(240).width('100%').padding(16)
      .backgroundColor(this.uiColors.bgSurfaceHigh).borderRadius(20)
      .onChange((value: string): void => { this.editText = value; })
    .attributeModifier(new TextAreaFieldStyle(this.uiColors))
      if (this.errorText !== '') {
      ErrorBannerView({ text: this.errorText })
    }
  }

  @Builder
  messageEditorActions() {
    Row({ space: 12 }) {
      Button('取消', { type: ButtonType.Normal }).layoutWeight(1).constraintSize({ minHeight: 48 })
        .fontColor(this.uiColors.textPrimary).backgroundColor(this.uiColors.headerButtonTint)
        .border({ width: 0.8, color: this.uiColors.glassEdge })
        .stateStyles({ normal: touchFeedbackNormal, pressed: touchFeedbackPressed })

        .onClick((): void => { this.closeMessageEditor(); })
      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button(this.busy ? '保存中…' : '保存', { type: ButtonType.Normal }).layoutWeight(1).constraintSize({ minHeight: 48 })
        .fontColor(this.uiColors.textInverse).backgroundColor(this.uiColors.accent).enabled(!this.busy)
        .stateStyles({ normal: touchFeedbackNormal, pressed: touchFeedbackPressed })

        .onClick((): void => { this.saveEdit(); })
    .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      }.width('100%')
  }

  @Builder
  messageEditorSheet() {
    ChatPanel({ title: '编辑消息', subtitle: `第 ${this.editIndex + 1} 条消息`, hasFooter: true, managedLayout: true,
      onContentHeight: (height: number): void => { this.panel.fitContentHeight(height); },
      onClose: (): void => { this.closeMessageEditor(); },
      footer: (): void => { this.messageEditorActions(); },
      content: (): void => { this.messageEditorContent(); } })
  }

  @Builder
  messageMenu(message: ChatMessageDto, index: number) {
    Scroll() {
      Column() {
        LiquidMenuItem({ label: '编辑这条消息', onSelect: (): void => {
          this.menuOrigin.select((): void => { this.beginMessageEdit(message, index, 'chat-message-more-' + index); });
        } })
        LiquidMenuItem({ label: '从这里重新生成', onSelect: (): void => {
          this.menuOrigin.select((): void => { this.regenerateFrom(index); });
        } })
        LiquidMenuItem({ label: '删除这条消息', destructive: true, onSelect: (): void => {
          this.menuOrigin.select((): void => { this.deleteMessage(index); });
        } })
      }
      .width('100%').padding(8)
      .onAreaChange((_previous: Area, area: Area): void => { this.menuOrigin.fitMenuHeight(Number(area.height)); })
    }
    .width('100%').height('100%').scrollBar(BarState.Off)
  }

  private syncDock(): void {
    this.dock.preventBack = this.replyNeedsSave || this.committingReply || this.preparingGeneration;
    this.dock.text = this.inputText;
    this.dock.streaming = this.streaming;
    this.dock.available = this.openChat !== null && !this.preparingGeneration && !this.committingReply && !this.replyNeedsSave;
    this.dock.attachments = this.attachedImages.length;
    this.dock.summaryVisible = this.summaryVisible;
    this.dock.searchOpen = this.searchOpen;
  }

  private bindDock(): void {
    this.syncDock();
    this.dock.changeText = (value: string): void => { this.inputText = value; };
    this.dock.attach = (): void => { this.attachImage(); };
    this.dock.selectModel = (): void => { this.openPanel('model', 'chat-tools-anchor'); };
    this.dock.compactContext = (): void => { this.openPanel('context', 'chat-tools-anchor'); };
    this.dock.toggleSearch = (): void => { this.toggleSearchPanel('chat-tools-anchor'); };
    this.dock.toggleSummary = (): void => { this.toggleSummaryPanel('chat-tools-anchor'); };
    this.dock.scrollToLatest = (): void => { this.scrollToBottom(); };
    this.dock.submit = (): void => {
      if (this.streaming) {
        const choices: boolean = this.generatingChoiceStream;
        this.cancelActiveStream();
        this.statusText = '已停止';
        if (choices) {
          this.streamText = '';
          this.choicesError = '已停止准备选项，可以重试或直接输入回复。';
        } else if (this.streamText.trim() !== '') {
          this.persistNarrativeReply();
        } else {
          this.refreshStoryChoices();
        }
      } else {
        this.send();
      }
    };
  }

  private toggleSearchPanel(sourceId: string): void {
    if (this.searchOpen) { this.panel.close(); return; }
    this.searchOpen = true;
    this.openPanel('search', sourceId);
  }

  private toggleSummaryPanel(sourceId: string): void {
    if (this.summaryVisible) { this.panel.close(); return; }
    this.summaryVisible = true;
    this.openPanel('summary', sourceId);
    if (this.openChat !== null) {
      this.loadSummary(this.openChat.character_name, this.openChat.file_name);
    }
  }

  private chatMenuLabels(): string[] {
    return ['切换会话', '故事与聊天模式', '聊天生成设置', '模型设置',
      this.summaryVisible ? '收起摘要' : '查看摘要', this.searchOpen ? '关闭搜索' : '搜索消息', '重新生成回复', '查看聊天上下文'];
  }

  @Builder
  chatMenu() {
    Scroll() {
      Column() {
        LiquidMenuItem({ label: '切换会话', onSelect: (): void => {
          this.menuOrigin.select((): void => { this.openPanel('conversations', 'chat-options-anchor'); });
        } })
        LiquidMenuItem({ label: '故事与聊天模式', available: this.openChat !== null && !this.streaming && !this.preparingGeneration && !this.busy && !this.committingReply && !this.replyNeedsSave,
          onSelect: (): void => { this.menuOrigin.select((): void => {
            if (this.openChat !== null) {
              StoryIntent.request(this.openChat.character_name, this.displayName(this.openChat.character_name), '', this.openChat.file_name);
            }
          }); } })
        LiquidMenuItem({ label: '聊天生成设置', onSelect: (): void => {
          this.menuOrigin.select((): void => { this.openPanel('chat-settings', 'chat-options-anchor'); });
        } })
        LiquidMenuItem({ label: '模型设置', onSelect: (): void => {
          this.menuOrigin.select((): void => { this.openPanel('model', 'chat-options-anchor'); });
        } })
        LiquidMenuItem({ label: this.summaryVisible ? '收起摘要' : '查看摘要', onSelect: (): void => {
          this.menuOrigin.select((): void => { this.toggleSummaryPanel('chat-options-anchor'); });
        } })
        LiquidMenuItem({ label: this.searchOpen ? '关闭搜索' : '搜索消息', onSelect: (): void => {
          this.menuOrigin.select((): void => { this.toggleSearchPanel('chat-options-anchor'); });
        } })
        LiquidMenuItem({ label: '重新生成回复', available: this.messages.length > 0 && !this.streaming,
          onSelect: (): void => { this.menuOrigin.select((): void => { this.retry(); }); } })
        LiquidMenuItem({ label: '查看聊天上下文', available: this.openChat !== null,
          onSelect: (): void => { this.menuOrigin.select((): void => { this.previewPrompt(); }); } })
      }
      .width('100%').padding(8)
      .onAreaChange((_previous: Area, area: Area): void => { this.menuOrigin.fitMenuHeight(Number(area.height)); })
    }
    .width('100%').height('100%').scrollBar(BarState.Off)
  }

  @Builder
  chatMenuCover() {
    Stack() {
      OriginPanel({ state: this.menuOrigin, content: (): void => { this.chatMenu(); } })
    }
    .width('100%').height('100%')
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }

  @Builder
  messageMenuCover(message: ChatMessageDto, index: number) {
    Stack() {
      OriginPanel({ state: this.menuOrigin, content: (): void => { this.messageMenu(message, index); } })
    }
    .width('100%').height('100%')
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }

  private async loadAvatarRoot(): Promise<void> {
    try {
      const paths: RuntimePathsDto = await Backend.getRuntimePaths();
      this.avatarRoot = paths.data_root.replace(/\/$/, '');
    } catch (error) {
      this.avatarRoot = '';
    }
  }

  private avatarSource(name: string): string {
    if (this.avatarRoot === '') { return ''; }
    for (const character of this.characters) {
      if (character.name === name || this.chatKey(character) === name) {
        const avatar: string = character.avatar || '';
        if (avatar === '' || avatar === '.' || avatar === '..' ||
          avatar.includes('/') || avatar.includes('\\')) { return ''; }
        return `file://${this.avatarRoot}/default-user/characters/${encodeURIComponent(avatar)}`;
      }
    }
    return '';
  }

  private messageName(message: ChatMessageDto): string {
    if (message.is_user) { return '你'; }
    if (message.is_system) { return '系统'; }
    return this.displayName(message.name);
  }

  @Builder
  chatHeader() {
    Row({ space: 8 }) {
      HeaderAction({ icon: $r('app.media.icon_back'), label: '返回', refresh: false,
        onAction: async (): Promise<void> => {
          if (this.replyNeedsSave || this.committingReply || this.preparingGeneration) {
            this.getUIContext().getPromptAction().showToast({ message: '请先保存已收到的回复，再离开对话' });
            return;
          }
          this.cancelActiveStream(); ROOT_PATH_STACK.pop();
        } })
      Button({ type: ButtonType.Normal }) {
        Row({ space: 8 }) {
          IdentityAvatar({
            name: this.openChat === null ? '聊' : this.displayName(this.openChat.character_name),
            source: this.openChat === null ? '' : this.avatarSource(this.openChat.character_name),
            diameter: 32
          })
          Column({ space: 3 }) {
            Text(this.openChat === null ? '开启对话' : this.displayName(this.openChat.character_name))
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.uiColors.textPrimary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Row({ space: 4 }) {
              BrandIcon({ model: this.model, diameter: 14 })
              Text(this.model || '选择模型')
                .fontSize(12)
                .fontColor(this.uiColors.textSecondary)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
              Image($r('app.media.icon_chevron'))
                .width(12)
                .height(12)
                .rotate({ angle: 90 })
                .colorFilter(iconTint(this.uiColors.textSecondary))
            }
            .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .height(52)
      .padding({ left: 4, right: 4 })
      .borderRadius(16)
      .backgroundColor(Color.Transparent)
      .accessibilityText(`${this.openChat === null ? '开启对话' : this.displayName(this.openChat.character_name)}，${this.model || '选择模型'}，模型设置`)
      .id('chat-model-anchor')
      .stateStyles({ normal: touchFeedbackNormal, pressed: touchFeedbackPressed })

      .onClick(() => { this.openPanel('model', 'chat-model-anchor'); })
      HeaderAction({ icon: $r('app.media.icon_chat_add'), label: '切换或新建会话', refresh: false,
        marker: 'chat-conversations-anchor',
        onAction: async (): Promise<void> => { this.openPanel('conversations', 'chat-conversations-anchor'); } })
      HeaderAction({ icon: $r('app.media.icon_more'), label: '聊天选项', refresh: false,
        marker: 'chat-options-anchor', onAction: async (): Promise<void> => {
          this.menuOrigin.openMenu(this.getUIContext(), 'chat-options-anchor', this.chatMenuLabels().length * 48 + 16,
            this.chatMenuLabels());
        } })
      .bindContentCover(this.menuOrigin.presented && this.menuOrigin.sourceId === 'chat-options-anchor', this.chatMenuCover(), {
        modalTransition: ModalTransition.NONE, backgroundColor: Color.Transparent,
        onWillDismiss: (): void => { this.menuOrigin.close(); },
        onDisappear: (): void => { this.menuOrigin.dismissed(); }
      })
    }
    .width('100%')
    .height(72)
    .padding({ left: 12, right: 12 })
  }

  @Builder
  messageActions(message: ChatMessageDto, index: number) {
    Row({ space: 2 }) {
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.icon_edit'))
          .width(18)
          .height(18)
          .colorFilter(iconTint(this.uiColors.textSecondary))
      }
      .width(44)
      .height(44)
      .backgroundColor(Color.Transparent)
      .accessibilityText('编辑这条消息')
      .id('chat-message-edit-' + index)
      .stateStyles({ normal: touchFeedbackNormal, pressed: touchFeedbackPressed })

      .onClick(() => {
        this.beginMessageEdit(message, index, 'chat-message-edit-' + index);
      })
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.icon_more'))
          .width(18)
          .height(18)
          .colorFilter(iconTint(this.uiColors.textSecondary))
      }
      .width(44)
      .height(44)
      .backgroundColor(Color.Transparent)
      .accessibilityText('更多消息操作')
      .id('chat-message-more-' + index)
      .stateStyles({ normal: touchFeedbackNormal, pressed: touchFeedbackPressed })

      .onClick((): void => { this.menuOrigin.openMenu(this.getUIContext(), 'chat-message-more-' + index, 160, ['从这里重新生成']); })
      .bindContentCover(this.menuOrigin.presented && this.menuOrigin.sourceId === 'chat-message-more-' + index,
        this.messageMenuCover(message, index), {
        modalTransition: ModalTransition.NONE, backgroundColor: Color.Transparent,
        onWillDismiss: (): void => { this.menuOrigin.close(); },
        onDisappear: (): void => { this.menuOrigin.dismissed(); }
      })
      if (!message.is_user) {
        Blank()
        Text(message.is_system ? '系统' : 'AI')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.uiColors.textSecondary)
          .margin({ right: 8 })
      }
    }
    .width(message.is_user ? 92 : '100%')
  }

  private usageCounter(value: number | undefined): string {
    return typeof value === 'number' && Number.isSafeInteger(value) && value >= 0 ? String(value) : '未提供';
  }

  private messageUsageText(message: ChatMessageDto): string {
    const usage: TokenUsage | undefined = message.extra?.['harmony_token_usage'] as TokenUsage | undefined;
    if (usage === undefined || usage === null || typeof usage !== 'object') { return 'Token：未提供'; }
    return 'Token · 输入 ' + this.usageCounter(usage.prompt_tokens) + ' · 输出 ' + this.usageCounter(usage.completion_tokens) +
      ' · 合计 ' + this.usageCounter(usage.total_tokens) + (message.extra?.['harmony_usage_complete'] === false ? ' · 未完整结束' : '');
  }

  private messageReasoning(message: ChatMessageDto): string {
    const reasoning: ESObject = message.extra?.['reasoning'];
    return typeof reasoning === 'string' ? reasoning : '';
  }

  @Builder
  reasoningView(text: string, expanded: boolean, truncated: boolean, toggle: () => void) {
    Column({ space: 8 }) {
      Button(expanded ? '收起思考过程' : '展开思考过程', { type: ButtonType.Normal })
        .attributeModifier(new ActionButtonStyle(this.uiColors)).constraintSize({ minHeight: 48 }).width('100%').onClick(toggle)
      if (expanded) {
        Text(text || '接口尚未返回思考内容').fontSize(13).fontColor(this.uiColors.textSecondary).lineHeight(22).width('100%')
        if (truncated) { Text('思考内容过长，仅保留前 60000 字符。').fontSize(12).fontColor(this.uiColors.textSecondary) }
      }
    }.width('100%')
  }

  @Builder
  messageCard(message: ChatMessageDto, index: number) {
    if (RpgThemes.find(this.backgroundId) !== undefined) {
      this.rpgMessageCard(message, index)
    } else {
      this.standardMessageCard(message, index)
    }
  }

  @Builder
  rpgMessageCard(message: ChatMessageDto, index: number) {
    Column({ space: 12 }) {
      Row({ space: 11 }) {
        if (message.is_user) { Blank() }
        IdentityAvatar({ name: message.is_user ? (this.userName || '你') : this.messageName(message),
          source: message.is_user ? this.userAvatar : (message.is_system ? '' : this.avatarSource(message.name)),
          diameter: message.is_user ? 28 : 44 })
        Column({ space: 4 }) {
          Text(message.is_user ? (this.userName || '你') : this.messageName(message))
            .fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.uiColors.textPrimary)
          if (!message.is_user) {
            Text(message.is_system ? '故事旁白' : '旅伴 · 对话')
              .fontSize(11).fontColor(this.uiColors.textSecondary)
          }
        }.alignItems(HorizontalAlign.Start).layoutWeight(message.is_user ? 0 : 1)
        if (!message.is_user && this.backgroundId === 'rpg_sakura') {
          Text('物\n語').fontSize(10).fontColor(this.uiColors.accent).padding(4)
            .border({ width: 0.8, color: this.uiColors.accent }).borderRadius(2)
            .accessibilityLevel('no')
        }
      }.width('100%')
      Text(message.mes)
        .fontSize(this.readingSize).lineHeight(this.readingSize * this.readingLine)
        .fontFamily(ReadingPreferences.fontFamily(this.readingFont))
        .fontColor(message.is_user ? this.uiColors.textInverse : this.uiColors.textPrimary)
        .copyOption(CopyOptions.LocalDevice)
        .padding({ left: this.readingInset, right: this.readingInset, top: 11, bottom: 11 })
        .constraintSize({ maxWidth: message.is_user ? '94%' : '100%' })
        .width(message.is_user ? undefined : '100%')
        .attributeModifier(new RpgBubbleStyle(this.backgroundId, this.uiColors, message.is_user, this.focusIndex === index))
      if (this.showReasoning && !message.is_user && !message.is_system) {
        if (this.messageReasoning(message) !== '') {
          this.reasoningView(this.messageReasoning(message), this.reasoningExpanded === index,
            message.extra?.['harmony_reasoning_truncated'] === true,
            (): void => { this.reasoningExpanded = this.reasoningExpanded === index ? -1 : index; })
        } else {
          Text('思考过程：接口未提供').fontSize(12).fontColor(this.uiColors.textSecondary).width('100%')
        }
      }
      if (this.showTokenUsage && !message.is_user && !message.is_system) {
        Text(this.messageUsageText(message)).fontSize(12).lineHeight(19)
          .fontColor(this.uiColors.textSecondary).width('100%').id('chat-message-usage-' + index)
      }
      this.messageActions(message, index)
    }
    .width('100%').padding(message.is_user ? 0 : 8)
    .alignItems(message.is_user ? HorizontalAlign.End : HorizontalAlign.Start)
    .attributeModifier(new RpgConversationStyle(message.is_user ? '' : this.backgroundId, this.uiColors))
    .id('rpg-message-' + index)
  }

  @Builder
  standardMessageCard(message: ChatMessageDto, index: number) {
    Column({ space: 10 }) {
      Row({ space: 9 }) {
        if (message.is_user) {
          Blank()
          Text(this.userName || '你')
            .fontSize(13)
            .fontColor(this.uiColors.textSecondary)
          IdentityAvatar({ name: this.userName || '你', source: this.userAvatar, diameter: 28 })
        } else {
          IdentityAvatar({
            name: this.messageName(message),
            source: message.is_system ? '' : this.avatarSource(message.name),
            diameter: 36
          })
          Text(this.messageName(message))
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.uiColors.textPrimary)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .width('100%')
      if (message.is_user) {
        Text(message.mes)
          .fontSize(this.readingSize)
          .lineHeight(this.readingSize * this.readingLine)
          .fontFamily(ReadingPreferences.fontFamily(this.readingFont))
          .fontColor(this.uiColors.textInverse)
          .copyOption(CopyOptions.LocalDevice)
          .padding({ left: this.readingInset, right: this.readingInset, top: 13, bottom: 13 })
          .constraintSize({ maxWidth: '94%' })
          .backgroundColor(this.uiColors.accent)
          .borderRadius({ topLeft: RpgThemes.radius(22), topRight: RpgThemes.radius(22),
            bottomLeft: RpgThemes.radius(22), bottomRight: Math.min(7, RpgThemes.radius(7)) })
          .border({ width: this.focusIndex === index ? 2 : 0, color: this.uiColors.textPrimary })
          .attributeModifier(new RpgBubbleStyle(this.backgroundId, this.uiColors, true, this.focusIndex === index))
        this.messageActions(message, index)
      } else {
        Column({ space: 10 }) {
          Text(message.mes)
            .fontSize(this.readingSize)
            .lineHeight(this.readingSize * this.readingLine)
            .fontFamily(ReadingPreferences.fontFamily(this.readingFont))
            .fontColor(this.uiColors.textPrimary)
            .copyOption(CopyOptions.LocalDevice)
            .width('100%')
            .textAlign(TextAlign.Start)
          if (this.showReasoning && !message.is_system) {
            if (this.messageReasoning(message) !== '') {
              this.reasoningView(this.messageReasoning(message), this.reasoningExpanded === index,
                message.extra?.['harmony_reasoning_truncated'] === true,
                (): void => { this.reasoningExpanded = this.reasoningExpanded === index ? -1 : index; })
            } else {
              Text('思考过程：接口未提供').fontSize(12).fontColor(this.uiColors.textSecondary).width('100%')
            }
          }
          if (this.showTokenUsage && !message.is_system) {
            Text(this.messageUsageText(message)).fontSize(12).fontColor(this.uiColors.textSecondary)
              .lineHeight(19).width('100%').id('chat-message-usage-' + index)
          }
          this.messageActions(message, index)
        }
        .width('100%')
        .padding({ left: this.readingInset, right: this.readingInset, top: 18, bottom: 4 })
        .backgroundColor(message.is_system ? this.uiColors.bgSurfaceHigh : this.uiColors.bgSurface)
        .borderRadius(RpgThemes.radius(24))
        .border({ width: this.focusIndex === index ? 1.5 : RpgThemes.borderWidth(0.8),
          color: this.focusIndex === index ? this.uiColors.accent : this.uiColors.borderSubtle })
        .attributeModifier(new RpgBubbleStyle(this.backgroundId, this.uiColors, false, this.focusIndex === index))
      }
    }
    .width('100%')
    .alignItems(message.is_user ? HorizontalAlign.End : HorizontalAlign.Start)
    .transition(this.reduceMotion ? TransitionEffect.IDENTITY : TransitionEffect.OPACITY)
  }

  @Builder
  streamingCard() {
    Column({ space: 10 }) {
      Row({ space: 9 }) {
        IdentityAvatar({
          name: this.openChat === null ? 'AI' : this.displayName(this.openChat.character_name),
          source: this.openChat === null ? '' : this.avatarSource(this.openChat.character_name),
          diameter: 36
        })
        Text(this.openChat === null ? 'AI' : this.displayName(this.openChat.character_name))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.uiColors.textPrimary)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      Column({ space: 12 }) {
        if (this.showReasoning && this.streamReasoning !== '') {
          Text('模型返回的思考过程').fontSize(13).fontColor(this.uiColors.accent).width('100%')
          Text(this.streamReasoning.substring(Math.max(0, this.streamReasoning.length - 1200)))
            .fontSize(13).fontColor(this.uiColors.textSecondary).lineHeight(22).width('100%')
          Text('生成时只显示最近一段，完成后可展开已保留内容。').fontSize(12).fontColor(this.uiColors.textSecondary)
        }
        StreamingText({ text: this.visibleStreamText(), active: this.streaming,
          onHeightChanged: (): void => {
            if (this.chatPreferences.auto_scroll_chat_to_bottom && this.followLatest) { this.messageViewportChanged(); }
          } })
        if (this.streaming && this.streamText !== '') {
          Text('正在回应…')
            .fontSize(11)
            .fontColor(this.uiColors.accent)
            .width('100%')
        }
      }
      .width('100%')
      .padding({ left: this.readingInset, right: this.readingInset, top: 14, bottom: 14 })
      .backgroundColor(this.uiColors.bgSurface)
      .borderRadius(24)
      .attributeModifier(new SurfaceStyle(this.uiColors, 24))
      .border({ width: 0.8, color: this.uiColors.borderSubtle })
      .attributeModifier(new RpgBubbleStyle(this.backgroundId, this.uiColors, false))
    }
    .width('100%')
    .padding(RpgThemes.find(this.backgroundId) !== undefined ? 8 : 0)
    .attributeModifier(new RpgConversationStyle(this.backgroundId, this.uiColors))
  }

  @Builder
  searchPanelContent() {
    Column({ space: 12 }) {
      Row({ space: 6 }) {
          TextInput({ placeholder: '搜这条聊天里的内容', text: this.searchQuery })
            .fontSize(15)
            .fontColor(this.uiColors.textPrimary)
            .placeholderColor(this.uiColors.textSecondary)
            .height(44)
            .layoutWeight(1)
            .backgroundColor(this.uiColors.bgSurfaceHigh)
            .onChange((value: string) => {
              this.searchQuery = value;
            })
            .onSubmit(() => {
              this.runChatSearch();
            })
          .attributeModifier(new InputFieldStyle(this.uiColors))
      Button('搜', { type: ButtonType.Normal })
            .fontSize(Typography.micro)
            .fontColor(this.uiColors.textInverse)
            .backgroundColor(this.uiColors.accent)
            .height(44)
            .enabled(!this.busy)
            .stateStyles({ normal: touchFeedbackNormal, pressed: touchFeedbackPressed })

            .onClick(() => {
              this.runChatSearch();
            })
      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
      .width('100%')
      if (this.searchNote !== '') {
        Text(this.searchNote).fontSize(Typography.micro).fontColor(this.uiColors.textSecondary).width('100%')
      }
      if (this.searchHits.length > 0) {
        Column({ space: 2 }) {
          ForEach(this.searchHits, (hit: ESObject) => {
            Text(this.hitLabel(hit))
              .fontSize(Typography.micro)
              .fontColor(this.uiColors.textPrimary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor(this.focusIndex === this.hitIndex(hit) ? this.uiColors.accentContainer : this.uiColors.bgSurfaceHigh)
              .borderRadius(6)
              .stateStyles({ normal: touchFeedbackNormal, pressed: touchFeedbackPressed })

              .onClick(() => {
                this.focusIndex = this.hitIndex(hit);
                this.statusText = `定位到第 ${this.hitIndex(hit)} 条`;
                this.panel.close();
              })
          }, (hit: ESObject) => `${this.hitIndex(hit)}-${(hit.snippet as string) ?? ``}`)
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  private chatHudInset(): number {
    return Math.max(0, this.bottomInset - 12);
  }

  private chatBottomReserve(): number {
    return (this.story.mode === 'world' ? this.chatHudInset() + 56 : this.bottomInset + 8) +
      (this.errorText !== '' || this.statusText.includes('失败') ? 72 : 0);
  }

  private chatEdgeStops(): FractionStop[] {
    const height: number = Math.max(this.topInset + 97, this.messageViewportHeight);
    return [[1, 0], [0.85, (this.topInset + 24) / height],
      [0.35, (this.topInset + 60) / height], [0, (this.topInset + 96) / height], [0, 1]];
  }

  @Builder
  buildSurfaceContent() {
    Stack({ alignContent: Alignment.Bottom }) {
      List({ space: 24, scroller: this.msgScroller }) {
          if (RpgThemes.find(this.backgroundId) !== undefined) {
            ListItem() {
              Row({ space: 8 }) {
                Text(RpgThemes.find(this.backgroundId)?.label ?? '').fontSize(11).fontColor(this.uiColors.accent)
                Blank()
                Text('让故事继续').fontSize(11).fontColor(this.uiColors.textSecondary)
              }.width('100%').padding({ left: 4, right: 4 }).id('rpg-theme-banner')
            }
          }
          if (this.messages.length === 0 && !this.streaming) {
            ListItem() {
              EmptyHint(this.openChat === null ? '先选择一段故事' : '把第一句话留在这里',
                this.openChat === null ? '在右上角菜单中选择或新建对话。' : '从一个问候开始，也可以开启一场冒险。', this.uiColors)
            }
          }
          LazyForEach(this.messageSource, (row: ChatMessageRow) => {
            ListItem() { this.messageCard(row.message, row.index) }
          }, (row: ChatMessageRow): string => row.key)
          ListItem() {
          Column({ space: 16 }) {
          if (this.latestChoices().length > 0 && !this.streaming && !this.preparingGeneration && !this.committingReply && this.streamText === '') {
            Column({ space: 10 }) {
              Text('接下来，你想…').fontSize(14).fontColor(this.uiColors.textSecondary).width('100%')
              ForEach(this.latestChoices(), (choice: StoryOption, index: number) => {
                Button({ type: ButtonType.Normal }) {
                  Column({ space: 6 }) {
                    Text(choice.label).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.uiColors.accent)
                      .width('100%').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text('“' + choice.reply + '”').fontSize(15).fontColor(this.uiColors.textPrimary).width('100%')
                  }.width('100%').alignItems(HorizontalAlign.Start)
                }
                  .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
                  .width('100%').height('auto').constraintSize({ minHeight: 64 }).padding(14)
                  .enabled(!this.busy && !this.preparingGeneration)
                  .id('story-choice-' + index).accessibilityText(choice.label + '，发送：' + choice.reply)
                  .onClick((): void => { this.chooseStoryOption(choice); })
              }, (choice: StoryOption) => choice.reply)
              Text('点击只发送引号中的实际发言；也可以自由输入。').fontSize(12).fontColor(this.uiColors.textSecondary)
            }.width('100%')
          }
          if (this.choicesLoading) {
            Row({ space: 10 }) {
              LoadingProgress().width(20).height(20).color(this.uiColors.accent)
              Text('正在准备本轮选项…').fontSize(14).fontColor(this.uiColors.textSecondary)
            }.width('100%').padding(12)
          }
          if (this.choicesError !== '' && !this.streaming && !this.committingReply) {
            Column({ space: 10 }) {
              Text(this.choicesError).fontSize(14).fontColor(this.uiColors.textSecondary).width('100%')
              Button('重试本轮选项').attributeModifier(new ActionButtonStyle(this.uiColors))
                .enabled(!this.busy && !this.preparingGeneration).onClick((): void => { this.refreshStoryChoices(); })
            }.width('100%')
          }
          if (!this.generatingChoiceStream && (this.streaming || this.streamText !== '' || (this.showReasoning && this.streamReasoning !== ''))) {
            this.streamingCard()
          }
          if (this.replyNeedsSave) {
            Button('保存已收到的回复').attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
              .enabled(!this.committingReply).onClick((): void => { this.persistNarrativeReply(); })
          }
          }.width('100%')
          }
      }
      .cachedCount(3)
      .contentStartOffset(this.topInset + 96)
      .contentEndOffset(this.chatBottomReserve())
      .padding({ left: 16, right: 16 })
      .width('100%').height('100%')
      .scrollBar(BarState.Off)
      .linearGradientBlur(glassEffect(GLASS_HEADER, this.blurRadius, this.immersiveLevel, this.uiColors).radius ?? 0, {
        fractionStops: this.chatEdgeStops(), direction: GradientDirection.Bottom
      })
      .edgeEffect(EdgeEffect.Spring, SCROLL_EDGE_OPTIONS)
      .nestedScroll(SCROLL_NESTED_OPTIONS)
      .align(Alignment.Top)
      .onSizeChange((previous: SizeOptions, current: SizeOptions): void => {
        if (Number(previous.height) !== Number(current.height)) {
          this.messageViewportHeight = Math.max(1, Number(current.height));
          this.messageViewportChanged();
        }
      })
      .onWillScroll((_offset: number, _state: ScrollState, source: ScrollSource): void => {
        this.readingScroll = source !== ScrollSource.SCROLLER && source !== ScrollSource.SCROLLER_ANIMATION;
      })
      .onDidScroll((_offset: number, state: ScrollState): void => {
        if (this.readingScroll && state !== ScrollState.Idle) {
          this.followLatest = this.msgScroller.isAtEnd();
        }
      })
      .onScrollStop((): void => {
        if (this.readingScroll) { this.followLatest = this.msgScroller.isAtEnd(); }
      })
      Column({ space: 0 }) {
        if (this.errorText !== '' || this.statusText.includes('失败')) {
          Column() {
            ErrorBannerView({ text: this.errorText || this.statusText })
          }
          .padding({ left: 16, right: 16, bottom: 8 })
        }
        if (this.story.mode === 'world') {
          Column() {
            WorldStatusHud({ state: this.worldReport.state ?? emptyWorldState(), ready: this.worldReport.status === 'ready', busy: this.worldBusy,
              onDetails: (): void => { this.openWorldSidebar('status', undefined, 'chat-world-details'); },
              onInventory: (): void => { this.openWorldSidebar('inventory', undefined, 'chat-world-inventory'); } })
          }.width('100%').padding({ left: 16, right: 16 })
        }
      }.width('100%').padding({ bottom: this.story.mode === 'world' ? this.chatHudInset() : this.bottomInset }).align(Alignment.Bottom)
        .hitTestBehavior(HitTestMode.Transparent)
      if (this.story.mode === 'world') {
        WorldJournalDock({ onRight: this.journalOnRight(), busy: this.worldBusy,
          onSection: (section: string, onRight: boolean, sourceId: string): void => { this.openWorldSidebar(section, onRight, sourceId); } })
      }
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      RpgBackdrop()
      this.buildSurfaceContent()
      Column().width('100%').height(this.topInset + 96)
        .linearGradient({ direction: GradientDirection.Bottom,
          colors: [[Appearance.palette(this.backgroundId).fadeTop, 0],
            [Appearance.palette(this.backgroundId).fadeMiddle, 0.55],
            [Appearance.palette(this.backgroundId).fadeEnd, 1]] })
        .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      Column({ space: 0 }) {
        Column().height(this.topInset)
        this.chatHeader()
      }.width('100%').hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height('100%')
    .onAppear(() => {
      this.bindDock();
      this.loadAvatarRoot();
    })
    .backgroundColor(this.uiColors.bgBase)
    .bindContentCover($$this.panel.presented, this.chatPanelCover(), {
      modalTransition: ModalTransition.NONE, backgroundColor: Color.Transparent,
      onWillDismiss: (_action: DismissContentCoverAction): void => {
        if (this.activePanel === 'model' && this.modelBackHandler()) { return; }
        this.panel.close();
      }
    })
  }

  @Builder
  worldJournalCover() {
    WorldJournalSidebar({ panel: this.panel, onRight: this.worldSidebarRight, section: this.worldSidebarSection, report: this.worldReport, busy: this.worldBusy, error: this.worldError,
      canGenerate: !this.worldBusy && !this.worldItemBusy && !this.worldSettingsSaving && !this.streaming && !this.preparingGeneration && !this.replyNeedsSave && !this.committingReply,
      onGenerate: (): void => { this.generateWorld(); },
      canCancel: !this.worldApplying, onCancel: (): void => { this.cancelWorld(); },
      onClosed: (): void => { this.panelClosed(); },
      content: (): void => { this.worldJournalBody(); } })
  }

  // Native components must be created inside @Builder methods, not in inline BuilderParam arrows.
  @Builder
  worldJournalBody() {
    if (this.worldSidebarSection === 'settings') { this.worldStateContent('settings'); }
    else if (this.worldReport.state !== undefined) {
      WorldStatusDetails({ state: this.worldReport.state, section: this.worldSidebarSection,
        actionsAvailable: this.itemActionsAvailable(), onItemAction: (index: number, action: string): void => { this.selectWorldItem(index, action); } })
    }
  }

  @Builder
  chatPanelCover() {
    Stack() {
      if (this.activePanel.startsWith('world-')) { this.worldJournalCover() }
      else {
        OriginPanel({ state: this.panel, onClosed: (): void => { this.panelClosed(); },
          content: (): void => { this.activePanelContent(); } })
      }
    }
    .width('100%').height('100%')
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }

  @Builder
  activePanelContent() {
      if (this.activePanel === 'model') { this.modelSheet() }
      else if (this.activePanel === 'conversations') { this.conversationSheet() }
      else if (this.activePanel === 'context') {
        ChatPanel({ title: '精简上下文', subtitle: '保留原文，可恢复', managedLayout: true,
          onContentHeight: (height: number): void => { this.panel.fitContentHeight(height); },
          onClose: (): void => { this.panel.close(); }, content: (): void => { this.contextContent(); } })
      }
      else if (this.activePanel === 'world-state') {
        ChatPanel({ title: '创造模式', subtitle: '根据世界书与剧情生成', managedLayout: true,
          onContentHeight: (height: number): void => { this.panel.fitContentHeight(height); },
          onClose: (): void => { this.panel.close(); }, content: (): void => { this.worldStateContent(); } })
      }
      else if (this.activePanel === 'world-inventory') {
        ChatPanel({ title: '背包物品栏', subtitle: '人物携带物品、数量和用途', managedLayout: true,
          onContentHeight: (height: number): void => { this.panel.fitContentHeight(height); },
          onClose: (): void => { this.panel.close(); }, content: (): void => { this.worldStateContent('inventory'); } })
      }
      else if (this.activePanel === 'chat-settings') {
        ChatPanel({ title: '聊天生成设置', subtitle: '用量、思考、回复与上下文预算', managedLayout: true,
          onContentHeight: (height: number): void => { this.panel.fitContentHeight(height); },
          onClose: (): void => { this.panel.close(); },
          content: (): void => { this.chatSettingsContent(); } })
      }
      else if (this.activePanel === 'editor') { this.messageEditorSheet() }
      else if (this.activePanel === 'search') {
        ChatPanel({ title: '搜索消息', managedLayout: true, onContentHeight: (height: number): void => { this.panel.fitContentHeight(height); }, onClose: (): void => { this.panel.close(); },
          content: (): void => { this.searchPanelContent(); } })
      } else if (this.activePanel === 'summary') {
        ChatPanel({ title: '故事摘要', managedLayout: true, onContentHeight: (height: number): void => { this.panel.fitContentHeight(height); }, onClose: (): void => { this.panel.close(); },
          content: (): void => { this.summaryPanelContent(); } })
      } else if (this.activePanel === 'prompt') {
        ChatPanel({ title: '聊天上下文', subtitle: '仅本地预览，不发送给模型', managedLayout: true,
          onContentHeight: (height: number): void => { this.panel.fitContentHeight(height); },
          onClose: (): void => { this.panel.close(); },
          content: (): void => { this.promptPanelContent(); } })
      }
  }

  private async previewPrompt(): Promise<void> {
    if (this.openChat === null) { return; }
    this.promptPreview = '装配中…';
    this.openPanel('prompt', 'chat-options-anchor');
    try {
      const dto: GenerateRequestDto = await this.buildDto(this.openChat, this.messages);
      this.promptPreview = JSON.stringify({ model: dto.model, temperature: dto.temperature,
        top_p: dto.top_p, max_tokens: dto.max_tokens, messages: dto.messages }, null, 2);
    } catch (error) { this.promptPreview = '装配失败：' + (error as Error).message; }
  }

  @Builder
  promptPanelContent() {
    Text(this.promptPreview).fontSize(13).lineHeight(22).fontColor(this.uiColors.textPrimary)
      .width('100%').padding(12).copyOption(CopyOptions.LocalDevice)
  }

  @Builder
  summaryPanelContent() {
    Text(this.chatSummary || '这段故事还没有摘要').fontSize(16).lineHeight(28)
      .fontColor(this.uiColors.textPrimary).width('100%').padding(16)
      .backgroundColor(this.uiColors.bgSurface).borderRadius(18).attributeModifier(new SurfaceStyle(this.uiColors, 18))
  }
}
