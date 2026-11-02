export interface ProviderSetupDraft { providerId: string; url: string; model: string; protocol: string; key: string; note: string; }
interface SetupJson { providerId?: string; url?: string; base_url?: string; model?: string; protocol?: string; api_key?: string; }
interface TextBlock { type?: string; text?: string; }
interface CompletionMessage { content?: string; }
interface CompletionChoice { message?: CompletionMessage; }
interface CompletionOutput { content?: TextBlock[]; }
interface GeminiPart { text?: string; }
interface GeminiContent { parts?: GeminiPart[]; }
interface GeminiCandidate { content?: GeminiContent; }
interface SetupResponse { choices?: CompletionChoice[]; content?: TextBlock[]; output_text?: string; output?: CompletionOutput[]; candidates?: GeminiCandidate[]; }

/** Builds a reviewable draft only. No network access or persistence here. */
export class ProviderSetup {
  static empty(): ProviderSetupDraft { return { providerId: 'custom', url: '', model: '', protocol: 'openai_compat', key: '', note: '' }; }
  static copy(draft: ProviderSetupDraft): ProviderSetupDraft { return { providerId: draft.providerId, url: draft.url, model: draft.model, protocol: draft.protocol, key: draft.key, note: draft.note }; }
  static parse(text: string): ProviderSetupDraft {
    const result: ProviderSetupDraft = ProviderSetup.empty();
    const fenced: string = text.trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '');
    if (fenced.startsWith('{')) {
      try {
        const json: SetupJson = JSON.parse(fenced) as SetupJson;
        if (typeof json.url === 'string') { result.url = json.url; }
        else if (typeof json.base_url === 'string') { result.url = json.base_url; }
        if (typeof json.model === 'string') { result.model = json.model; }
        if (typeof json.protocol === 'string') { result.protocol = json.protocol; }
        if (typeof json.api_key === 'string') { result.key = json.api_key; }
      } catch (_) { /* A curl example or free text is also supported. */ }
    }
    if (result.url === '') { result.url = text.match(/https?:\/\/[^\s'"<>\\]+/i)?.[0] ?? ''; }
    if (result.model === '') { result.model = text.match(/["']?model["']?\s*[:=]\s*["']([^"']+)["']/i)?.[1] ?? ''; }
    if (result.key === '') { result.key = text.match(/(?:Bearer\s+|x-api-key\s*:\s*|["']?(?:api_key|apiKey)["']?\s*[:=]\s*["']?)([^\s'",}]+)/i)?.[1] ?? ''; }
    const path: string = result.url.toLowerCase();
    if (path.includes('/responses')) { result.protocol = 'openai_responses'; }
    else if (path.includes('/messages')) { result.protocol = 'claude_messages'; }
    else if (path.includes(':generatecontent') || path.includes(':streamgeneratecontent')) { result.protocol = 'gemini_generate_content'; }
    result.url = result.url.replace(/\/(chat\/completions|responses|messages|models)\/?$/i, '').replace(/\/$/, '');
    result.note = '已在本机识别，请核对地址、协议和模型；密钥不会发送给配置助手。';
    return result;
  }
  static validate(draft: ProviderSetupDraft): void {
    if (!/^https?:\/\/[^\s/?#@]+(?::\d+)?(?:\/[^\s?#@]*)?$/i.test(draft.url)) { throw new Error('请提供不含账号、查询参数或片段的 HTTP(S) 基础地址'); }
    if (!['openai_compat', 'openai_responses', 'claude_messages', 'gemini_generate_content', 'gemini_interactions'].includes(draft.protocol)) { throw new Error('暂不支持此接口协议，请手动选择'); }
    if (draft.model.length > 256 || /[\r\n]/.test(draft.model)) { throw new Error('模型 ID 格式不正确'); }
  }
  static prompt(draft: ProviderSetupDraft): string {
    // Only an explicit field allowlist is sent. Keys, pasted snippets and query parameters never leave this parser.
    ProviderSetup.validate(draft);
    return JSON.stringify({ url: draft.url, model: draft.model, protocol: draft.protocol });
  }
  static responseText(response: ESObject): string {
    const value: SetupResponse = response as SetupResponse;
    if (typeof value.choices?.[0]?.message?.content === 'string') { return value.choices[0].message?.content ?? ''; }
    if (typeof value.output_text === 'string') { return value.output_text; }
    if (value.content !== undefined) { return value.content.map((part: TextBlock): string => part.text ?? '').join(''); }
    if (value.output !== undefined) { return value.output.map((item: CompletionOutput): string => (item.content ?? []).map((part: TextBlock): string => part.text ?? '').join('')).join(''); }
    return value.candidates?.[0]?.content?.parts?.map((part: GeminiPart): string => part.text ?? '').join('') ?? '';
  }
}
