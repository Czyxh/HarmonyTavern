import { ProviderSetup, ProviderSetupDraft } from '../backend/ProviderSetup';
import { SurfaceStyle } from '../theme/SurfaceStyles';
import { ActionButtonStyle, ActionTone, InputFieldStyle, TextAreaFieldStyle } from '../theme/ControlStyles';
import { HeaderAction } from './HeaderAction';
import { NativePreferencesPanel } from './NativePreferencesPanel';
import { iconTint } from '../theme/IconTint';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { ProviderEntry, ProviderPreferences, ProtocolOption } from '../backend/ProviderCatalog';
import { LengthMetrics } from '@kit.ArkUI';
import { GLASS_HEADER_BUTTON, glassEffect } from '../theme/Glass';
import { LS_BLUR_DEFAULT, LS_BLUR_KEY } from '../theme/LightSense';
import { IMMERSIVE_DEFAULT, IMMERSIVE_KEY } from '../theme/Immersive';
import { PageSurface } from './PageSurface';
import { BrandIcon } from './BrandIcon';
import { JellyTabBar, JellyTabItem } from './JellyTabBar';
import { SwingContent } from './SwingContent';
import { AuxiliaryModels } from '../backend/AuxiliaryModels';

const PROVIDER_GROUPS: JellyTabItem[] = [
  { glyph: '', label: '官方直连' }, { glyph: '', label: '第三方与云平台' }
];

const PROVIDER_FILTERS: JellyTabItem[] = [
  { glyph: '', label: '全部' },
  { glyph: '', label: '已配置' },
  { glyph: '', label: '待配置' }
];

@Component
export struct ProviderManager {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @Prop providers: ProviderEntry[] = [];
  @Prop embedded: boolean = false;
  @Prop readOnly: boolean = false;
  @Prop initialProviderId: string = '';
  @State embeddedDetail: boolean = false;
  @State assistantOpen: boolean = false;
  @StorageProp('auxiliaryModelId') auxiliaryModelId: string = 'builtin';
  @Prop assistantConfigured: boolean = false;
  @State assistantKey: string = '';
  @State editingAssistantKey: boolean = false;
  @State savingAssistantKey: boolean = false;
  onSaveAssistantKey: (key: string) => Promise<void> = async (_key: string): Promise<void> => {};
  @State assistantText: string = '';
  @State assistantBusy: boolean = false;
  @State assistantError: string = '';
  @State draft: ProviderSetupDraft = ProviderSetup.empty();
  onAssist: (draft: ProviderSetupDraft) => Promise<ProviderSetupDraft> = async (draft: ProviderSetupDraft): Promise<ProviderSetupDraft> => draft;
  private embeddedScroller: Scroller = new Scroller();
  onEmbeddedBackHandler: (handler: () => boolean) => void = (_handler: () => boolean): void => {};

  aboutToAppear(): void {
    if (this.embedded) { this.onEmbeddedBackHandler((): boolean => {
      if (this.assistantOpen) { this.assistantOpen = false; this.resetEmbeddedScroll(); return true; }
      if (!this.embeddedDetail) { return false; }
      this.embeddedDetail = false; this.resetEmbeddedScroll(); return true;
    }); }
    const index: number = this.providers.findIndex((provider: ProviderEntry) => provider.id === this.initialProviderId);
    if (this.embedded && index >= 0) { this.openProvider(index); }
  }
  @Link inputs: string[];
  @Link urlInputs: string[];
  @Link modelInputs: string[];
  @Link statuses: string[];
  @Link testTexts: string[];
  @Link protocols: string[];
  @Link extras: string[];
  @Link availableModels: string[][];
  @State groupIndex: number = 0;
  @State fetchingModels: boolean = false;
  @State modelLimit: number = 80;
  @Prop summaryText: string = '';
  @State paths: NavPathStack = new NavPathStack();
  @State selectedIndex: number = 0;
  @State detailTab: number = 0;
  @State displayedDetail: number = 0;
  @State displayedFilter: number = 0;
  @State filterIndex: number = 0;
  @State query: string = '';
  @State modelQuery: string = '';
  @State saving: boolean = false;
  @State testing: boolean = false;
  @State refreshing: boolean = false;
  @StorageProp(LS_BLUR_KEY) blurRadius: number = LS_BLUR_DEFAULT;
  @StorageProp(IMMERSIVE_KEY) immersiveLevel: number = IMMERSIVE_DEFAULT;
  @StorageProp('reduceMotion') reduceMotion: boolean = false;
  onBack: () => void = (): void => {};
  onRequestStart: (sourceId: string) => void = (_sourceId: string): void => {};
  onSave: (index: number) => Promise<void> = async (_index: number): Promise<void> => {};
  onTest: (index: number) => Promise<void> = async (_index: number): Promise<void> => {};
  onRefresh: () => Promise<void> = async (): Promise<void> => {};

