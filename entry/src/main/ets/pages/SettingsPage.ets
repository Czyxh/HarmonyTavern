import { BuiltinAssistant } from '../backend/BuiltinAssistant';
import { ProviderSetup, ProviderSetupDraft } from '../backend/ProviderSetup';
import { ActionButtonStyle, ActionTone, InputFieldStyle, TextAreaFieldStyle } from '../theme/ControlStyles';
import { HeaderAction } from '../components/HeaderAction';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { PageSurface } from '../components/PageSurface';
import { OriginMotion } from '../theme/OriginMotion';
import { SCROLL_EDGE_OPTIONS, SCROLL_NESTED_OPTIONS } from '../theme/ScrollFeedback';
import { ProviderManager } from '../components/ProviderManager';
import { AuxiliaryModels } from '../backend/AuxiliaryModels';
import { PROVIDERS, ProviderEntry, ProviderConfig, ProviderPreferences, ProviderSecretState, ProviderModelList } from '../backend/ProviderCatalog';
import { PageHeader } from '../components/PageHeader';
import { Radius as UIRadius, Typography as UIType } from '../theme/Tokens';
// P5 设置页 + P7 步骤 3b（预设管理 / 系统提示词 / 模型目录）。
//
// 密钥写入走 `write_secret`，读取状态走 `read_secret_state`。密钥名与 Rust 侧
// `SecretKeys` 常量一一对应（tt-domain/src/models/secret.rs）：
//   api_key_deepseek / api_key_moonshot / api_key_zai / api_key_siliconflow / api_key_minimax
// 生成 payload 不传 secret_id 时，后端按 `api_key_<source>` 自动取用（config.rs
// read_selected_secret），所以这里的名字就是「连通性」本身，错一个字符就报
// "API key is missing"。
//
// 「测试连接」走非流式 `generate_chat_completion`（requestId + 扁平 snake dto），
// 每次真实调用一次 provider；端点未授权时复用聊天页的三步握手（弹窗 → grant → 重试）。
//
// P7 步骤 3b（全部走 P6.1 已就绪命令，零新 Rust）：
//   1. 预设管理：list_presets / get_preset / delete_preset / save_preset
//      （apiId ∈ openai|sysprompt|context|instruct|reasoning|novel，PresetType::from_api_id）；
//   2. 系统提示词：resolve_agent_system_prompt（空 profileId = 默认装配）→ agentSystemPrompt；
//   3. 模型目录：get_openrouter_model_providers / get_nanogpt_model_providers（按模型名查提供方）。
//
// 刻意不做：密钥「查看」—— `view_secrets` 在 allow_keys_exposure=false 时会被后端拒绝，
// 设置页只显示「已设置 / 未设置」，不显示明文。
//
// 对应 DevEco 工程路径：entry/src/main/ets/pages/SettingsPage.ets
import { hilog } from '@kit.PerformanceAnalysisKit';
import { router } from '@kit.ArkUI';
import { Backend, BackendError } from '../backend/Backend';
import { ROOT_PATH_STACK } from '../nav/RootNav';
import { GLASS_CARD } from '../theme/Glass';
import { Radius, Spacing, Typography } from '../theme/Tokens';
import {
  AgentResolveSystemPromptResultDto,
  DeletePresetDto,
  GenerateRequestDto,
  ProviderRequestDto,
  ProviderModelProvidersRequestDto,
  SavePresetDto,
  SavePresetResponseDto
} from '../backend/Types';


const DOMAIN: number = 0x0003;
const TAG: string = 'HarmonyTavern';
const ENDPOINT_AUTH_REQUIRED_PREFIX: string = 'endpoint_authorization_required|';


/** P7 步骤 3b：预设 apiId（PresetType::from_api_id 的合法值子集）。 */
const PRESET_APIS: string[] = ['openai', 'sysprompt', 'context', 'instruct', 'reasoning', 'novel'];

