import { ProviderRequestDto } from './Types';

export const PROVIDER_PREFERENCES_KEY: string = 'providerPreferences';

export interface ProviderEntry {
  id: string;
  label: string;
  source: string;
  secretKey: string;
  group: string;
  defaultModel: string;
  baseUrl: string;
  protocol: string;
  extraLabel: string;
  extraDefault: string;
  keyOptional: boolean;
}

export interface ProviderConfig {
  id: string;
  url: string;
  model: string;
  protocol: string;
  secretId: string;
  extra: string;
  models: string[];
  saved: boolean;
}

export interface ProviderSecretState {
  id: string;
  value: string;
  active: boolean;
}

export interface ProviderModelEntry {
  id?: string;
  name?: string;
}

export interface ProviderModelList {
  bypass?: boolean;
  data?: ProviderModelEntry[];
}

export interface ProtocolOption {
  id: string;
  label: string;
}

export const CUSTOM_PROTOCOLS: ProtocolOption[] = [
  { id: 'openai_compat', label: 'OpenAI Chat Completions' },
  { id: 'openai_responses', label: 'OpenAI Responses' },
  { id: 'claude_messages', label: 'Anthropic Messages' },
  { id: 'gemini_generate_content', label: 'Gemini GenerateContent' },
  { id: 'gemini_interactions', label: 'Gemini Interactions' }
];

function nativeProvider(id: string, label: string, group: string, model: string, url: string,
  protocol: string = 'openai_compat', extraLabel: string = '', extraDefault: string = ''): ProviderEntry {
  return { id: id, label: label, source: id, secretKey: `api_key_${id}`, group: group,
    defaultModel: model, baseUrl: url, protocol: protocol, extraLabel: extraLabel,
    extraDefault: extraDefault, keyOptional: false };
}

function compatibleProvider(id: string, label: string, group: string, url: string,
  model: string = '', keyOptional: boolean = false): ProviderEntry {
  return { id: id, label: label, source: 'custom', secretKey: 'api_key_custom', group: group,
    defaultModel: model, baseUrl: url, protocol: 'openai_compat', extraLabel: '', extraDefault: '',
    keyOptional: keyOptional };
}

export const PROVIDERS: ProviderEntry[] = [
  nativeProvider('deepseek', 'DeepSeek', '官方直连', 'deepseek-chat', 'https://api.deepseek.com'),
  nativeProvider('openai', 'OpenAI', '官方直连', 'gpt-4o', 'https://api.openai.com/v1', 'openai_auto'),
  nativeProvider('claude', 'Anthropic Claude', '官方直连', '', 'https://api.anthropic.com/v1', 'claude_messages'),
  nativeProvider('makersuite', 'Google Gemini', '官方直连', '', 'https://generativelanguage.googleapis.com', 'gemini_generate_content'),
  nativeProvider('moonshot', 'Kimi · Moonshot', '官方直连', 'moonshot-v1-8k', 'https://api.moonshot.cn/v1', 'openai_compat', '区域（cn / global）', 'cn'),
  nativeProvider('zai', 'GLM · Z.ai', '官方直连', 'glm-4', 'https://api.z.ai/api/paas/v4'),
  compatibleProvider('zhipu', '智谱 · 中国站', '官方直连', 'https://open.bigmodel.cn/api/paas/v4'),
  nativeProvider('minimax', 'MiniMax', '官方直连', 'MiniMax-M2', 'https://api.minimaxi.com/v1', 'openai_compat', '区域（cn / global）', 'cn'),
  nativeProvider('xai', 'xAI · Grok', '官方直连', '', 'https://api.x.ai/v1'),
  nativeProvider('cohere', 'Cohere', '官方直连', '', 'https://api.cohere.ai/v2', 'cohere'),
  compatibleProvider('qwen', '通义千问 · 百炼', '官方直连', 'https://dashscope.aliyuncs.com/compatible-mode/v1'),
  compatibleProvider('doubao', '豆包 · 火山方舟', '官方直连', 'https://ark.cn-beijing.volces.com/api/v3'),
  compatibleProvider('qianfan', '文心 · 百度千帆', '官方直连', 'https://qianfan.baidubce.com/v2'),
  compatibleProvider('hunyuan', '腾讯混元', '官方直连', 'https://api.hunyuan.cloud.tencent.com/v1'),
  compatibleProvider('stepfun', '阶跃星辰', '官方直连', 'https://api.stepfun.com/v1'),
  compatibleProvider('mistral', 'Mistral AI', '官方直连', 'https://api.mistral.ai/v1'),
  compatibleProvider('yi', '零一万物', '官方直连', 'https://api.lingyiwanwu.com/v1'),
  compatibleProvider('baichuan', '百川智能', '官方直连', 'https://api.baichuan-ai.com/v1'),
  compatibleProvider('perplexity', 'Perplexity', '官方直连', 'https://api.perplexity.ai'),
  nativeProvider('openrouter', 'OpenRouter', '第三方与云平台', '', 'https://openrouter.ai/api/v1'),
  nativeProvider('siliconflow', '硅基流动 · SiliconFlow', '第三方与云平台', 'Qwen/Qwen2.5-7B-Instruct', 'https://api.siliconflow.cn/v1', 'openai_compat', '区域（cn / global）', 'cn'),
  nativeProvider('groq', 'Groq', '第三方与云平台', '', 'https://api.groq.com/openai/v1'),
  nativeProvider('opencode', 'OpenCode', '第三方与云平台', '', 'https://opencode.ai/inference/v1', 'openai_compat', '服务（zen / go）', 'zen'),
  nativeProvider('nanogpt', 'NanoGPT', '第三方与云平台', '', 'https://nano-gpt.com/api/v1'),
  nativeProvider('chutes', 'Chutes', '第三方与云平台', '', 'https://llm.chutes.ai/v1'),
  nativeProvider('pollinations', 'Pollinations', '第三方与云平台', '', 'https://gen.pollinations.ai/v1'),
  nativeProvider('workers_ai', 'Cloudflare Workers AI', '第三方与云平台', '', 'https://api.cloudflare.com', 'workers_ai', 'Cloudflare Account ID'),
  nativeProvider('aws_bedrock', 'Amazon Bedrock', '第三方与云平台', '', 'https://bedrock-runtime.us-east-1.amazonaws.com', 'bedrock', 'AWS 区域', 'us-east-1'),
  nativeProvider('vertexai', 'Google Vertex AI · Express', '第三方与云平台', '', 'https://aiplatform.googleapis.com', 'vertexai', 'Google Cloud 区域', 'us-central1'),
  compatibleProvider('together', 'Together AI', '第三方与云平台', 'https://api.together.xyz/v1'),
  compatibleProvider('fireworks', 'Fireworks AI', '第三方与云平台', 'https://api.fireworks.ai/inference/v1'),
  compatibleProvider('custom', '自定义服务商 / 中转站', '第三方与云平台', ''),
  compatibleProvider('ollama', 'Ollama · 本地服务', '第三方与云平台', '', '', true),
  compatibleProvider('lmstudio', 'LM Studio · 本地服务', '第三方与云平台', '', '', true)
];