  onFetchModels: (index: number) => Promise<void> = async (_index: number): Promise<void> => {};
  onSelectModel: (index: number, model: string) => Promise<void> = async (_index: number, _model: string): Promise<void> => {};

  aboutToDisappear(): void { if (this.embedded) { this.onEmbeddedBackHandler((): boolean => false); } }

  private resetEmbeddedScroll(): void {
    if (!this.embedded) { return; }
    try { this.embeddedScroller.scrollEdge(Edge.Top); } catch (error) { /* Not bound on first mount. */ }
  }

  private backFromDetail(): void {
    if (this.embedded) { this.embeddedDetail = false; this.resetEmbeddedScroll(); }
    else { this.paths.pop(); }
  }

  private configured(index: number): boolean {
    return this.statuses[index] === '✓ 已设置';
  }

  private statusLabel(index: number): string {
    if (this.configured(index)) { return '已配置'; }
    return this.statuses[index] === '未设置' ? '待配置' : '待确认';
  }

  private modelName(index: number): string {
    return this.modelInputs[index].trim();
  }

  private visible(index: number, selection: number): boolean {
    const group: number = Math.floor(selection / PROVIDER_FILTERS.length);
    const filter: number = selection % PROVIDER_FILTERS.length;
    if (this.providers[index].group !== PROVIDER_GROUPS[group].label) { return false; }
    if (filter === 1 && !this.configured(index)) { return false; }
    if (filter === 2 && this.statuses[index] !== '未设置') { return false; }
    const query: string = this.query.trim().toLowerCase();
    return `${this.providers[index].label} ${this.modelName(index)}`.toLowerCase().includes(query);
  }

  private visibleCount(selection: number): number {
    return this.providers.filter((_provider: ProviderEntry, index: number) => this.visible(index, selection)).length;
  }

  private openProvider(index: number): void {
    this.selectedIndex = index;
    this.detailTab = 0;
    this.modelQuery = '';
    this.modelLimit = 80;
    if (this.embedded) { this.embeddedDetail = true; this.resetEmbeddedScroll(); }
    else { this.paths.pushPath({ name: 'providerDetail' }); }
  }

  private openCustom(): void {
    const index: number = this.providers.findIndex((provider: ProviderEntry) => provider.id === 'custom');
    if (index >= 0) { this.openProvider(index); }
  }

  private openAssistant(): void {
    this.assistantError = ''; this.assistantOpen = true;
    if (this.embedded) { this.resetEmbeddedScroll(); }
    else { this.paths.pushPath({ name: 'providerAssistant' }); }
  }
  private async saveAssistantKey(): Promise<void> {
    if (this.assistantBusy || this.savingAssistantKey || this.readOnly) { return; }
    this.savingAssistantKey = true; this.assistantError = '';
    try { await this.onSaveAssistantKey(this.assistantKey); this.assistantKey = ''; this.editingAssistantKey = false; }
    catch (_) { this.assistantError = '保存助手密钥未完成，请检查密钥或稍后重试'; }
    finally { this.savingAssistantKey = false; }
  }
  private async identifyConfiguration(useAI: boolean): Promise<void> {
    if (this.assistantBusy || this.savingAssistantKey || this.readOnly) { return; }
    this.assistantError = ''; this.assistantBusy = true;
    try {
      const local: ProviderSetupDraft = ProviderSetup.parse(this.assistantText);
      ProviderSetup.validate(local);
      this.draft = useAI ? await this.onAssist(local) : local;
    } catch (error) { this.assistantError = (error as Error).message; }
    finally { this.assistantBusy = false; }
  }
  private applyDraft(): void {
    if (this.assistantBusy || this.readOnly) { return; }
    try {
      ProviderSetup.validate(this.draft);
      const index: number = this.providers.findIndex((provider: ProviderEntry): boolean => provider.id === 'custom');
      if (index < 0) { throw new Error('未找到自定义服务商'); }
      this.urlInputs[index] = this.draft.url; this.modelInputs[index] = this.draft.model;
      this.protocols[index] = this.draft.protocol;
      if (this.draft.key !== '') { this.inputs[index] = this.draft.key; }
      this.assistantText = ''; this.draft = ProviderSetup.empty(); this.assistantOpen = false;
      if (!this.embedded) { this.paths.pop(); }
      this.openProvider(index);
    } catch (error) { this.assistantError = (error as Error).message; }
  }

  private async saveCurrent(): Promise<void> {
    if (this.saving || this.testing || this.fetchingModels) { return; }
    this.saving = true;
    try { await this.onSave(this.selectedIndex); }
    finally { this.saving = false; }
  }