@Component
export struct SettingsPage {
  private requestSourceId: string = '';
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @Prop providerOnly: boolean = false;
  @Prop embedded: boolean = false;
  @Prop readOnly: boolean = false;
  @Prop initialProviderId: string = '';
  onClose: () => void = (): void => { ROOT_PATH_STACK.pop(); };
  onProviderChanged: () => void = (): void => {};
  onEmbeddedBackHandler: (handler: () => boolean) => void = (_handler: () => boolean): void => {};
  @State inputs: string[] = new Array(PROVIDERS.length).fill('');
  @State urlInputs: string[] = new Array(PROVIDERS.length).fill('');
  @State modelInputs: string[] = new Array(PROVIDERS.length).fill('');
  @State statuses: string[] = new Array(PROVIDERS.length).fill('未知');
  @State testTexts: string[] = new Array(PROVIDERS.length).fill('');
  @State summaryText: string = '';
  @State assistantConfigured: boolean = false;
  @State protocols: string[] = PROVIDERS.map((provider: ProviderEntry) => provider.protocol);
  @State extras: string[] = PROVIDERS.map((provider: ProviderEntry) => provider.extraDefault);
  @State availableModels: string[][] = PROVIDERS.map((): string[] => []);
  // P7 步骤 3b 状态
  @State presetApiId: string = 'openai';
  @State presetNames: string[] = [];
  @State presetListText: string = '未加载';
  @State presetView: string = '';
  @State selectedPreset: string = '';
  @State newPresetName: string = '';
  @State newPresetJson: string = '';
  @State presetOpText: string = '';
  @State sysPromptText: string = '';
  @State modelQuery: string = 'gpt-4o';
  @State providersText: string = '';

  aboutToAppear(): void {
    // 后端未初始化（进程恢复/直接冷启到本页）：回首页走完整初始化流程，避免
    // 每个命令都报 "Backend is not initialized"。
    if (!Backend.isReady()) {
      this.summaryText = '后端未就绪，跳回首页初始化…';
      ROOT_PATH_STACK.pop();
      return;
    }
    this.refreshStatus();
  }

  async refreshStatus(loadFields: boolean = true): Promise<void> {
    try {
      const state: Record<string, ProviderSecretState[]> = await Backend.readSecretState() as Record<string, ProviderSecretState[]>;
      ProviderPreferences.hydrate(state);
      this.assistantConfigured = await BuiltinAssistant.configured();
      this.statuses = PROVIDERS.map((provider: ProviderEntry): string =>
        ProviderPreferences.configured(provider, state) ? '✓ 已设置' : '未设置');
      if (loadFields) {
        this.urlInputs = PROVIDERS.map((provider: ProviderEntry) => ProviderPreferences.get(provider).url);
        this.modelInputs = PROVIDERS.map((provider: ProviderEntry) => ProviderPreferences.get(provider).model);
        this.protocols = PROVIDERS.map((provider: ProviderEntry) => ProviderPreferences.get(provider).protocol);
        this.extras = PROVIDERS.map((provider: ProviderEntry) => ProviderPreferences.get(provider).extra);
        this.availableModels = PROVIDERS.map((provider: ProviderEntry) => ProviderPreferences.get(provider).models);
      }
      this.summaryText = '已配置 ' + this.statuses.filter((value: string) => value === '✓ 已设置').length + ' 个服务商';
    } catch (err) {
      this.summaryText = '读取配置失败：' + (err as Error).message;
    }
  }