export class ProviderPreferences {
  static all(): ProviderConfig[] {
    try {
      const configs: ProviderConfig[] = JSON.parse(AppStorage.get<string>(PROVIDER_PREFERENCES_KEY) ?? '[]') as ProviderConfig[];
      return Array.isArray(configs) ? configs : [];
    } catch (_) { return []; }
  }

  static get(provider: ProviderEntry): ProviderConfig {
    const saved: ProviderConfig | undefined = ProviderPreferences.all().find((item: ProviderConfig) => item.id === provider.id);
    return saved ?? { id: provider.id, url: provider.baseUrl, model: provider.defaultModel,
      protocol: provider.protocol, secretId: '', extra: provider.extraDefault, models: [], saved: false };
  }

  static put(config: ProviderConfig): void {
    const current: ProviderConfig[] = ProviderPreferences.all();
    const previous: ProviderConfig | undefined = current.find((item: ProviderConfig) => item.id === config.id);
    if (previous !== undefined && JSON.stringify(previous) === JSON.stringify(config)) { return; }
    const configs: ProviderConfig[] = current.filter((item: ProviderConfig) => item.id !== config.id);
    configs.push(config);
    AppStorage.setOrCreate(PROVIDER_PREFERENCES_KEY, JSON.stringify(configs));
  }

  static activate(id: string): void {
    // EntryAbility binds this key to PersistentStorage before either settings UI mounts.
    AppStorage.setOrCreate('activeProviderId', id);
  }

  static active(): ProviderEntry {
    const id: string = AppStorage.get<string>('activeProviderId') ?? 'deepseek';
    return PROVIDERS.find((provider: ProviderEntry) => provider.id === id) ?? PROVIDERS[0];
  }

  static protocols(provider: ProviderEntry): ProtocolOption[] {
    if (provider.source === 'custom') { return CUSTOM_PROTOCOLS; }
    if (provider.source === 'opencode') {
      return CUSTOM_PROTOCOLS.filter((option: ProtocolOption) => option.id !== 'gemini_interactions');
    }
    return [{ id: provider.protocol, label: ProviderPreferences.protocolLabel(provider.protocol) }];
  }

  static endpointLabel(provider: ProviderEntry, extra: string): string {
    if (provider.source === 'moonshot') {
      return extra === 'cn' ? 'https://api.moonshot.cn/v1' : 'https://api.moonshot.ai/v1';
    }
    if (provider.source === 'siliconflow') {
      return extra === 'cn' ? 'https://api.siliconflow.cn/v1' : 'https://api.siliconflow.com/v1';
    }
    if (provider.source === 'minimax') {
      return extra === 'cn' ? 'https://api.minimaxi.com/v1' : 'https://api.minimax.io/v1';
    }
    if (provider.source === 'opencode' && extra === 'go') { return 'https://opencode.ai/inference/go/v1'; }
    if (provider.source === 'aws_bedrock') { return `https://bedrock-runtime.${extra}.amazonaws.com`; }
    return provider.baseUrl;
  }