  private async testCurrent(): Promise<void> {
    if (this.saving || this.testing || this.fetchingModels) { return; }
    this.testing = true;
    this.onRequestStart('provider-test-anchor');
    try { await this.onTest(this.selectedIndex); }
    finally { this.testing = false; }
  }

  private async refresh(): Promise<void> {
    if (this.refreshing) { return; }
    this.refreshing = true;
    try { await this.onRefresh(); }
    finally { this.refreshing = false; }
  }

  private async fetchCurrent(sourceId: string): Promise<void> {
    if (this.saving || this.testing || this.fetchingModels) { return; }
    this.fetchingModels = true;
    this.onRequestStart(sourceId);
    const index: number = this.selectedIndex;
    try {
      await this.onFetchModels(index);
      if (this.selectedIndex === index) { this.detailTab = 1; }
    }
    finally { this.fetchingModels = false; }
  }

  private async selectModel(model: string): Promise<void> {
    if (this.saving || this.testing || this.fetchingModels) { return; }
    this.saving = true;
    try { await this.onSelectModel(this.selectedIndex, model); }
    finally { this.saving = false; }
  }

  private filteredModels(): string[] {
    const query: string = this.modelQuery.trim().toLowerCase();
    return (this.availableModels[this.selectedIndex] ?? []).filter((model: string) => model.toLowerCase().includes(query));
  }

  @Styles
  card() {
    .width('100%')
    .padding(14)
    .backgroundColor(this.uiColors.bgSurface)
    .borderRadius(24)
    .attributeModifier(new SurfaceStyle(this.uiColors, 24))
    .border({ radius: 24, width: 0.65, color: this.uiColors.glassEdge })
  }

  @Styles
  field() {
    .height(52)
    .backgroundColor(Color.Transparent)
    .padding({ left: 0, right: 0 })
    .borderRadius(0)
  }

  @Builder
  icon(source: Resource) {
    Image(source).width(22).height(22).colorFilter(iconTint(this.uiColors.textPrimary))
  }