  private async saveProvider(index: number): Promise<ProviderConfig> {
    if (this.readOnly) { throw new Error('请先停止当前回复，再修改模型连接'); }
    const provider: ProviderEntry = PROVIDERS[index];
    const config: ProviderConfig = ProviderPreferences.get(provider);
    const key: string = this.inputs[index].trim();
    let address: string = this.urlInputs[index].trim();
    const protocol: string = this.protocols[index];
    if (provider.source === 'custom') {
      if (address === '' || address.includes('*')) { throw new Error('请填写完整的 API 基础地址'); }
      if (/[?#@]/.test(address)) { throw new Error('请填写不含账号、查询参数或片段的 API 基础地址'); }
      address = Backend.normalizeBaseUrl(address).replace(/\/(responses|messages|models|interactions)$/, '');
      if (!/^https?:\/\/[^\s/]+/i.test(address)) { throw new Error('服务地址需要使用 http:// 或 https://'); }
    }
    if (key === '' && config.secretId === '' && !provider.keyOptional) { throw new Error('请先输入 API Key'); }
    const extra: string = this.extras[index].trim();
    if (provider.extraLabel !== '' && extra === '') { throw new Error('请填写' + provider.extraLabel); }
    if (['moonshot', 'siliconflow', 'minimax'].includes(provider.source) && !['cn', 'global'].includes(extra)) {
      throw new Error('区域请填写 cn 或 global');
    }
    if (provider.source === 'opencode' && !['zen', 'go'].includes(extra)) { throw new Error('服务请填写 zen 或 go'); }
    if (config.url !== address || config.protocol !== protocol || config.extra !== extra) {
      config.models = [];
      this.availableModels[index] = [];
    }
    if (key !== '' || (provider.keyOptional && config.secretId === '')) {
      config.secretId = await Backend.writeSecret(provider.secretKey, key, provider.label);
      this.inputs[index] = '';
    }
    config.url = address;
    config.protocol = protocol;
    config.extra = extra;
    config.model = this.modelInputs[index].trim();
    config.saved = true;
    ProviderPreferences.put(config);
    this.urlInputs[index] = address;
    await this.refreshStatus(false);
    return config;
  }

  async save(index: number): Promise<void> {
    try {
      const config: ProviderConfig = await this.saveProvider(index);
      if (config.model !== '') { ProviderPreferences.activate(config.id); this.onProviderChanged(); }
      this.summaryText = PROVIDERS[index].label + (config.model === '' ? '：已保存，请获取或填写模型' : '：已保存，聊天默认使用此服务与模型');
    } catch (err) { this.summaryText = '保存失败：' + (err as Error).message; }
  }

  private async callWithEndpointAuth(operation: () => Promise<ESObject>): Promise<ESObject> {
    try { return await operation(); }
    catch (err) {
      const failure: BackendError = err as BackendError;
      const prefixIndex: number = failure.message.indexOf(ENDPOINT_AUTH_REQUIRED_PREFIX);
      if (failure.code !== 'unauthorized' || prefixIndex < 0) { throw new Error(failure.message); }
      const endpoint: string = failure.message.substring(prefixIndex + ENDPOINT_AUTH_REQUIRED_PREFIX.length);
      if (!await this.confirmEndpoint(endpoint)) { throw new Error('已取消：未授权端点'); }
      await Backend.grantUserEndpointAccess(endpoint);
      return await operation();
    }
  }

  async fetchModels(index: number): Promise<void> {
    this.testTexts[index] = '正在保存配置并获取模型…';
    try {
      const config: ProviderConfig = await this.saveProvider(index);
      const dto: ProviderRequestDto = {};
      ProviderPreferences.apply(dto, PROVIDERS[index], config);
      const response: ProviderModelList = await this.callWithEndpointAuth(
        async (): Promise<ESObject> => await Backend.getChatCompletionModels(dto)) as ProviderModelList;
      if (response.bypass === true) {
        this.testTexts[index] = '此服务暂不提供自动模型列表，请手动填写模型 ID 后保存。';
        return;
      }
      const models: string[] = ProviderPreferences.modelIds(response);
      config.models = models;
      ProviderPreferences.put(config);
      this.availableModels[index] = models;
      this.testTexts[index] = models.length > 0 ? '✓ 已获取 ' + models.length + ' 个模型，点击选择默认模型' : '服务返回了空列表，可以手动填写模型 ID。';
    } catch (err) {
      this.testTexts[index] = '获取模型未完成：' + (err as Error).message + '\n可核对地址、协议和密钥后重试，或手动填写模型 ID。';
    }
  }

  async selectModel(index: number, model: string): Promise<void> {
    this.modelInputs[index] = model;
    await this.save(index);
  }

  private async assistConfiguration(local: ProviderSetupDraft): Promise<ProviderSetupDraft> {
    if (this.readOnly) { throw new Error('请先停止当前回复，再整理连接配置'); }
    const dto: GenerateRequestDto = await AuxiliaryModels.route(BuiltinAssistant.configurationRequest(local), true);
    this.requestSourceId = 'provider-setup-ai';
    const response: ESObject = await this.callWithEndpointAuth(async (): Promise<ESObject> =>
      await Backend.generateChatCompletion('provider_setup_' + Date.now(), dto));
    return BuiltinAssistant.result(local, response);
  }

  async testConnection(index: number): Promise<void> {
    this.testTexts[index] = '测试中…';
    try {
      const config: ProviderConfig = await this.saveProvider(index);
      if (config.model === '') { throw new Error('请先获取并选择模型，或手动填写模型 ID'); }
      const dto: GenerateRequestDto = { model: config.model, stream: false,
        temperature: 0.5, max_tokens: 32, messages: [{ role: 'user', content: 'ping' }] };
      ProviderPreferences.apply(dto, PROVIDERS[index], config);
      const requestId: string = 'test_' + Date.now();
      await this.callWithEndpointAuth(async (): Promise<ESObject> => await Backend.generateChatCompletion(requestId, dto));
      this.testTexts[index] = '✓ 连接成功（当前密钥、端点与模型可用）';
    } catch (err) { this.testTexts[index] = '测试未完成：' + (err as Error).message; }
  }

  /** 端点授权确认弹窗（zh-CN 文案，与 ChatPage 一致，照搬上游 user_endpoint_access.rs）。 */
  private confirmEndpoint(endpoint: string): Promise<boolean> {
    const httpWarning: string = endpoint.startsWith('http://')
      ? '\n此 HTTP 连接未加密，传输内容可能被观察或修改。' : '';
    const message: string =
      `端点：${endpoint}\n\n` +
      '第三方扩展也可能发起此请求。仅当这是你刚刚配置并认识的端点时继续；' +
      'TauriTavern 可能向它发送 API 密钥、提示词和聊天内容。该端点后续将保持信任，请谨慎授权。' +
      httpWarning;
    return new Promise<boolean>((resolve: (value: boolean) => void) => {
      this.getUIContext().showAlertDialog({
        title: '允许连接到自定义端点？',
        alignment: DialogAlignment.Center,
        transition: OriginMotion.dialog(this.getUIContext(), this.requestSourceId),
        message: message,
        cancel: () => { resolve(false); },
        primaryButton: {
          value: '信任并连接',
          action: () => { resolve(true); }
        },
        secondaryButton: {
          value: '取消',
          action: () => { resolve(false); }
        }
      });
    });
  }

  // ---- P7 步骤 3b：预设管理 / 系统提示词 / 模型目录 ----

  async refreshPresets(): Promise<void> {
    this.presetListText = '加载中…';
    try {
      const names: string[] = await Backend.listPresets(this.presetApiId);
      this.presetNames = names;
      this.presetListText = names.length > 0
        ? `共 ${names.length} 个（${this.presetApiId}）` : `（${this.presetApiId} 无预设）`;
    } catch (err) {
      this.presetListText = `加载失败：${(err as BackendError).message}`;
    }
  }

  async viewPreset(name: string): Promise<void> {
    this.selectedPreset = name;
    this.presetView = '加载中…';
    try {
      const data: ESObject = await Backend.getPreset(name, this.presetApiId);
      this.presetView = JSON.stringify(data);
    } catch (err) {
      this.presetView = `读取失败：${(err as BackendError).message}`;
    }
  }

  async deletePreset(name: string): Promise<void> {
    const ok: boolean = await new Promise<boolean>((resolve: (value: boolean) => void) => {
      this.getUIContext().showAlertDialog({
        title: '删除预设',
        alignment: DialogAlignment.Center,
        transition: OriginMotion.dialog(this.getUIContext(), 'preset-delete-' + name),
        message: `确定删除预设「${name}」（${this.presetApiId}）？其关联的 Agent Skill 也会被清理。`,
        primaryButton: {
          value: '删除',
          action: () => { resolve(true); }
        },
        secondaryButton: {
          value: '取消',
          action: () => { resolve(false); }
        }
      });
    });
    if (!ok) {
      return;
    }
    try {
      const dto: DeletePresetDto = { name: name, apiId: this.presetApiId };
      await Backend.deletePreset(dto);
      this.presetOpText = `已删除 ${name}`;
      this.presetView = '';
      await this.refreshPresets();
    } catch (err) {
      this.presetOpText = `删除失败：${(err as BackendError).message}`;
    }
  }

  async saveNewPreset(): Promise<void> {
    const name: string = this.newPresetName.trim();
    if (name === '') {
      this.presetOpText = '请输入预设名';
      return;
    }
    let preset: ESObject;
    try {
      preset = JSON.parse(this.newPresetJson) as ESObject;
    } catch (err) {
      this.presetOpText = `JSON 解析失败：${(err as Error).message}`;
      return;
    }
    try {
      const dto: SavePresetDto = { name: name, apiId: this.presetApiId, preset: preset };
      const resp: SavePresetResponseDto = await Backend.savePreset(dto);
      this.presetOpText = `已保存：${resp.name}`;
      await this.refreshPresets();
    } catch (err) {
      this.presetOpText = `保存失败：${(err as BackendError).message}`;
    }
  }

  /** 解析默认装配的系统提示词（空 profileId = 全局默认装配）。 */
  async resolveSystemPrompt(): Promise<void> {
    this.sysPromptText = '解析中…';
    try {
      const result: AgentResolveSystemPromptResultDto = await Backend.resolveAgentSystemPrompt({});
      this.sysPromptText = result.agentSystemPrompt;
    } catch (err) {
      this.sysPromptText = `解析失败：${(err as BackendError).message}`;
    }
  }

  /** 模型目录：按模型名查 OpenRouter / NanoGPT 的提供方列表（需联网）。 */
  async fetchModelProviders(which: string): Promise<void> {
    const dto: ProviderModelProvidersRequestDto = { model: this.modelQuery.trim() };
    this.providersText = '查询中…（需联网）';
    try {
      if (which === 'openrouter') {
        const list: ESObject = await Backend.getOpenrouterModelProviders(dto);
        this.providersText = `OpenRouter 提供方（${dto.model}）：\n${JSON.stringify(list)}`;
      } else {
        const list: ESObject = await Backend.getNanogptModelProviders(dto);
        this.providersText = `NanoGPT 提供方（${dto.model}）：\n${JSON.stringify(list)}`;
      }
    } catch (err) {
      this.providersText = `查询失败：${(err as BackendError).message}`;
    }
  }



  @Builder
  creationSettings() {
      // ---- P7 步骤 3b：预设管理 ----
      Text('生成预设')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(PRESET_APIS, (apiId: string) => {
          Button(apiId, { type: ButtonType.Normal })
            .fontSize(UIType.micro)
            .constraintSize({ minHeight: 44 })
            .fontColor(this.presetApiId === apiId ? this.uiColors.accent : this.uiColors.textSecondary)
            .backgroundColor(this.presetApiId === apiId ? this.uiColors.accentContainer : this.uiColors.bgSurfaceHigh)
            .onClick(() => {
              this.presetApiId = apiId;
              this.refreshPresets();
            })
        .attributeModifier(new ActionButtonStyle(this.uiColors, (this.presetApiId === apiId) ? ActionTone.Selected : ActionTone.Normal))
      }, (apiId: string) => apiId)
      }
      .width('100%')

      Row({ space: 6 }) {
        Text(this.presetListText)
          .fontSize(UIType.micro)
          .opacity(0.8)
          .layoutWeight(1)
        HeaderAction({ label: '刷新', marker: 'settingspage-refresh-1', available: true,
          onAction: async (): Promise<void> => { await this.refreshPresets(); } })
      }
      .width('100%')

      if (this.presetNames.length > 0) {
        List({ space: 4 }) {
          ForEach(this.presetNames, (name: string) => {
            ListItem() {
              Row({ space: 6 }) {
                Text(name)
                  .fontSize(UIType.caption)
                  .layoutWeight(1)
                  .onClick(() => {
                    this.viewPreset(name);
                  })
                Button('删', { type: ButtonType.Normal })
                  .id('preset-delete-' + name)
                  .fontSize(UIType.micro)
                  .height(44)
                  .backgroundColor(this.uiColors.danger)
                  .onClick(() => {
                    this.deletePreset(name);
                  })
              .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Danger))
      }
              .width('100%')
              .padding(6)
              .backgroundColor(this.uiColors.bgSurface)
            .border({ width: 1, color: this.uiColors.borderSubtle })
              .borderRadius(UIRadius.sm)
            }
          }, (name: string) => `${name}_${this.presetApiId}`)
        }
        .height(Math.min(this.presetNames.length * 64, 160))
        .edgeEffect(EdgeEffect.Spring, SCROLL_EDGE_OPTIONS)
        .nestedScroll(SCROLL_NESTED_OPTIONS)
      }

