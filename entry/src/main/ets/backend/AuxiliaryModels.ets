import { Backend } from './Backend';
import { BuiltinAssistant, BUILTIN_ASSISTANT_MODEL, BUILTIN_ASSISTANT_URL } from './BuiltinAssistant';
import { GenerateRequestDto } from './Types';
import { PROVIDERS, ProviderEntry, ProviderConfig, ProviderPreferences, ProviderSecretState } from './ProviderCatalog';

export interface AuxiliaryModel {
  id: string;
  label: string;
  url: string;
  model: string;
  protocol: string;
  secretId: string;
  providerId?: string;
}

export class AuxiliaryModels {
  static all(): AuxiliaryModel[] {
    try {
      const models: AuxiliaryModel[] = JSON.parse(AppStorage.get<string>('auxiliaryModels') ?? '[]') as AuxiliaryModel[];
      return Array.isArray(models) ? models : [];
    } catch (_) { return []; }
  }
  static selectedId(): string { return AppStorage.get<string>('auxiliaryModelId') ?? 'builtin'; }
  static providerId(provider: string, model: string): string { return 'provider:' + provider + ':' + encodeURIComponent(model); }
  static choices(state: Record<string, ProviderSecretState[]>): AuxiliaryModel[] {
    const choices: AuxiliaryModel[] = [];
    for (const provider of PROVIDERS) {
      const config: ProviderConfig = ProviderPreferences.get(provider);
      if (!config.saved || config.secretId === '' ||
        !(state[provider.secretKey] ?? []).some((entry: ProviderSecretState): boolean => entry.id === config.secretId)) { continue; }
      const models: string[] = [];
      for (const model of [config.model, ...config.models]) {
        if (model.trim() !== '' && !models.includes(model)) { models.push(model); }
      }
      for (const model of models) {
        choices.push({ id: AuxiliaryModels.providerId(provider.id, model), providerId: provider.id,
          label: provider.label, url: config.url, model: model, protocol: config.protocol, secretId: config.secretId });
      }
    }
    return choices;
  }
  static selected(id: string = AuxiliaryModels.selectedId()): AuxiliaryModel {
    if (id === 'builtin') {
      return { id: 'builtin', label: '内置 Qwen 助手', url: BUILTIN_ASSISTANT_URL,
        model: BUILTIN_ASSISTANT_MODEL, protocol: 'openai_compat', secretId: '' };
    }
    if (id.startsWith('provider:')) {
      const parts: string[] = id.split(':');
      const provider: ProviderEntry | undefined = PROVIDERS.find((item: ProviderEntry): boolean => item.id === parts[1]);
      if (provider === undefined || parts.length !== 3) { throw new Error('所选服务商不存在，请重新选择辅助模型'); }
      const config: ProviderConfig = ProviderPreferences.get(provider);
      const model: string = decodeURIComponent(parts[2]);
      if (!config.saved || model === '') { throw new Error('请先在服务商管理保存所选模型的连接配置'); }
      if (config.model !== model && !config.models.includes(model)) { throw new Error('所选模型已从服务商管理移除，请重新选择辅助模型'); }
      return { id: id, providerId: provider.id, label: provider.label, url: config.url,
        model: model, protocol: config.protocol, secretId: config.secretId };
    }
    const model: AuxiliaryModel | undefined = AuxiliaryModels.all().find((item: AuxiliaryModel): boolean => item.id === id);
    if (model === undefined) { throw new Error('所选辅助模型不存在，请在辅助模型设置中重新选择'); }
    return model;
  }
  static select(id: string): void {
    if (id.startsWith('provider:')) {
      const match: ProviderEntry | undefined = PROVIDERS.find((provider: ProviderEntry): boolean =>
        [ProviderPreferences.get(provider).model, ...ProviderPreferences.get(provider).models]
          .some((model: string): boolean => model !== '' && AuxiliaryModels.providerId(provider.id, model) === id &&
            ProviderPreferences.get(provider).saved));
      if (match === undefined) { throw new Error('请从已保存的服务商模型中选择'); }
    } else if (id !== 'builtin' && !AuxiliaryModels.all().some((item: AuxiliaryModel): boolean => item.id === id)) {
      throw new Error('辅助模型不存在');
    }
    AppStorage.setOrCreate('auxiliaryModelId', id);
  }
  static async route(input: GenerateRequestDto, jsonOutput: boolean = false, modelId: string = ''): Promise<GenerateRequestDto> {
    const selected: AuxiliaryModel = AuxiliaryModels.selected(modelId || AuxiliaryModels.selectedId());
    const secret: string = selected.id === 'builtin' ? await BuiltinAssistant.secretId() : selected.secretId;
    if (secret === '') { throw new Error('辅助模型连接不可用，请在设置 → 模型与连接 → 辅助模型设置中选择已配置的服务商模型'); }
    const dto: GenerateRequestDto = { chat_completion_source: 'custom', custom_api_format: selected.protocol, custom_url: selected.url,
      secret_id: secret, model: selected.model, stream: false, temperature: input.temperature,
      top_p: input.top_p, max_tokens: input.max_tokens, messages: input.messages,
      custom_include_body: selected.id === 'builtin' ?
        'enable_thinking: false' + (jsonOutput ? '\nresponse_format: { type: json_object }' : '') : undefined };
    if (selected.providerId !== undefined) {
      const provider: ProviderEntry | undefined = PROVIDERS.find((item: ProviderEntry): boolean => item.id === selected.providerId);
      if (provider === undefined) { throw new Error('所选辅助服务商不存在'); }
      const config: ProviderConfig = ProviderPreferences.get(provider);
      const state: Record<string, ProviderSecretState[]> = await Backend.readSecretState() as Record<string, ProviderSecretState[]>;
      if (!(state[provider.secretKey] ?? []).some((entry: ProviderSecretState): boolean => entry.id === secret)) {
        throw new Error('所选服务商密钥已移除，请在服务商管理重新保存');
      }
      dto.custom_url = undefined; dto.custom_api_format = undefined;
      ProviderPreferences.apply(dto, provider, config);
    }
    return dto;
  }
}
