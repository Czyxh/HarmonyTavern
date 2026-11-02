import { COLORS, ColorTokens } from '../theme/Tokens';
import { ActionButtonStyle, ActionTone } from '../theme/ControlStyles';
import { SurfaceStyle } from '../theme/SurfaceStyles';
import { PageHeader } from '../components/PageHeader';
import { HeaderAction } from '../components/HeaderAction';
import { ChatDock, ChatDockState } from '../components/ChatDock';
import { ErrorBannerView } from '../components/Builders';
import { Backend } from '../backend/Backend';
import { SettingsChoice, SettingsPicker } from '../components/SettingsPicker';
import { CharacterDto, ChatMessageDto, GenerateRequestDto } from '../backend/Types';
import { GroupSession, GroupSessionData, GroupConversationIntent } from '../backend/GroupSession';
import { NativeSettings } from '../backend/NativePreferences';
import { ProviderPreferences, ProviderSecretState } from '../backend/ProviderCatalog';
import { ROOT_PATH_STACK } from '../nav/RootNav';
import { ReadingPreferences, READING_SIZE_KEY, READING_LINE_KEY, READING_FONT_KEY, READING_INSET_KEY } from '../theme/ReadingPreferences';
import { StreamingText } from '../components/StreamingText';

@Component
export struct GroupChatPage {
  @StorageProp(READING_SIZE_KEY) readingSize: number = 15;
  @StorageProp(READING_LINE_KEY) readingLine: number = 1.5;
  @StorageProp(READING_FONT_KEY) readingFont: string = 'system';
  @StorageProp(READING_INSET_KEY) readingInset: number = 8;
  @StorageProp('uiColors') colors: ColorTokens = COLORS;
  @StorageProp('systemTopInset') top: number = 0;
  @StorageProp('systemBottomInset') bottom: number = 0;
  @State dock: ChatDockState = new ChatDockState();
  @State groupName: string = '群聊';
  @State characters: CharacterDto[] = [];
  @State messages: ChatMessageDto[] = [];
  @State manual: boolean = false;
  @State selectedSpeaker: string = '';
  @State generating: boolean = false;
  @State loading: boolean = true;
  @State liveText: string = '';
  @State speakerName: string = '';
  @State error: string = '';
  @State status: string = '';
  private groupId: string = '';
  private chatId: string = '';
  private streamId: string = '';
  private replyModel: string = '';
  private cancelled: boolean = false;
  private mounted: boolean = false;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.mounted = true;
    this.groupId = GroupConversationIntent.groupId; this.chatId = GroupConversationIntent.chatId;
    GroupConversationIntent.groupId = ''; GroupConversationIntent.chatId = '';
    this.dock.changeText = (value: string): void => { this.dock.text = value; };
    this.dock.submit = (): void => { if (this.generating) { this.stop(); } else { this.send(); } };
    this.reload();
  }
  aboutToDisappear(): void { this.mounted = false; this.stop(); }
  stop(): void {
    this.cancelled = true;
    if (this.streamId !== '') { Backend.closeChatCompletionStream(this.streamId).catch((): void => {}); }
  }
  async reload(): Promise<void> {
    if (this.generating) { return; }
    this.loading = true; this.dock.available = false; this.error = '';
    try {
      const group: ESObject = await Backend.getGroup(this.groupId);
      if (!group) { throw new Error('群聊已不存在'); }
      this.groupName = group.name as string; this.manual = (group.activation_strategy as number) === 2;
      const members: string[] = (group.members as string[]) || [];
      const muted: string[] = (group.disabled_members as string[]) || [];
      const all: CharacterDto[] = await Backend.getAllCharacters();
      this.characters = members.filter((key: string) => !muted.includes(key)).map((key: string) =>
        all.find((character: CharacterDto) => character.avatar === key))
        .filter((character: CharacterDto | undefined) => character !== undefined) as CharacterDto[];
      if (!this.characters.some((character: CharacterDto) => character.avatar === this.selectedSpeaker)) {
        this.selectedSpeaker = this.characters.length ? this.characters[0].avatar || '' : '';
      }
      const session = await GroupSession.read(this.groupId, this.chatId);
      this.chatId = session.chatId; this.messages = session.messages;
      this.dock.available = this.characters.length > 0;
      this.status = this.characters.length ? this.characters.length + ' 位成员参与回复' : '没有可发言成员，请返回群聊设置';
    } catch (error) { this.error = (error as Error).message; }
    finally { this.loading = false; }
  }
  async append(name: string, user: boolean, text: string): Promise<void> {
    const extra: Record<string, ESObject> = {};
    if (!user) { extra['model'] = this.replyModel; extra['harmony_usage_recorded'] = true; extra['harmony_usage_request'] = this.streamId; }
    const message: ChatMessageDto = { name: name, is_user: user, is_system: false,
      send_date: new Date().toISOString(), mes: text, extra: extra };
    const session: GroupSessionData = await GroupSession.append(this.groupId, this.chatId, this.messages.length, message);
    this.messages = session.messages;
  }
  async start(dto: GenerateRequestDto): Promise<void> {
    this.replyModel = dto.model || '';
    try { await Backend.startChatCompletionStream(this.streamId, dto); }
    catch (error) {
      const message: string = (error as Error).message;
      const marker: string = 'endpoint_authorization_required|';
      const index: number = message.indexOf(marker);
      if (index < 0) { throw new Error(message); }
      const endpoint: string = message.substring(index + marker.length);
      const allowed: boolean = await new Promise<boolean>((resolve) => {
        this.getUIContext().showAlertDialog({ title: '允许连接到自定义端点？',
          message: '端点：' + endpoint + '\n将向此端点发送密钥、角色设定与聊天内容。' +
            (endpoint.startsWith('http://') ? '\n此 HTTP 连接未加密。' : ''),
          primaryButton: { value: '取消', action: (): void => { resolve(false); } },
          secondaryButton: { value: '信任并连接', action: (): void => { resolve(true); } },
          cancel: (): void => { resolve(false); } });
      });
      if (!allowed || this.cancelled) { throw new Error('已取消连接'); }
      await Backend.grantUserEndpointAccess(endpoint); await Backend.startChatCompletionStream(this.streamId, dto);
    }
  }
  async reply(character: CharacterDto): Promise<void> {
    const provider = ProviderPreferences.active();
    const config = ProviderPreferences.get(provider);
    if (!config.model) { throw new Error('请先在服务商设置中选择模型'); }
    const key: string = (character.avatar || character.name).replace(/\.[^.]+$/, '');
    let dto: GenerateRequestDto = { model: config.model, stream: true,
      messages: this.messages.map((message: ChatMessageDto): ESObject => ({
        role: message.is_system ? 'system' : (message.is_user ? 'user' : 'assistant'),
        content: message.is_user ? message.mes : message.name + ': ' + message.mes
      })) };
    ProviderPreferences.apply(dto, provider, config);
    dto = await NativeSettings.prepareChat(key, dto);
    dto.messages.push({ role: 'system', content: 'This is a group conversation named ' + this.groupName +
      '. Participants: ' + this.characters.map((member: CharacterDto) => member.name).join(', ') +
      '. Write only the next reply by ' + character.name + '. Do not speak for other participants or the user.' });
    if (this.cancelled) { return; }
    this.speakerName = character.name; this.liveText = '';
    this.streamId = 'group_' + Date.now() + '_' + Math.floor(Math.random() * 100000);
    let sequence: number = 0;
    try {
      await this.start(dto);
      let done: boolean = false;
      while (!done && !this.cancelled) {
        const result = await Backend.readChatCompletionStreamDecoded(this.streamId, sequence);
        for (const event of result.events) {
          sequence = event.seq;
          if (event.type === 'chunk') {
            for (const part of event.parts) { if (part.kind === 'text') { this.liveText += part.text; } }
          } else if (event.type === 'error') { throw new Error(event.message); }
          else if (event.type === 'done') { done = true; }
        }
        if (result.status !== 'running') { done = true; }
        if (!done && !this.cancelled) { await new Promise<void>((resolve) => { setTimeout((): void => { resolve(); }, 200); }); }
      }
      if (this.liveText.trim() !== '') { await this.append(character.name, false, this.liveText); this.liveText = ''; }
    } catch (error) {
      if (this.liveText.trim() !== '') { await this.append(character.name, false, this.liveText); this.liveText = ''; }
      throw new Error((error as Error).message);
    } finally {
      if (this.streamId !== '') { await Backend.closeChatCompletionStream(this.streamId).catch((): void => {}); this.streamId = ''; }
    }
  }
  async send(continueOnly: boolean = false): Promise<void> {
    if (this.generating || this.loading || (!continueOnly && !this.dock.text.trim()) || this.characters.length === 0) { return; }
    this.generating = true; this.dock.streaming = true; this.cancelled = false; this.error = '';
    try {
      const secretState = await Backend.readSecretState() as Record<string, ProviderSecretState[]>;
      ProviderPreferences.hydrate(secretState);
      const prefs = await NativeSettings.get();
      if (!continueOnly) {
        const text: string = prefs.preferences.trim_spaces ? this.dock.text.trim() : this.dock.text;
        await this.append(prefs.preferences.user_name, true, text); this.dock.text = '';
      }
      const speakers: CharacterDto[] = this.manual ? this.characters.filter((character: CharacterDto) => character.avatar === this.selectedSpeaker) : this.characters;
      for (const speaker of speakers) { if (this.cancelled || !this.mounted) { break; } await this.reply(speaker); }
      this.status = this.cancelled ? '已停止，已保留生成内容' : '本轮回复完成';
    } catch (error) { if (!this.cancelled) { this.error = (error as Error).message; } }
    finally { this.generating = false; this.dock.streaming = false; }
  }
  build() {
    Column({ space: 8 }) {
      PageHeader({ title: this.groupName, subtitle: this.status, onBack: (): void => { this.stop(); ROOT_PATH_STACK.pop(); } }) {
        HeaderAction({ label: '刷新群聊记录', marker: 'group-chat-refresh', available: !this.generating, pending: this.loading,
          onAction: async (): Promise<void> => { await this.reload(); } })
      }
      Row() {
        Button('模型设置').attributeModifier(new ActionButtonStyle(this.colors, ActionTone.Normal))
          .enabled(!this.generating).onClick((): void => { ROOT_PATH_STACK.pushPathByName('pages/ProviderPage', null); })
        Button('继续回复').attributeModifier(new ActionButtonStyle(this.colors, ActionTone.Normal))
          .enabled(!this.generating && !this.loading && this.messages.length > 0)
          .onClick((): void => { this.send(true); })
      }.width('100%').padding({ left: 12, right: 12 })
      if (this.manual && this.characters.length) {
        SettingsPicker({ title: '发言成员', marker: 'group-speaker', selectedId: this.selectedSpeaker,
          options: this.characters.map((character: CharacterDto): SettingsChoice => {
            return { id: character.avatar ?? '', label: character.name };
          }), available: !this.generating, placeholder: '选择发言成员',
          onSelect: (id: string): void => { this.selectedSpeaker = id; } })
          .padding({ left: 12, right: 12 })
      }
      ErrorBannerView({ text: this.error })
      Scroll(this.scroller) {
        Column({ space: 12 }) {
          ForEach(this.messages, (message: ChatMessageDto, index: number) => {
            Column({ space: 6 }) {
              Text(message.name).fontSize(13).fontColor(this.colors.textSecondary).width('100%')
              Text(message.mes).fontSize(this.readingSize).lineHeight(this.readingSize * this.readingLine)
                .fontFamily(ReadingPreferences.fontFamily(this.readingFont))
                .fontColor(this.colors.textPrimary).width('100%').copyOption(CopyOptions.LocalDevice)
            }.width('100%').padding(this.readingInset).attributeModifier(new SurfaceStyle(this.colors, 20))
          }, (message: ChatMessageDto, index: number) => index.toString() + message.send_date)
          if (this.generating || this.liveText !== '') {
            Column({ space: 6 }) {
              Text(this.speakerName).fontSize(13).fontColor(this.colors.textSecondary).width('100%')
              StreamingText({ text: this.liveText, active: this.generating })
            }.width('100%').padding(this.readingInset)
          }
        }.width('100%').padding(12)
      }.width('100%').layoutWeight(1)
      Row() { ChatDock({ state: this.dock }) }.padding(6).margin({ left: 12, right: 12 })
        .attributeModifier(new SurfaceStyle(this.colors, 28))
    }.width('100%').height('100%').padding({ top: this.top, bottom: this.bottom + 8 }).backgroundColor(this.colors.bgBase)
  }
}