      if (this.presetView !== '') {
        Text(this.selectedPreset !== '' ? `预览：${this.selectedPreset}` : '')
          .fontSize(UIType.micro)
          .opacity(0.7)
        Text(this.presetView)
          .fontSize(UIType.micro)
          .width('100%')
          .maxLines(6)
          .opacity(0.8)
      }

      Column({ space: 4 }) {
        TextInput({ placeholder: '新预设名', text: this.newPresetName })
          .fontColor(this.uiColors.textPrimary)
          .placeholderColor(this.uiColors.textTertiary)
          .backgroundColor(this.uiColors.bgSurfaceHigh)
          .borderRadius(UIRadius.sm)
          .fontSize(UIType.caption)
          .width('100%')
          .onChange((value: string) => {
            this.newPresetName = value;
          })
        .attributeModifier(new InputFieldStyle(this.uiColors))
      TextArea({ placeholder: '预设 JSON（按该 apiId 的格式，如 {"system_prompt": "…"}）', text: this.newPresetJson })
          .fontColor(this.uiColors.textPrimary)
          .placeholderColor(this.uiColors.textTertiary)
          .backgroundColor(this.uiColors.bgSurfaceHigh)
          .borderRadius(UIRadius.sm)
          .fontSize(UIType.micro)
          .width('100%')
          .height(80)
          .onChange((value: string) => {
            this.newPresetJson = value;
          })
        .attributeModifier(new TextAreaFieldStyle(this.uiColors))
      Button('保存为新预设', { type: ButtonType.Normal })
          .fontSize(UIType.caption)
          .onClick(() => {
            this.saveNewPreset();
          })
      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      }
      .width('100%')