  @Builder
  header(detail: boolean) {
    Row({ space: 12 }) {
      HeaderAction({ icon: $r('app.media.icon_back'),
        label: detail ? '返回服务商列表' : (this.embedded ? '关闭模型设置' : '返回设置'),
        onAction: async (): Promise<void> => { if (detail) { this.backFromDetail(); } else { this.onBack(); } } })
        Text(detail ? (this.detailTab === 2 ? '聊天生成设置' : '服务商详情') : '服务商管理')
        .fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.uiColors.textPrimary)
        .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      if (detail) {
        if (this.detailTab !== 2) {
        HeaderAction({ icon: $r('app.media.icon_save'), label: '保存服务商配置', pending: this.saving,
          available: !this.readOnly && !this.testing && !this.fetchingModels,
          onAction: async (): Promise<void> => { await this.saveCurrent(); } })
        }
      } else {
        HeaderAction({ label: '刷新配置状态', marker: 'provider-refresh-action', pending: this.refreshing,
          onAction: async (): Promise<void> => { await this.refresh(); } })
        HeaderAction({ icon: $r('app.media.icon_add'), label: '配置自定义服务商', refresh: false,
          marker: 'provider-create-action', onAction: async (): Promise<void> => { this.openCustom(); } })
      }
    }
    .width('100%').height(72).padding({ left: 16, right: 16 })
  }

  @Builder
  badge(label: string, active: boolean = false) {
    Text(label).fontSize(12).fontWeight(FontWeight.Medium)
      .fontColor(active ? this.uiColors.accent : this.uiColors.textSecondary)
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .backgroundColor(active ? this.uiColors.accentContainer : this.uiColors.bgBase)
      .borderRadius(14)
  }

  @Builder
  providerCard(provider: ProviderEntry, index: number) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 14 }) {
        BrandIcon({ provider: provider.id, diameter: 40, framed: true })
        Column({ space: 6 }) {
          Row({ space: 8 }) {
            Text(provider.label)
              .fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.uiColors.textPrimary)
              .layoutWeight(1).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            Circle().width(7).height(7)
              .fill(this.configured(index) ? this.uiColors.success : this.uiColors.textTertiary)
          }
          .width('100%')
          Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(6), cross: LengthMetrics.vp(6) } }) {
            this.badge(ProviderPreferences.protocolLabel(this.protocols[index]))
            this.badge(this.statusLabel(index), this.configured(index))
          }
          .width('100%')
          Text(this.modelName(index) || '填写地址与模型，连接自己的服务')
            .fontSize(12).fontColor(this.uiColors.textTertiary)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Start)
        Image($r('app.media.icon_chevron')).width(16).height(16).colorFilter(iconTint(this.uiColors.textTertiary))
      }
      .width('100%')
    }
    .card()
    .accessibilityText(`${provider.label}，${this.statusLabel(index)}，查看详情`)
    .onClick(() => { this.openProvider(index); })
  }

  @Builder
  providerResults() {
    Column({ space: 12 }) {
      ForEach(this.providers, (provider: ProviderEntry, index: number) => {
        if (this.visible(index, this.displayedFilter)) { this.providerCard(provider, index) }
      }, (provider: ProviderEntry) => provider.id)
      if (this.visibleCount(this.displayedFilter) === 0) {
        Column({ space: 10 }) {
          Image($r('app.media.icon_cloud')).width(48).height(48).colorFilter(iconTint(this.uiColors.textTertiary))
          Text('没有匹配的服务商').fontSize(16).fontColor(this.uiColors.textSecondary)
          Text('试试其他关键词或配置状态').fontSize(13).fontColor(this.uiColors.textTertiary)
        }
        .width('100%').padding({ top: 32, bottom: 32 })
      }
    }
    .width('100%')
  }

  @Builder
  listContent() {
    Column({ space: 12 }) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 12 }) {
          Image($r('app.media.icon_model')).width(24).height(24).colorFilter(iconTint(this.uiColors.accent))
          Column({ space: 4 }) {
            Text('让 AI 帮我配置').fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.uiColors.textPrimary)
            Text('识别接口示例，生成可编辑的连接配置').fontSize(12).fontColor(this.uiColors.textSecondary)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Image($r('app.media.icon_chevron')).width(16).height(16).colorFilter(iconTint(this.uiColors.textTertiary))
        }.width('100%')
      }.card().id('provider-setup-assistant').enabled(!this.readOnly).onClick((): void => { this.openAssistant(); })
      JellyTabBar({ items: PROVIDER_GROUPS, currentIndex: this.groupIndex, textOnly: true,
        onSelect: (index: number): void => { this.groupIndex = index; } })
      JellyTabBar({ items: PROVIDER_FILTERS, currentIndex: this.filterIndex, textOnly: true,
        onSelect: (index: number): void => { this.filterIndex = index; } })
      Search({ value: this.query, placeholder: '筛选服务商或模型…' })
        .height(48).backgroundColor(this.uiColors.bgSurface).borderRadius(24).attributeModifier(new SurfaceStyle(this.uiColors, 24))
        .border({ width: 1, color: this.uiColors.borderSubtle })
        .fontColor(this.uiColors.textPrimary).placeholderColor(this.uiColors.textTertiary)
        .onChange((value: string): void => { this.query = value; })
      SwingContent({ activeIndex: this.groupIndex * PROVIDER_FILTERS.length + this.filterIndex,
        onDisplay: (index: number): void => { this.displayedFilter = index; },
        content: (): void => { this.providerResults(); } })
      Button({ type: ButtonType.Normal }) {
        Row({ space: 10 }) {
          Image($r('app.media.icon_add')).width(22).height(22).colorFilter(iconTint(this.uiColors.accent))
          Text('配置自定义服务商').fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.uiColors.accent)
        }
        .justifyContent(FlexAlign.Center).width('100%')
      }
      .width('100%').height(48).borderRadius(24).backgroundColor(this.uiColors.bgSurface)
      .onClick(() => { this.openCustom(); })
      if (this.summaryText !== '') {
        Text(this.summaryText).fontSize(12).fontColor(this.uiColors.textSecondary).width('100%')
      }
    }
    .width('100%').padding({ bottom: 16 })
  }

  @Builder
  detailTabs() {
    Row() {
      ForEach(['配置', '模型', '生成'], (label: string, index: number) => {
        Button({ type: ButtonType.Normal }) {
          Column({ space: 10 }) {
            Text(label).fontSize(16).fontWeight(FontWeight.Bold)
              .fontColor(this.detailTab === index ? this.uiColors.accent : this.uiColors.textSecondary)
            Row().width(24).height(3).borderRadius(2)
              .backgroundColor(this.detailTab === index ? this.uiColors.accent : Color.Transparent)
          }
          .padding({ top: 10, bottom: 6 })
        }
        .layoutWeight(1).backgroundColor(Color.Transparent).borderRadius(16)
        .accessibilitySelected(this.detailTab === index)
        .onClick(() => { this.detailTab = index; this.resetEmbeddedScroll(); })
      }, (label: string) => label)
    }
    .width('100%')
  }

  @Builder
  identityCard() {
    Column({ space: 14 }) {
      Row({ space: 14 }) {
        BrandIcon({ provider: this.providers[this.selectedIndex].id, diameter: 52, framed: true })
        Text(this.providers[this.selectedIndex].label)
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.uiColors.textPrimary).layoutWeight(1)
        this.badge(this.statusLabel(this.selectedIndex), this.configured(this.selectedIndex))
      }
      .width('100%')
      this.badge(this.providers[this.selectedIndex].group)
    }
    .alignItems(HorizontalAlign.Start).card()
  }

  @Builder
  sectionLabel(title: string) {
    Text(title).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.uiColors.textSecondary)
      .width('100%').padding({ left: 4 })
  }

  @Builder
  protocolCard() {
    Column({ space: 12 }) {
      Text('接口协议').fontSize(17).fontWeight(FontWeight.Bold).fontColor(this.uiColors.textPrimary).width('100%')
      ForEach(ProviderPreferences.protocols(this.providers[this.selectedIndex]), (option: ProtocolOption) => {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 8 }) {
            Text(option.label).fontSize(14).fontColor(this.protocols[this.selectedIndex] === option.id ? this.uiColors.accent : this.uiColors.textSecondary).layoutWeight(1)
            Text(this.protocols[this.selectedIndex] === option.id ? '✓' : '').fontColor(this.uiColors.accent)
          }.width('100%')
        }
        .width('100%').constraintSize({ minHeight: 44 }).padding(12).borderRadius(16)
        .backgroundColor(this.protocols[this.selectedIndex] === option.id ? this.uiColors.accentContainer : this.uiColors.bgBase)
        .enabled(!this.saving && !this.testing && !this.fetchingModels)
        .accessibilitySelected(this.protocols[this.selectedIndex] === option.id)
        .onClick(() => { this.protocols[this.selectedIndex] = option.id; this.availableModels[this.selectedIndex] = []; })
      }, (option: ProtocolOption) => option.id)
      Text('协议需与服务商提供的接口一致。').fontSize(12).fontColor(this.uiColors.textTertiary).width('100%')
    }.card()
  }

  @Builder
  connectionCard() {
    Column({ space: 0 }) {
      if (this.providers[this.selectedIndex].source === 'custom') {
        Text('服务地址').fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.uiColors.textPrimary).width('100%')
        TextInput({ text: this.urlInputs[this.selectedIndex], placeholder: 'https://api.example.com/v1' })
          .field().fontSize(14).fontColor(this.uiColors.textPrimary).placeholderColor(this.uiColors.textTertiary)
          .type(InputType.URL).enabled(!this.saving && !this.testing && !this.fetchingModels)
          .onChange((value: string) => { this.urlInputs[this.selectedIndex] = value; })
        .attributeModifier(new InputFieldStyle(this.uiColors))
      Divider().color(this.uiColors.borderSubtle).margin({ bottom: 14 })
        Text('填写服务商提供的 API 基础地址').fontSize(12).fontColor(this.uiColors.textTertiary).width('100%')
      } else {
        Row({ space: 12 }) {
          Image($r('app.media.icon_cloud')).width(24).height(24).colorFilter(iconTint(this.uiColors.accent))
          Column({ space: 6 }) {
            Text('内置服务地址').fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.uiColors.textPrimary)
            Text(ProviderPreferences.endpointLabel(this.providers[this.selectedIndex], this.extras[this.selectedIndex]))
              .fontSize(13).fontColor(this.uiColors.textSecondary).wordBreak(WordBreak.BREAK_ALL)
          }
          .layoutWeight(1).alignItems(HorizontalAlign.Start)
        }
        .width('100%')
      }
    }
    .card()
  }

  @Builder
  authenticationCard() {
    Row() {
      Text('认证').fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.uiColors.textSecondary).layoutWeight(1)
      Button(this.testing ? '测试中…' : '测试连接', { type: ButtonType.Normal })
        .id('provider-test-anchor')
        .height(44).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.uiColors.accent)
        .backgroundColor(Color.Transparent).enabled(!this.saving && !this.testing && !this.fetchingModels)
        .onClick(() => { this.testCurrent(); })
    .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
    .width('100%').padding({ left: 4 })
    Column({ space: 8 }) {
      Text(this.providers[this.selectedIndex].keyOptional ? 'API Key（免认证时可留空）' : 'API Key')
        .fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.uiColors.textPrimary).width('100%')
      TextInput({ text: this.inputs[this.selectedIndex],
        placeholder: this.configured(this.selectedIndex) ? '已保存，输入新密钥以更新' : '输入服务商提供的 API Key' })
        .field().fontSize(14).fontColor(this.uiColors.textPrimary).placeholderColor(this.uiColors.textTertiary)
        .type(InputType.Password).showPasswordIcon(true).enabled(!this.saving && !this.testing && !this.fetchingModels)
        .onChange((value: string) => { this.inputs[this.selectedIndex] = value; })
      .attributeModifier(new InputFieldStyle(this.uiColors))
      Divider().color(this.uiColors.borderSubtle)
      Text('测试前保存当前配置，并发送一次简短请求。获取模型不会生成聊天内容。')
        .fontSize(12).fontColor(this.uiColors.textTertiary).lineHeight(19).width('100%')
      Text('密钥以明文保存在应用私有目录，请妥善保护设备。')
        .fontSize(12).fontColor(this.uiColors.textTertiary).lineHeight(19).width('100%')
    }
    .card()
  }

  @Builder
  modelEditor() {
    Column({ space: 8 }) {
      Text('模型名称').fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.uiColors.textPrimary).width('100%')
      TextInput({ text: this.modelInputs[this.selectedIndex], placeholder: '例如 gpt-4o' })
        .field().fontSize(14).fontColor(this.uiColors.textPrimary).placeholderColor(this.uiColors.textTertiary)
        .enabled(!this.saving && !this.testing && !this.fetchingModels)
        .onChange((value: string) => { this.modelInputs[this.selectedIndex] = value; })
      .attributeModifier(new InputFieldStyle(this.uiColors))
      Divider().color(this.uiColors.borderSubtle)
      Text('可从获取的列表中选择，也可手动输入模型 ID。保存后供聊天使用，无需重复输入已保存的密钥。')
        .fontSize(12).fontColor(this.uiColors.textTertiary).lineHeight(19).width('100%')
    }
    .card()
  }

  @Builder
  configuration() {
    this.identityCard()
    this.protocolCard()
    this.sectionLabel('连接')
    this.connectionCard()
    if (this.providers[this.selectedIndex].extraLabel !== '') {
      Column({ space: 8 }) {
        Text(this.providers[this.selectedIndex].extraLabel).fontSize(15).fontColor(this.uiColors.textPrimary).width('100%')
        TextInput({ text: this.extras[this.selectedIndex], placeholder: this.providers[this.selectedIndex].extraDefault })
          .field().fontColor(this.uiColors.textPrimary).placeholderColor(this.uiColors.textTertiary)
          .enabled(!this.saving && !this.testing && !this.fetchingModels)
          .onChange((value: string) => { this.extras[this.selectedIndex] = value; })
      .attributeModifier(new InputFieldStyle(this.uiColors))
      }.card()
    }
    this.authenticationCard()
    Button(this.fetchingModels ? '正在获取模型…' : '保存并获取模型', { type: ButtonType.Normal })
      .id('provider-models-anchor')
      .width('100%').height(48).fontColor(this.uiColors.textInverse).backgroundColor(this.uiColors.accent)
      .enabled(!this.saving && !this.testing && !this.fetchingModels)
      .onClick(() => { this.fetchCurrent('provider-models-anchor'); })
    .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      this.sectionLabel('默认模型')
    this.modelEditor()
  }

  @Builder
  models() {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Text((this.availableModels[this.selectedIndex] ?? []).length + ' 个已获取模型').fontSize(15).fontColor(this.uiColors.textPrimary).layoutWeight(1)
        HeaderAction({ label: '刷新模型列表', marker: 'provider-models-refresh-anchor', pending: this.fetchingModels,
          available: !this.saving && !this.testing && !this.readOnly,
          onAction: async (): Promise<void> => { await this.fetchCurrent('provider-models-refresh-anchor'); } })
      }.width('100%')
      Search({ value: this.modelQuery, placeholder: '搜索模型 ID…' })
        .height(44).backgroundColor(this.embedded ? Color.Transparent : this.uiColors.bgBase).fontColor(this.uiColors.textPrimary).placeholderColor(this.uiColors.textTertiary)
        .onChange((value: string) => { this.modelQuery = value; this.modelLimit = 80; })
      Text('当前默认：' + (this.modelName(this.selectedIndex) || '尚未选择')).fontSize(13).fontColor(this.uiColors.textSecondary).width('100%')
    }.card()
    ForEach(this.filteredModels().slice(0, this.modelLimit), (model: string) => {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 12 }) {
          BrandIcon({ model: model, diameter: 24 })
          Text(model).fontSize(14).fontColor(this.uiColors.textPrimary).wordBreak(WordBreak.BREAK_ALL).layoutWeight(1)
          Text(model === this.modelName(this.selectedIndex) ? '✓' : '').fontColor(this.uiColors.accent)
        }.width('100%')
      }
      .card().enabled(!this.saving && !this.testing && !this.fetchingModels)
      .accessibilityText('选择模型 ' + model).accessibilitySelected(model === this.modelName(this.selectedIndex))
      .onClick(() => { this.selectModel(model); })
    }, (model: string) => model)
    if (this.filteredModels().length > this.modelLimit) {
      Button('显示更多模型', { type: ButtonType.Normal }).width('100%').height(44).fontColor(this.uiColors.accent).backgroundColor(this.uiColors.accentContainer)
        .onClick(() => { this.modelLimit += 80; })
    .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
    if (this.filteredModels().length === 0) {
      Text(this.modelQuery === '' ? '尚无模型列表，请点击获取；接口不支持时可手动填写。' : '没有匹配的模型')
        .fontSize(14).fontColor(this.uiColors.textSecondary).width('100%').padding(20)
    }
    this.modelEditor()
  }

  @Builder
  detailPanel() {
    Column({ space: 16 }) {
      if (this.displayedDetail === 0) { this.configuration() }
      else if (this.displayedDetail === 1) { this.models() }
      else { NativePreferencesPanel({ identity: false, generationOnly: true }) }
    }
    .width('100%')
    .enabled(!this.readOnly)
  }

  @Builder
  detailContent() {
    Column({ space: 16 }) {
      this.detailTabs()
      this.detailBody()
    }.width('100%')
  }

  @Builder
  detailBody() {
    Column({ space: 16 }) {
      SwingContent({ activeIndex: this.detailTab,
        onDisplay: (index: number): void => { this.displayedDetail = index; },
        content: (): void => { this.detailPanel(); } })
      if (this.testTexts[this.selectedIndex] !== '') {
        Text(this.testTexts[this.selectedIndex]).fontSize(13).lineHeight(20)
          .fontColor(this.testTexts[this.selectedIndex].startsWith('✓') ? this.uiColors.success : this.uiColors.textSecondary)
          .width('100%').padding(16).backgroundColor(this.uiColors.bgSurface).borderRadius(18).attributeModifier(new SurfaceStyle(this.uiColors, 18))
      }
      if (this.summaryText !== '') {
        Text(this.summaryText).fontSize(13).fontColor(this.uiColors.textSecondary).width('100%').padding({ left: 4 })
      }
    }
    .width('100%').padding({ bottom: 20 })
  }

  @Builder
  assistantHeader() {
    Row({ space: 12 }) {
      HeaderAction({ icon: $r('app.media.icon_back'), label: '返回服务商管理', refresh: false,
        onAction: async (): Promise<void> => { this.assistantOpen = false; if (this.embedded) { this.resetEmbeddedScroll(); } else { this.paths.pop(); } } })
      Text('让 AI 帮我配置').fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.uiColors.textPrimary).layoutWeight(1)
    }.width('100%').height(64).padding({ left: 16, right: 16 })
  }
  @Builder
  assistantContent() {
    Column({ space: 12 }) {
      Text('当前辅助模型：' + AuxiliaryModels.selected().label).fontSize(14).fontColor(this.uiColors.textPrimary).width('100%')
      Text('可在设置 → 模型与连接 → 辅助模型设置中切换。').fontSize(12).fontColor(this.uiColors.textSecondary).width('100%')
      if (this.auxiliaryModelId === 'builtin') {
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          Text('内置 Qwen 助手').fontSize(15).fontWeight(FontWeight.Bold).fontColor(this.uiColors.textPrimary).layoutWeight(1)
          Text(this.assistantConfigured ? '已配置' : '待配置密钥').fontSize(12).fontColor(this.assistantConfigured ? this.uiColors.success : this.uiColors.textSecondary)
        }.width('100%')
        Text('Qwen/Qwen3.5-4B · 硅基流动 · 联网生成').fontSize(12).fontColor(this.uiColors.textSecondary).width('100%')
        if (!this.assistantConfigured || this.editingAssistantKey) {
          TextInput({ text: this.assistantKey, placeholder: '硅基流动 API Key' }).type(InputType.Password)
            .attributeModifier(new InputFieldStyle(this.uiColors)).id('builtin-assistant-key').enabled(!this.savingAssistantKey && !this.assistantBusy)
            .onChange((value: string): void => { this.assistantKey = value; })
          Button(this.savingAssistantKey ? '正在保存…' : '保存助手密钥').attributeModifier(new ActionButtonStyle(this.uiColors)).width('100%')
            .id('builtin-assistant-save-key').enabled(!this.savingAssistantKey && !this.assistantBusy && this.assistantKey.trim() !== '')
            .onClick((): void => { this.saveAssistantKey(); })
        } else {
          Button('更换密钥').attributeModifier(new ActionButtonStyle(this.uiColors)).height(44)
            .id('builtin-assistant-change-key')
            .onClick((): void => { this.editingAssistantKey = true; })
        }
      }.card()
      }
      Text('粘贴服务地址、JSON 或 curl 示例。先在本机提取配置；AI 整理仅发送提取后的地址、模型和协议。').fontSize(13).lineHeight(20).fontColor(this.uiColors.textSecondary)
      TextArea({ text: this.assistantText, placeholder: '例如 https://example.com/v1/chat/completions，或包含 model 的接口示例' })
        .attributeModifier(new TextAreaFieldStyle(this.uiColors)).height(144).maxLength(16000).id('provider-setup-input')
        .enabled(!this.assistantBusy).onChange((value: string): void => { this.assistantText = value; this.draft = ProviderSetup.empty(); })
      Row({ space: 10 }) {
        Button('本机识别').attributeModifier(new ActionButtonStyle(this.uiColors)).layoutWeight(1)
          .enabled(!this.assistantBusy && !this.savingAssistantKey && this.assistantText.trim() !== '').onClick((): void => { this.identifyConfiguration(false); })
        Button(this.assistantBusy ? '正在整理…' : 'AI 整理').attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary)).layoutWeight(1)
          .enabled(!this.assistantBusy && !this.savingAssistantKey && (this.auxiliaryModelId !== 'builtin' || this.assistantConfigured) && this.assistantText.trim() !== '').id('provider-setup-ai').onClick((): void => { this.identifyConfiguration(true); })
      }.width('100%')
      Text('AI 整理使用所选辅助模型，会产生该服务的请求用量。仅发送提取后的地址、模型和协议，密钥和原始示例不发送给助手。').fontSize(12).lineHeight(19).fontColor(this.uiColors.textSecondary)
      if (this.assistantError !== '') { Text(this.assistantError).fontSize(13).fontColor(this.uiColors.danger).width('100%') }
      if (this.draft.url !== '') {
        Column({ space: 10 }) {
          Text('核对连接草稿').fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.uiColors.textPrimary).width('100%')
          TextInput({ text: this.draft.url, placeholder: 'API 基础地址' }).attributeModifier(new InputFieldStyle(this.uiColors))
            .enabled(!this.assistantBusy).onChange((value: string): void => { this.draft.url = value; this.draft = ProviderSetup.copy(this.draft); })
          TextInput({ text: this.draft.model, placeholder: '模型 ID（也可稍后获取）' }).attributeModifier(new InputFieldStyle(this.uiColors))
            .enabled(!this.assistantBusy).onChange((value: string): void => { this.draft.model = value; this.draft = ProviderSetup.copy(this.draft); })
          Text(ProviderPreferences.protocolLabel(this.draft.protocol)).fontSize(13).fontColor(this.uiColors.textSecondary).width('100%')
          Text(this.draft.note).fontSize(12).lineHeight(19).fontColor(this.uiColors.textSecondary).width('100%')
          Button('填入自定义服务商').attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary)).width('100%')
            .enabled(!this.assistantBusy).onClick((): void => { this.applyDraft(); })
          Text('填写后可继续修改、保存并测试连接。').fontSize(12).fontColor(this.uiColors.textSecondary)
        }.card()
      }
    }.width('100%').padding({ bottom: 20 })
  }

  @Builder
  destination(name: string) {
    if (name === 'providerAssistant') {
      NavDestination() { PageSurface({ topBar: (): void => { this.assistantHeader(); }, content: (): void => { this.assistantContent(); }, topContentInset: 84 }) }
        .hideTitleBar(true).backgroundColor(this.uiColors.bgBase)
    } else if (name === 'providerDetail') {
      NavDestination() {
        if (this.embedded) { this.embeddedSurface() }
        else { PageSurface({ topBar: () => { this.header(true); }, content: () => { this.detailContent(); } }) }
      }
      .hideTitleBar(true).backgroundColor(this.embedded ? Color.Transparent : this.uiColors.bgBase)
      .systemTransition(this.reduceMotion ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.SLIDE_RIGHT)
    }
  }

  @Builder
  embeddedSurface() {
    Column({ space: 12 }) {
      if (this.assistantOpen) { this.assistantHeader() } else if (this.embeddedDetail) { this.header(true); this.detailTabs() } else { this.header(false) }
      Scroll(this.embeddedScroller) {
        Column() {
          if (this.assistantOpen) { this.assistantContent() } else if (this.embeddedDetail) { this.detailBody() } else { this.listContent() }
        }.width('100%')
      }.width('100%').layoutWeight(1).scrollBar(BarState.Auto)
    }.width('100%').height('100%').padding({ left: 16, right: 16, top: 12, bottom: 16 })
  }

  build() {
    if (this.embedded) {
      this.embeddedSurface()
    } else {
    Navigation(this.paths) {
      if (this.embedded) { this.embeddedSurface() }
      else { PageSurface({ topBar: () => { this.header(false); }, content: () => { this.listContent(); }, topContentInset: 84 }) }
    }
    .mode(NavigationMode.Stack).hideTitleBar(true).hideToolBar(true)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .navDestination(this.destination).width('100%').height('100%').backgroundColor(this.embedded ? Color.Transparent : this.uiColors.bgBase)
    }
  }
}