  static protocolLabel(protocol: string): string {
    const option: ProtocolOption | undefined = CUSTOM_PROTOCOLS.find((item: ProtocolOption) => item.id === protocol);
    if (option !== undefined) { return option.label; }
    if (protocol === 'openai_auto') { return 'OpenAI · 自动选择 Chat / Responses'; }
    if (protocol === 'cohere') { return 'Cohere Chat v2'; }
    if (protocol === 'bedrock') { return 'AWS Bedrock · API Key'; }
    if (protocol === 'vertexai') { return 'Vertex AI · Express'; }
    if (protocol === 'workers_ai') { return 'Workers AI · Chat Completions'; }
    return protocol;
  }

  static hydrate(state: Record<string, ProviderSecretState[]>): void {
    for (const provider of PROVIDERS) {
      const config: ProviderConfig = ProviderPreferences.get(provider);
      if (config.secretId !== '' || (provider.source === 'custom' && provider.id !== 'custom')) { continue; }
      if (provider.id === 'custom' && !config.saved && !(state['custom_url'] ?? []).length) { continue; }
      const entries: ProviderSecretState[] = state[provider.secretKey] ?? [];
      const active: ProviderSecretState | undefined = entries.find((entry: ProviderSecretState) => entry.active);
      if (active !== undefined) {
        config.secretId = active.id;
        config.saved = true;
        ProviderPreferences.put(config);
      }
    }
    const custom: ProviderEntry | undefined = PROVIDERS.find((provider: ProviderEntry) => provider.id === 'custom');
    if (custom === undefined) { return; }
    const config: ProviderConfig = ProviderPreferences.get(custom);
    const url: ProviderSecretState | undefined = (state['custom_url'] ?? []).find((entry: ProviderSecretState) => entry.active);
    const model: ProviderSecretState | undefined = (state['custom_model'] ?? []).find((entry: ProviderSecretState) => entry.active);
    if (config.url === '' && url !== undefined && !url.value.includes('*')) { config.url = url.value; }
    if (config.model === '' && model !== undefined && !model.value.includes('*')) { config.model = model.value; }
    ProviderPreferences.put(config);
  }

  static configured(provider: ProviderEntry, state: Record<string, ProviderSecretState[]>): boolean {
    const config: ProviderConfig = ProviderPreferences.get(provider);
    const entries: ProviderSecretState[] = state[provider.secretKey] ?? [];
    const keyPresent: boolean = entries.some((entry: ProviderSecretState) =>
      provider.source === 'custom' ? entry.id === config.secretId : entry.active);
    return (keyPresent || (provider.keyOptional && config.saved)) &&
      (provider.source !== 'custom' || config.url !== '');
  }

  static apply(dto: ProviderRequestDto, provider: ProviderEntry, config: ProviderConfig): void {
    dto.chat_completion_source = provider.source;
    if (provider.source === 'custom') {
      if (config.secretId === '') { throw new Error('请先在服务商管理中保存此服务的配置与密钥'); }
      dto.secret_id = config.secretId;
      dto.custom_url = config.url;
      dto.custom_api_format = config.protocol;
    }
    if (provider.source === 'opencode') {
      dto.opencode_endpoint = config.extra;
      dto.opencode_api_format = config.protocol === 'gemini_generate_content' ? 'gemini' : config.protocol;
    }
    if (provider.source === 'moonshot') { dto.moonshot_endpoint = config.extra; }
    if (provider.source === 'siliconflow') { dto.siliconflow_endpoint = config.extra; }
    if (provider.source === 'minimax') { dto.minimax_endpoint = config.extra; }
    if (provider.source === 'workers_ai') { dto.workers_ai_account_id = config.extra; }
    if (provider.source === 'aws_bedrock') { dto.aws_bedrock_region = config.extra; }
    if (provider.source === 'vertexai') { dto.vertexai_region = config.extra; }
  }

  static modelIds(response: ProviderModelList): string[] {
    if (response === null || typeof response !== 'object') { throw new Error('服务商返回了无效响应'); }
    if (response.bypass === true) { return []; }
    if (!Array.isArray(response.data)) { throw new Error('服务商没有返回有效的模型列表'); }
    const models: ProviderModelEntry[] = response.data as ProviderModelEntry[];
    const ids: string[] = [];
    for (const item of models) {
      if (item === null || typeof item !== 'object') { continue; }
      const raw: string | undefined = item.id ?? item.name;
      if (typeof raw !== 'string') { continue; }
      const id: string = raw.trim();
      if (id !== '' && !ids.includes(id)) { ids.push(id); }
    }
    return ids.sort((left: string, right: string) => left.localeCompare(right));
  }
}