      Text(this.presetOpText)
        .fontSize(UIType.micro)
        .fontColor(this.presetOpText.startsWith('已') ? this.uiColors.success : this.uiColors.danger)
        .width('100%')

      // ---- P7 步骤 3b：系统提示词查看器 ----
      Text('系统提示词')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .width('100%')
      Button('解析默认系统提示词', { type: ButtonType.Normal })
        .fontSize(UIType.caption)
        .onClick(() => {
          this.resolveSystemPrompt();
        })
      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Text(this.sysPromptText)
        .fontSize(UIType.micro)
        .width('100%')
        .maxLines(8)
        .opacity(0.85)

      // ---- P7 步骤 3b：模型目录 ----
      Text('在线模型目录')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .width('100%')
      Row({ space: 6 }) {
        TextInput({ placeholder: '模型名，如 gpt-4o', text: this.modelQuery })
          .fontColor(this.uiColors.textPrimary)
          .placeholderColor(this.uiColors.textTertiary)
          .backgroundColor(this.uiColors.bgSurfaceHigh)
          .borderRadius(UIRadius.sm)
          .fontSize(UIType.caption)
          .layoutWeight(1)
          .onChange((value: string) => {
            this.modelQuery = value;
          })
        .attributeModifier(new InputFieldStyle(this.uiColors))
      Button('OpenRouter', { type: ButtonType.Normal })
          .fontSize(UIType.micro)
          .constraintSize({ minHeight: 44 })
          .onClick(() => {
            this.fetchModelProviders('openrouter');
          })
        .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button('NanoGPT', { type: ButtonType.Normal })
          .fontSize(UIType.micro)
          .constraintSize({ minHeight: 44 })
          .onClick(() => {
            this.fetchModelProviders('nanogpt');
          })
      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
      .width('100%')
      Text(this.providersText)
        .fontSize(UIType.micro)
        .width('100%')
        .maxLines(6)
        .opacity(0.85)

  }

