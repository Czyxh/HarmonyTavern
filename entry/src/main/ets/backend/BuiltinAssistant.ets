import { Backend } from './Backend';
import { GenerateRequestDto } from './Types';
import { ProviderSetup, ProviderSetupDraft } from './ProviderSetup';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { PersonalizationStore } from '../theme/PersonalizationStore';

const SEED_FILE: string = 'builtin/siliconflow.key';
const SEED_VERSION_KEY: string = 'builtinAssistantSeedVersion';
const SEED_VERSION: number = 1;

interface AssistantSecretState { id: string; active: boolean; label: string; }
const SECRET_KEY: string = 'api_key_custom';
const SECRET_LABEL: string = 'HarmonyTavern 内置配置助手 · SiliconFlow';
export const BUILTIN_ASSISTANT_MODEL: string = 'Qwen/Qwen3.5-4B';
export const BUILTIN_ASSISTANT_URL: string = 'https://api.siliconflow.cn/v1';

/** Fixed assistant route. Credentials remain in the existing private backend secret store, never in a HAP resource. */
export class BuiltinAssistant {
  private static async credentials(): Promise<AssistantSecretState[]> {
    const state: Record<string, AssistantSecretState[] | null> = await Backend.readSecretState() as Record<string, AssistantSecretState[] | null>;
    return state[SECRET_KEY] ?? [];
  }
  static async secretId(): Promise<string> {
    const entries: AssistantSecretState[] = await BuiltinAssistant.credentials();
    for (let index: number = entries.length - 1; index >= 0; index--) {
      if (entries[index].label === SECRET_LABEL) { return entries[index].id; }
    }
    return '';
  }
  /** Imports the key shipped in the app's resources into the private backend secret store (first run / seed upgrade). */
  static async seed(context: common.Context): Promise<void> {
    if ((AppStorage.get<number>(SEED_VERSION_KEY) ?? 0) >= SEED_VERSION && await BuiltinAssistant.configured()) { return; }
    const bytes: Uint8Array = await context.resourceManager.getRawFileContent(SEED_FILE);
    const key: string = new util.TextDecoder('utf-8').decodeToString(bytes).trim();
    await BuiltinAssistant.saveKey(key);
    PersonalizationStore.set(SEED_VERSION_KEY, SEED_VERSION);
  }
  static async configured(): Promise<boolean> { return (await BuiltinAssistant.secretId()) !== ''; }
  static async saveKey(key: string): Promise<void> {
    if (!/^sk-[A-Za-z0-9_-]+$/.test(key.trim())) { throw new Error('请输入完整的硅基流动 API Key'); }
    const previous: AssistantSecretState | undefined = (await BuiltinAssistant.credentials()).find((item: AssistantSecretState): boolean => item.active);
    await Backend.writeSecret(SECRET_KEY, key.trim(), SECRET_LABEL);
    // All assistant requests select their own ID. Preserve an existing custom provider's active credential too.
    if (previous !== undefined && previous.label !== SECRET_LABEL) { await Backend.rotateSecret(SECRET_KEY, previous.id); }
  }
  static request(local: ProviderSetupDraft, secretId: string): GenerateRequestDto {
    if (secretId === '') { throw new Error('内置助手暂不可用，请在辅助模型设置中选择已配置的服务商模型'); }
    const dto: GenerateRequestDto = BuiltinAssistant.configurationRequest(local);
    dto.chat_completion_source = 'custom'; dto.custom_api_format = 'openai_compat'; dto.custom_url = BUILTIN_ASSISTANT_URL;
    dto.secret_id = secretId; dto.model = BUILTIN_ASSISTANT_MODEL;
    dto.custom_include_body = 'enable_thinking: false\nresponse_format: { type: json_object }';
    return dto;
  }
  static configurationRequest(local: ProviderSetupDraft): GenerateRequestDto {
    return { stream: false, temperature: 0.1, max_tokens: 1024,
      messages: [{ role: 'system', content: '你是API连接配置助手。只返回合法JSON对象，字段url、model、protocol。依据地址核对协议，protocol只能是openai_compat/openai_responses/claude_messages/gemini_generate_content/gemini_interactions。禁止发明或更改服务地址、模型ID，禁止输出密钥。输入已在本机归一化，保留url与model原值，不确定协议则保留输入值。不要解释，不要Markdown。' },
        { role: 'user', content: ProviderSetup.prompt(local) }] };
  }
  static result(local: ProviderSetupDraft, response: ESObject): ProviderSetupDraft {
    const text: string = ProviderSetup.responseText(response).trim();
    if (!text.startsWith('{') && !text.startsWith(String.fromCharCode(96).repeat(3))) { throw new Error('辅助模型未返回配置JSON，请重试或使用本机识别'); }
    const draft: ProviderSetupDraft = ProviderSetup.parse(text);
    ProviderSetup.validate(draft);
    if (draft.url !== local.url || draft.model !== local.model) { throw new Error('辅助模型改动了服务地址或模型，请使用本机识别并手动核对'); }
    draft.key = local.key;
    draft.note = '辅助模型已整理接口协议，请核对后填入。尚未保存或发起连接测试。';
    return draft;
  }
}
