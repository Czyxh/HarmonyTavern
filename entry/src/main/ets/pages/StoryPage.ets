import { COLORS, ColorTokens } from '../theme/Tokens';
import { ActionButtonStyle, ActionTone, InputFieldStyle, TextAreaFieldStyle } from '../theme/ControlStyles';
import { PageSurface } from '../components/PageSurface';
import { PageHeader } from '../components/PageHeader';
import { Backend } from '../backend/Backend';
import { NativeStory, StorySettings, defaultStorySettings } from '../backend/NativeStory';
import { ChatDto, CharacterDto, ChatSearchResultDto } from '../backend/Types';
import { PersonalizationStore, STORY_WELCOME_DISMISSED_KEY } from '../theme/PersonalizationStore';
import { ChatIntent, StoryIntent, ROOT_PATH_STACK } from '../nav/RootNav';
import { MOTION_REDUCE_KEY } from '../theme/Motion';
import { WorldModelPicker } from '../components/WorldModelPicker';
import { AuxiliaryModels } from '../backend/AuxiliaryModels';
import { StoryAssistant, StoryDraft } from '../backend/StoryAssistant';
import { SettingsChoice, SettingsPicker } from '../components/SettingsPicker';
import { GenerateRequestDto } from '../backend/Types';

@Component
export struct StoryPage {
  @StorageProp('uiColors') colors: ColorTokens = COLORS;
  @StorageProp(MOTION_REDUCE_KEY) reduceMotion: boolean = false;
  @State story: StorySettings = defaultStorySettings();
  @State loading: boolean = true;
  @State ready: boolean = false;
  @State busy: boolean = false;
  @State assistantBusy: boolean = false;
  @State assistantRequirement: string = '';
  @State assistantError: string = '';
  @State assistantDraft: StoryDraft | null = null;
  private assistantRevision: number = 0;
  private assistantRequest: string = '';
  @State error: string = '';
  @State characterName: string = '';
  @State displayName: string = '';
  @State fileName: string = '';
  @State characters: CharacterDto[] = [];
  @State worldBooks: string[] = [];
  @State characterExpanded: boolean = false;
  @State worldExpanded: boolean = false;
  @State assistantExpanded: boolean = false;
  @State detailsExpanded: boolean = false;
  @State modeSettings: boolean = false;
  @State characterQuery: string = '';
  @State histories: ChatSearchResultDto[] = [];
  @State historyExpanded: boolean = false;
  @State selectedHistory: string = '';
  @State historyLoading: boolean = false;
  private historyRevision: number = 0;
  private newStory: StorySettings = defaultStorySettings();
  private alive: boolean = false;