  @Builder
  pageTopBar() {
    PageHeader({ title: '创作设置', subtitle: '为你的故事调整回应', onBack: () => ROOT_PATH_STACK.pop() })
  }

  @Builder
  buildSurfaceContent() {
    Column({ space: 16 }) {
      this.creationSettings()
    }
    .width('100%')
    .padding({ bottom: 24 })
  }

  build() {
    if (this.providerOnly) {
      ProviderManager({
        embedded: this.embedded,
        onEmbeddedBackHandler: this.onEmbeddedBackHandler,
        readOnly: this.readOnly,
        initialProviderId: this.initialProviderId,
        providers: PROVIDERS,
        inputs: $inputs,
        urlInputs: $urlInputs,
        modelInputs: $modelInputs,
        statuses: $statuses,
        testTexts: $testTexts,
        summaryText: this.summaryText,
        protocols: $protocols,
        extras: $extras,
        availableModels: $availableModels,
        assistantConfigured: this.assistantConfigured,
        onSaveAssistantKey: async (key: string): Promise<void> => {
          if (this.readOnly) { throw new Error('请先停止当前回复，再更换助手密钥'); }
          await BuiltinAssistant.saveKey(key); this.assistantConfigured = await BuiltinAssistant.configured();
        },
        onAssist: async (draft: ProviderSetupDraft): Promise<ProviderSetupDraft> => await this.assistConfiguration(draft),
        onRequestStart: (sourceId: string): void => { this.requestSourceId = sourceId; },
        onFetchModels: async (index: number): Promise<void> => { await this.fetchModels(index); },
        onSelectModel: async (index: number, model: string): Promise<void> => { await this.selectModel(index, model); },
        onBack: (): void => { this.onClose(); },
        onSave: async (index: number): Promise<void> => { await this.save(index); },
        onTest: async (index: number): Promise<void> => { await this.testConnection(index); },
        onRefresh: async (): Promise<void> => { await this.refreshStatus(); }
      })
    } else {
      PageSurface({ topBar: () => { this.pageTopBar(); }, content: () => { this.buildSurfaceContent(); } })
    }
  }
}