  aboutToAppear(): void {
    this.alive = true;
    this.characterName = StoryIntent.characterName;
    this.displayName = StoryIntent.displayName;
    this.fileName = StoryIntent.fileName;
    this.story.opening_message = StoryIntent.greeting;
    this.characterExpanded = this.fileName === '' && this.characterName === '';
    this.load();
  }
  aboutToDisappear(): void { this.alive = false; this.cancelAssistant(); }
  private cancelAssistant(): void {
    this.assistantRevision++;
    const request: string = this.assistantRequest;
    this.assistantRequest = ''; this.assistantBusy = false;
    if (request !== '') { Backend.cancelChatCompletionGeneration(request).catch((): void => {}); }
  }
  private async generateDraft(): Promise<void> {
    if (this.assistantBusy || this.busy || this.fileName !== '' || this.selectedHistory !== '' || this.story.mode !== 'free') { return; }
    const character: CharacterDto | undefined = this.characters.find((item: CharacterDto): boolean => this.characterKey(item) === this.characterName);
    if (character === undefined) { this.assistantError = '请重新选择角色卡后生成草稿'; return; }
    const revision: number = ++this.assistantRevision;
    const request: string = 'story_setup_' + Date.now();
    this.assistantBusy = true; this.assistantRequest = request; this.assistantError = ''; this.assistantDraft = null;
    try {
      const dto: GenerateRequestDto = await AuxiliaryModels.route(StoryAssistant.request(this.assistantRequirement, character, this.story), true);
      if (!this.alive || revision !== this.assistantRevision) { return; }
      let response: ESObject;
      try { response = await Backend.generateChatCompletion(request, dto); }
      catch (error) {
        const marker: string = 'endpoint_authorization_required|';
        const message: string = (error as Error).message;
        const position: number = message.indexOf(marker);
        if (position < 0) { throw new Error(message); }
        if (!this.alive || revision !== this.assistantRevision) { return; }
        const endpoint: string = message.substring(position + marker.length).trim();
        const trusted: boolean = await new Promise<boolean>((resolve) => {
          this.getUIContext().showAlertDialog({ title: '信任端点',
            message: '生成故事草稿会发送本页故事设置、需求与所选角色资料到 ' + endpoint,
            primaryButton: { value: '取消', action: (): void => { resolve(false); } },
            secondaryButton: { value: '信任并连接', action: (): void => { resolve(true); } }, cancel: (): void => { resolve(false); } });
        });
        if (!trusted || !this.alive || revision !== this.assistantRevision) { return; }
        await Backend.grantUserEndpointAccess(endpoint);
        if (!this.alive || revision !== this.assistantRevision) { return; }
        response = await Backend.generateChatCompletion(request, dto);
      }
      if (this.alive && revision === this.assistantRevision) { this.assistantDraft = StoryAssistant.result(response); }
    } catch (error) {
      if (this.alive && revision === this.assistantRevision) { this.assistantError = '草稿生成失败：' + (error as Error).message; }
    } finally {
      if (revision === this.assistantRevision) { this.assistantBusy = false; this.assistantRequest = ''; }
    }
  }
  private applyAssistantDraft(): void {
    const draft: StoryDraft | null = this.assistantDraft;
    if (draft === null || this.assistantBusy) { return; }
    this.story.title = draft.title; this.story.scenario = draft.scenario; this.story.style = draft.style;
    this.story.author_note = draft.author_note; this.story.opening_message = draft.opening_message;
    this.assistantDraft = null;
  }
  private async load(): Promise<void> {
    this.loading = true;
    this.ready = false;
    this.error = '';
    try {
      if (this.fileName !== '') {
        const story: StorySettings = await NativeStory.get(this.characterName, this.fileName);
        if (!this.alive) { return; }
        this.story = story;
      }
      if (this.story.world_books === undefined) { this.story.world_books = []; }
      const characters: CharacterDto[] = this.fileName === '' ? await Backend.getAllCharacters() : [];
      const books: string[] = await Backend.listWorldInfos();
      const histories: ChatSearchResultDto[] = this.fileName === '' ? await Backend.listChatSummaries() : [];
      if (!this.alive) { return; }
      this.characters = characters;
      this.worldBooks = books;
      this.histories = histories;
      this.ready = true;
    } catch (error) { if (this.alive) { this.error = (error as Error).message; } }
    finally { if (this.alive) { this.loading = false; } }
  }
  private characterKey(character: CharacterDto): string {
    return (character.avatar ?? '').replace(/\.png$/i, '') || character.name;
  }
  private matchingCharacters(): CharacterDto[] {
    const query: string = this.characterQuery.trim().toLocaleLowerCase();
    return this.characters.filter((character: CharacterDto): boolean => query === '' || character.name.toLocaleLowerCase().includes(query));
  }
  private setPickerExpanded(picker: string, expanded: boolean): void {
    this.getUIContext().animateTo({ duration: this.reduceMotion ? 0 : 240, curve: Curve.EaseInOut }, (): void => {
      if (picker === 'character') { this.characterExpanded = expanded; }
      else if (picker === 'history') { this.historyExpanded = expanded; }
      else if (picker === 'assistant') { this.assistantExpanded = expanded; }
      else if (picker === 'details') { this.detailsExpanded = expanded; }
      else { this.worldExpanded = expanded; }
    });
  }
  private pickerTransition(): TransitionEffect {
    return this.reduceMotion ? TransitionEffect.IDENTITY :
      TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: -8 }));
  }
  private chooseCharacter(character: CharacterDto): void {
    this.assistantDraft = null;
    if (this.characterName === this.characterKey(character)) { this.setPickerExpanded('character', false); return; }
    if (this.selectedHistory !== '') { this.story = this.newStory; }
    this.selectedHistory = '';
    this.historyRevision++;
    this.historyLoading = false;
    const previous: CharacterDto | undefined = this.characters.find((item: CharacterDto): boolean => this.characterKey(item) === this.characterName);
    if (this.story.opening_message === '' || this.story.opening_message === previous?.first_mes) {
      this.story.opening_message = character.first_mes ?? '';
    }
    this.characterName = this.characterKey(character);
    this.displayName = character.name;
    this.setPickerExpanded('character', false);
  }
  private characterHistories(): ChatSearchResultDto[] {
    return this.histories.filter((chat: ChatSearchResultDto): boolean => chat.character_name === this.characterName);
  }
  private async selectHistory(file: string): Promise<void> {
    this.assistantDraft = null;
    if (this.busy || this.historyLoading) { return; }
    if (this.selectedHistory === file) { this.setPickerExpanded('history', false); return; }
    const revision: number = ++this.historyRevision;
    if (file === '') {
      this.story = this.newStory;
      this.selectedHistory = '';
      this.setPickerExpanded('history', false);
      return;
    }
    this.historyLoading = true;
    this.error = '';
    try {
      const story: StorySettings = await NativeStory.get(this.characterName, file);
      if (!this.alive || revision !== this.historyRevision) { return; }
      if (this.selectedHistory === '') { this.newStory = this.story; }
      this.story = story;
      this.selectedHistory = file;
      this.setPickerExpanded('history', false);
    } catch (error) { if (this.alive && revision === this.historyRevision) { this.error = '读取聊天记录失败：' + (error as Error).message; } }
    finally { if (this.alive && revision === this.historyRevision) { this.historyLoading = false; } }
  }
  private toggleWorld(name: string): void {
    if (this.story.world_books.includes(name)) {
      this.story.world_books = this.story.world_books.filter((selected: string): boolean => selected !== name);
    } else if (this.story.world_books.length < 8) {
      this.story.world_books = [...this.story.world_books, name];
    } else {
      this.getUIContext().getPromptAction().showToast({ message: '每段对话最多选择 8 本世界书' });
    }
  }
  private back(): void { if (!this.busy) { ROOT_PATH_STACK.pop(); } }
  private async save(): Promise<void> {
    if (this.loading || this.historyLoading || !this.ready || this.busy || this.assistantBusy || this.characterName === '') { return; }
    this.busy = true;
    AppStorage.setOrCreate<boolean>('storySaving', true);
    this.error = '';
    try {
      if (this.fileName === '') {
        let chat: ChatDto;
        if (this.selectedHistory !== '') {
          await NativeStory.save(this.characterName, this.selectedHistory, this.story);
          chat = await Backend.getChat(this.characterName, this.selectedHistory);
        } else {
          chat = await NativeStory.create(this.characterName, this.story);
        }
        PersonalizationStore.set(STORY_WELCOME_DISMISSED_KEY, true);
        if (!this.alive) { return; }
        ChatIntent.request(chat.character_name, chat.file_name);
        ROOT_PATH_STACK.replacePathByName('pages/ChatPage', null);
      } else {
        await NativeStory.save(this.characterName, this.fileName, this.story);
        AppStorage.setOrCreate<number>('storyRevision', (AppStorage.get<number>('storyRevision') ?? 0) + 1);
        if (this.alive) { ROOT_PATH_STACK.pop(); }
      }
    } catch (error) { if (this.alive) { this.error = '保存失败：' + (error as Error).message; } }
    finally {
      AppStorage.setOrCreate<boolean>('storySaving', false);
      if (this.alive) { this.busy = false; }
    }
  }
  @Builder
  characterPicker() {
    if (this.fileName === '') {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 10 }) {
          Column({ space: 6 }) {
            Text('角色卡 · 必选').fontSize(13).fontColor(this.colors.textSecondary)
            Text(this.characterName === '' ? '选择资料库中已有的角色卡' : this.displayName)
              .fontSize(16).fontColor(this.colors.textPrimary).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Text(this.characterExpanded ? '收起' : '选择').fontSize(14).fontColor(this.colors.accent)
        }.width('100%')
      }.attributeModifier(new ActionButtonStyle(this.colors)).height('auto').padding(14).width('100%')
        .id('story-character-picker').onClick((): void => { this.setPickerExpanded('character', !this.characterExpanded); })
      if (this.characterExpanded) {
        Column({ space: 18 }) {
        if (this.characters.length > 4) {
          TextInput({ text: this.characterQuery, placeholder: '搜索已有角色卡' })
            .attributeModifier(new InputFieldStyle(this.colors)).onChange((value: string): void => { this.characterQuery = value; })
        }
        if (this.characters.length === 0) {
          Text('还没有角色卡，请先到资料库导入，再回来创建对话。').fontSize(14).fontColor(this.colors.textSecondary)
        } else if (this.matchingCharacters().length === 0) {
          Text('没有匹配的角色卡').fontSize(14).fontColor(this.colors.textSecondary)
        } else {
          Scroll() {
            Column({ space: 6 }) {
              ForEach(this.matchingCharacters(), (character: CharacterDto) => {
                Button({ type: ButtonType.Normal }) {
                  Row({ space: 12 }) {
                    Text(character.name.substring(0, 1)).fontSize(20).fontColor(this.colors.accent)
                    Text(character.name).fontSize(15).fontColor(this.colors.textPrimary).layoutWeight(1)
                      .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(this.characterName === this.characterKey(character) ? '✓' : '').fontColor(this.colors.accent)
                  }.width('100%')
                }.attributeModifier(new ActionButtonStyle(this.colors,
                  this.characterName === this.characterKey(character) ? ActionTone.Selected : ActionTone.Normal))
                  .width('100%').height(58).id('story-character-' + this.characterKey(character))
                  .accessibilitySelected(this.characterName === this.characterKey(character))
                  .onClick((): void => { this.chooseCharacter(character); })
              }, (character: CharacterDto): string => this.characterKey(character))
            }.width('100%')
          }.height(Math.min(250, this.matchingCharacters().length * 64 - 6)).width('100%').scrollBar(BarState.Auto)
        }
        }.width('100%').transition(this.pickerTransition()).id('story-character-expanded')
      }
    } else {
      Text('角色卡：' + this.displayName).fontSize(15).fontColor(this.colors.textPrimary).width('100%')
    }
  }
  @Builder
  historyPicker() {
    if (this.fileName === '') {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 10 }) {
          Column({ space: 6 }) {
            Text('聊天记录 · 可选').fontSize(13).fontColor(this.colors.textSecondary)
            Text(this.selectedHistory === '' ? '从空白开始新对话' : this.selectedHistory)
              .fontSize(16).fontColor(this.colors.textPrimary).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Text(this.historyLoading ? '读取中…' : (this.historyExpanded ? '收起' : '选择'))
            .fontSize(14).fontColor(this.colors.accent)
        }.width('100%')
      }.attributeModifier(new ActionButtonStyle(this.colors)).height('auto').padding(14).width('100%')
        .enabled(this.characterName !== '').id('story-history-picker')
        .onClick((): void => { this.setPickerExpanded('history', !this.historyExpanded); })
      if (this.historyExpanded) {
        Column({ space: 18 }) {
        Button(this.selectedHistory === '' ? '✓ 从空白开始' : '从空白开始')
          .attributeModifier(new ActionButtonStyle(this.colors)).width('100%').id('story-history-empty')
          .onClick((): void => { this.selectHistory(''); })
        if (this.characterHistories().length === 0) {
          Text('这个角色还没有聊天记录，可从空白开始。').fontSize(14).fontColor(this.colors.textSecondary)
        }
        ForEach(this.characterHistories(), (chat: ChatSearchResultDto) => {
          Button({ type: ButtonType.Normal }) {
            Column({ space: 6 }) {
              Text((this.selectedHistory === chat.file_name ? '✓ ' : '') + chat.file_name)
                .fontSize(15).fontColor(this.colors.textPrimary).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(String(chat.message_count) + ' 条消息 · 继续原对话').fontSize(12).fontColor(this.colors.textSecondary)
            }.width('100%').alignItems(HorizontalAlign.Start)
          }.attributeModifier(new ActionButtonStyle(this.colors,
            this.selectedHistory === chat.file_name ? ActionTone.Selected : ActionTone.Normal))
            .height('auto').padding(14).width('100%').id('story-history-' + chat.file_name)
            .accessibilitySelected(this.selectedHistory === chat.file_name)
            .onClick((): void => { this.selectHistory(chat.file_name); })
        }, (chat: ChatSearchResultDto): string => chat.file_name)
        }.width('100%').transition(this.pickerTransition()).id('story-history-expanded')
      }
      Text('选择已有记录会读取它的故事设置，确认后保存本页设置并继续原对话；不会复制或清空原消息。')
        .fontSize(12).fontColor(this.colors.textSecondary).width('100%')
    }
  }
  @Builder
  worldPicker() {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 10 }) {
        Column({ space: 6 }) {
          Text(this.story.mode === 'world' ? '世界书 · 可选，不选则使用角色卡内置世界书' : '世界书 · 可选多本').fontSize(13).fontColor(this.colors.textSecondary)
          Text(this.story.world_books.length === 0 ? (this.story.mode === 'world' ? '使用角色卡内置世界书' : '不额外添加世界书') : this.story.world_books.join('、'))
            .fontSize(16).fontColor(this.colors.textPrimary).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text(this.worldExpanded ? '收起' : '选择').fontSize(14).fontColor(this.colors.accent)
      }.width('100%')
    }.attributeModifier(new ActionButtonStyle(this.colors)).height('auto').padding(14).width('100%')
      .id('story-world-picker').onClick((): void => { this.setPickerExpanded('world', !this.worldExpanded); })
    if (this.worldExpanded) {
      Column({ space: 18 }) {
      if (this.worldBooks.length === 0) {
        Text('资料库里还没有世界书，可先导入，也可以不选。').fontSize(14).fontColor(this.colors.textSecondary)
      }
      ForEach(this.worldBooks, (name: string) => {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 12 }) {
            Text(name).fontSize(15).fontColor(this.colors.textPrimary).layoutWeight(1)
            Text(this.story.world_books.includes(name) ? '✓' : '+').fontColor(this.colors.accent)
          }.width('100%')
        }.attributeModifier(new ActionButtonStyle(this.colors,
          this.story.world_books.includes(name) ? ActionTone.Selected : ActionTone.Normal))
          .height('auto').constraintSize({ minHeight: 48 }).padding(12).width('100%').id('story-world-' + name)
          .accessibilitySelected(this.story.world_books.includes(name)).onClick((): void => { this.toggleWorld(name); })
      }, (name: string): string => name)
      ForEach(this.story.world_books.filter((name: string): boolean => !this.worldBooks.includes(name)), (name: string) => {
        Button('移除已不存在的世界书：' + name).attributeModifier(new ActionButtonStyle(this.colors, ActionTone.Warning))
          .height('auto').padding(12).onClick((): void => { this.toggleWorld(name); })
      }, (name: string): string => name)
      }.width('100%').transition(this.pickerTransition()).id('story-world-expanded')
    }
    Text('所选世界书的启用条目会作为本段对话的背景上下文；不会修改原角色卡和世界书。')
      .fontSize(12).fontColor(this.colors.textSecondary).width('100%')
  }
  @Builder
  storyAssistant() {
    if (this.fileName === '' && this.selectedHistory === '' && this.story.mode === 'free') {
      Column({ space: 10 }) {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 10 }) {
            Column({ space: 6 }) {
              Text('AI 辅助 · 可选').fontSize(13).fontColor(this.colors.textSecondary)
              Text(this.assistantBusy ? '正在生成故事草稿…' : this.assistantDraft !== null ? '有一份草稿待核对' : '让 AI 帮我创建普通对话')
                .fontSize(16).fontColor(this.colors.textPrimary).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Text(this.assistantExpanded ? '收起' : '展开').fontSize(14).fontColor(this.colors.accent)
          }.width('100%')
        }.attributeModifier(new ActionButtonStyle(this.colors)).height('auto').padding(14).width('100%')
          .id('story-assistant-toggle').accessibilityText(this.assistantExpanded ? '收起 AI 辅助' : '展开 AI 辅助')
          .onClick((): void => { this.setPickerExpanded('assistant', !this.assistantExpanded); })
        if (this.assistantExpanded) {
          Column({ space: 10 }) {
        Text('使用辅助模型生成故事草稿。核对并填入后，可继续编辑再创建对话；会发送需求、当前故事设置与所选角色资料。')
          .fontSize(13).fontColor(this.colors.textSecondary).lineHeight(21).width('100%')
        TextArea({ text: this.assistantRequirement, placeholder: '描述想要的背景、风格和开场，例如：在雨夜书店与这位角色初次见面，轻松日常风格。' })
          .maxLength(3000).height(110).attributeModifier(new TextAreaFieldStyle(this.colors)).id('story-assistant-requirement')
          .onChange((value: string): void => { this.assistantRequirement = value; this.assistantDraft = null; })
        Button(this.assistantBusy ? '正在生成故事草稿…' : '生成故事草稿').attributeModifier(new ActionButtonStyle(this.colors)).width('100%')
          .enabled(this.characterName !== '' && this.assistantRequirement.trim() !== '').id('story-assistant-generate')
          .onClick((): void => { this.generateDraft(); })
        if (this.assistantError !== '') { Text(this.assistantError).fontColor(this.colors.danger).width('100%') }
        if (this.assistantDraft !== null) {
          Text('故事名称：' + this.assistantDraft.title).fontColor(this.colors.textPrimary).width('100%')
          Text('背景：' + this.assistantDraft.scenario).fontColor(this.colors.textSecondary).width('100%')
          Text('风格：' + this.assistantDraft.style).fontColor(this.colors.textSecondary).width('100%')
          Text('补充规则：' + this.assistantDraft.author_note).fontColor(this.colors.textSecondary).width('100%')
          Text('开场白：' + this.assistantDraft.opening_message).fontColor(this.colors.textSecondary).width('100%')
          Button('填入故事设置').attributeModifier(new ActionButtonStyle(this.colors, ActionTone.Primary)).width('100%')
            .id('story-assistant-apply').onClick((): void => { this.applyAssistantDraft(); })
          Button('丢弃草稿').attributeModifier(new ActionButtonStyle(this.colors)).width('100%')
            .onClick((): void => { this.assistantDraft = null; })
        }

          }.width('100%').transition(this.pickerTransition()).id('story-assistant-expanded')
        }
      }.width('100%')
    }
  }
  @Builder
  storyDetailsSection() {
    if (this.fileName === '' && this.selectedHistory === '') {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 10 }) {
          Column({ space: 6 }) {
            Text('故事设置 · 可选').fontSize(13).fontColor(this.colors.textSecondary)
            Text(this.story.title !== '' ? this.story.title : '名称、背景、风格、规则与开场白')
              .fontSize(16).fontColor(this.colors.textPrimary).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Text(this.detailsExpanded ? '收起' : '展开').fontSize(14).fontColor(this.colors.accent)
        }.width('100%')
      }.attributeModifier(new ActionButtonStyle(this.colors)).height('auto').padding(14).width('100%')
        .id('story-details-toggle').accessibilityText(this.detailsExpanded ? '收起故事设置' : '展开故事设置')
        .onClick((): void => { this.setPickerExpanded('details', !this.detailsExpanded); })
      if (this.detailsExpanded) {
        Column({ space: 18 }) {
        Text('故事设置仅用于当前对话，不会修改角色卡。').fontSize(13).fontColor(this.colors.textSecondary)
        TextInput({ text: this.story.title, placeholder: '故事名称（可选）' }).maxLength(100)
          .onChange((value: string): void => { this.story.title = value; }).accessibilityText('故事名称')
          .attributeModifier(new InputFieldStyle(this.colors))
        Column({ space: 8 }) {
          Text('故事背景').fontSize(14).fontColor(this.colors.textSecondary).width('100%')
          TextArea({ text: this.story.scenario }).height(128).accessibilityText('故事背景').id('story-scenario')
            .attributeModifier(new TextAreaFieldStyle(this.colors))
            .onChange((value: string): void => { this.story.scenario = value; })
        }.width('100%')
        Column({ space: 8 }) {
          Text('叙事风格').fontSize(14).fontColor(this.colors.textSecondary).width('100%')
          TextArea({ text: this.story.style }).height(128).accessibilityText('叙事风格').id('story-style')
            .attributeModifier(new TextAreaFieldStyle(this.colors))
            .onChange((value: string): void => { this.story.style = value; })
        }.width('100%')
        Column({ space: 8 }) {
          Text('补充规则').fontSize(14).fontColor(this.colors.textSecondary).width('100%')
          TextArea({ text: this.story.author_note }).height(128).accessibilityText('补充规则').id('story-author-note')
            .attributeModifier(new TextAreaFieldStyle(this.colors))
            .onChange((value: string): void => { this.story.author_note = value; })
        }.width('100%')
          Column({ space: 8 }) {
            Text('开场白（留空则不添加开场消息）').fontSize(14).fontColor(this.colors.textSecondary).width('100%')
            TextArea({ text: this.story.opening_message }).height(128).accessibilityText('开场白').id('story-opening-message')
              .attributeModifier(new TextAreaFieldStyle(this.colors))
              .onChange((value: string): void => { this.story.opening_message = value; })
          }.width('100%')
        }.width('100%').transition(this.pickerTransition()).id('story-details-expanded')
      }
    }
  }  @Builder
  content() {
    Column({ space: 18 }) {
      if (this.loading) { Text('读取故事设置中…').fontColor(this.colors.textSecondary) }
      Column({ space: 18 }) {
        Text('选择已有资料').fontSize(18).fontWeight(FontWeight.Medium).fontColor(this.colors.textPrimary).width('100%')
        this.characterPicker()
        this.historyPicker()
        this.worldPicker()
        this.storyAssistant()
        this.storyDetailsSection()
        Text('聊天模式').fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.colors.textPrimary).width('100%')
        Row({ space: 12 }) {
          Button(this.story.mode !== 'world' ? '✓ 普通模式' : '普通模式')
            .attributeModifier(new ActionButtonStyle(this.colors, this.story.mode !== 'world' ? ActionTone.Primary : ActionTone.Normal))
            .layoutWeight(1).id('story-mode-normal')
            .accessibilitySelected(this.story.mode !== 'world')
            .onClick((): void => { this.story.mode = 'free'; })
          Button(this.story.mode === 'world' ? '✓ 创造模式' : '创造模式')
            .attributeModifier(new ActionButtonStyle(this.colors, this.story.mode === 'world' ? ActionTone.Primary : ActionTone.Normal))
            .layoutWeight(1).id('story-mode-world').accessibilitySelected(this.story.mode === 'world')
            .onClick((): void => { this.story.mode = 'world'; })
        }.width('100%')
        Text('普通模式自由对话；创造模式追踪世界状态。两种模式都可开启剧情选项。')
          .fontSize(13).lineHeight(23).fontColor(this.colors.textSecondary).width('100%')
        Button((this.story.mode === 'world' ? '创造模式设置' : '普通模式设置') + ' ›')
          .attributeModifier(new ActionButtonStyle(this.colors)).width('100%').id('story-mode-settings')
          .onClick((): void => { this.modeSettings = true; })
          .bindContentCover($$this.modeSettings, this.modeCover())
      }.width('100%').enabled(!this.busy && !this.assistantBusy && !this.loading && !this.historyLoading && this.ready)
      if (this.assistantBusy) {
        Button('正在生成草稿… 点击取消').attributeModifier(new ActionButtonStyle(this.colors)).width('100%')
          .id('story-assistant-cancel').onClick((): void => { this.cancelAssistant(); })
      }
      if (this.error !== '') { Text(this.error).fontColor(this.colors.danger).width('100%') }
      if (!this.ready && !this.loading) {
        Button('重试读取').onClick((): void => { this.load(); })
          .attributeModifier(new ActionButtonStyle(this.colors, ActionTone.Normal))
      }
      Button(this.busy ? '保存中…' : (this.fileName === '' ? (this.selectedHistory === '' ? '创建并开始对话' : '保存设置并继续对话') : '保存故事设置'), { type: ButtonType.Normal })
        .enabled(!this.busy && !this.assistantBusy && !this.loading && !this.historyLoading && this.ready && this.characterName !== '').onClick((): void => { this.save(); })
        .attributeModifier(new ActionButtonStyle(this.colors, ActionTone.Primary)).id('story-save')
    }.width('100%')
  }
  @Builder
  modeContent() {
    Column({ space: 20 }) {
      Row({ space: 12 }) {
        Column({ space: 6 }) {
          Text('剧情选项').fontSize(17).fontColor(this.colors.textPrimary)
          Text('为每轮回复提供可选的下一句发言，也可以继续自由输入。')
            .fontSize(13).lineHeight(23).fontColor(this.colors.textSecondary)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.story.choices_enabled === true })
          .selectedColor(this.colors.accent).id('story-choices-enabled').accessibilityText('开启剧情选项')
          .onChange((enabled: boolean): void => { this.story.choices_enabled = enabled; })
      }.width('100%')
        if (this.story.mode === 'world') {
          Text('你希望怎样显示这个世界？').fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.colors.textPrimary).width('100%')
          TextArea({ text: this.story.world_ui_request,
            placeholder: '例如：追踪我的人物；按世界书显示生命、灵力、负伤与中毒，背包显示丹药数量，位置精确到区域/建筑。现代世界则显示体力、压力和随身物品。' })
            .maxLength(3000).constraintSize({ minHeight: 120 }).attributeModifier(new TextAreaFieldStyle(this.colors))
            .id('story-world-ui-request').accessibilityText('创造模式界面生成需求')
            .onChange((value: string): void => { this.story.world_ui_request = value; })
          SettingsPicker({ title: '状态更新方式', marker: 'story-world-update', selectedId: this.story.world_update_mode ?? 'auxiliary',
            options: [{ id: 'auxiliary', label: '辅助模型自动更新（推荐）', detail: '每次回复后单独提取状态，不让主模型输出状态 JSON' },
              { id: 'inline', label: '随主模型回复更新', detail: '不额外请求辅助模型，主回复会增加状态指令和 JSON 用量' },
              { id: 'manual', label: '仅手动更新', detail: '不自动调用；点击生成时才使用状态栏模型' }],
            onSelect: (id: string): void => { this.story.world_update_mode = id; } })
          WorldModelPicker({ selectedId: this.story.world_model_id ?? '',
            onSelect: (id: string): void => { this.story.world_model_id = id; } })
          Text('所选模型用于手动生成和辅助自动更新，仅影响本段对话；可选服务商管理中已保存的模型。辅助自动更新仍会产生所选模型的用量。')
            .fontSize(12).fontColor(this.colors.textSecondary).lineHeight(20).width('100%')
          SettingsPicker({ title: '冒险侧栏位置', marker: 'story-world-sidebar', selectedId: this.story.world_sidebar_side ?? 'auto',
            options: [{ id: 'auto', label: '跟随智感握持', detail: '杯子靠近握持手；双手或未识别时在右侧，展开期间不跳边' },
              { id: 'left', label: '固定左侧' }, { id: 'right', label: '固定右侧' }],
            onSelect: (id: string): void => { this.story.world_sidebar_side = id; } })
          Text('世界书可选；不选时使用角色卡内置世界书（需带有启用条目）。只追踪剧情支持的任务、好感度、血量、负面状态和位置；未知显示未确认，不自动补满或推算好感度。')
            .fontSize(13).fontColor(this.colors.textSecondary).lineHeight(21).width('100%')
        }
        if (this.story.choices_enabled === true) {
          Text('每轮选项数').fontColor(this.colors.textSecondary).width('100%')
          SettingsPicker({ title: '每轮选项数', marker: 'story-choice-count', selectedId: String(this.story.choice_count),
            options: ['2', '3', '4', '5', '6'].map((id: string): SettingsChoice => { return { id: id, label: id + ' 个选项' }; }),
            onSelect: (id: string): void => { this.story.choice_count = Number(id); } })
        }
      Button('完成设置').attributeModifier(new ActionButtonStyle(this.colors, ActionTone.Primary))
        .width('100%').id('story-mode-settings-done').onClick((): void => { this.modeSettings = false; })
    }.width('100%')
  }
  @Builder
  modeHeader() {
    PageHeader({ title: this.story.mode === 'world' ? '创造模式设置' : '普通模式设置',
      subtitle: '仅用于当前对话', onBack: (): void => { this.modeSettings = false; } })
  }
  @Builder
  modeCover() {
    PageSurface({ topBar: (): void => { this.modeHeader(); }, content: (): void => { this.modeContent(); } })
  }
  @Builder
  headerActions() {
    if (this.assistantBusy) {
      Button('取消生成').attributeModifier(new ActionButtonStyle(this.colors))
        .id('story-assistant-header-cancel').onClick((): void => { this.cancelAssistant(); })
    }
  }
  @Builder
  header() {
    PageHeader({ title: this.fileName === '' ? '创建对话' : '故事与聊天模式', subtitle: this.displayName || '从已有角色卡与世界书开始',
      actions: (): void => { this.headerActions(); },
      onBack: (): void => { this.back(); } })
  }
  build() {
    PageSurface({ topBar: (): void => { this.header(); }, content: (): void => { this.content(); } })
  }
}
