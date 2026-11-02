import { AgentExtensionAbility, common, Want } from '@kit.AbilityKit';
import { createA2AServer, Server, RequestContext, TaskState, Role, Message } from '@kit.AgentFrameworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';
import { ProviderSetup, ProviderSetupDraft } from '../backend/ProviderSetup';

const TAG: string = 'TavernAgent';
const GUIDE: string = '请提供HTTP(S)接口地址、JSON或curl示例，我可以识别基础地址、模型ID与协议。请勿提供密钥。结果仅为待核对草稿；请在HarmonyTavern的设置→服务商管理→让AI帮我配置中核对、保存并测试。';

/** Local A2A extension. Recognition never opens endpoints or reads application secrets. */
export default class HarmonyTavernAgentExtensionAbility extends AgentExtensionAbility {
  private server: Server | undefined = undefined;

  onCreate(want: Want): void {
    try {
      this.server = createA2AServer(this.context.agentCard,
        (method: string, context: RequestContext): void => { this.handleRequest(method, context); }, want);
      this.server.start();
    } catch (_) { hilog.error(0x0003, TAG, 'A2A server initialization failed'); }
  }

  onAuth(proxy: common.AgentHostProxy, handshakeData: string): void {
    try {
      if (this.server !== undefined) { proxy.authorize(this.server.onAuth(handshakeData)); }
    } catch (_) { hilog.error(0x0003, TAG, 'A2A authentication failed'); }
  }

  onData(proxy: common.AgentHostProxy, data: string): void {
    try { this.server?.onMessage(data, (response: string): void => { proxy.sendData(response); }); }
    catch (_) { hilog.error(0x0003, TAG, 'A2A message processing failed'); }
  }

  private reply(context: RequestContext, state: TaskState, text: string): void {
    const taskId: string | undefined = context.getTaskId();
    if (taskId === undefined || this.server === undefined) { return; }
    const message: Message = { messageId: util.generateRandomUUID(true), role: Role.AGENT,
      contextId: context.getContextId(), taskId: taskId, parts: [{ text: text, mediaType: 'text/plain' }] };
    this.server.updateStatus(taskId, { state: state, message: message });
  }

  private handleRequest(method: string, context: RequestContext): void {
    try {
      if (method === 'Cancel') { this.reply(context, TaskState.CANCELED, '已取消，未保存或测试任何连接。'); return; }
      if (method === 'PerceptionSuggest') { this.reply(context, TaskState.COMPLETED, GUIDE); return; }
      if (method !== 'Execute') { this.reply(context, TaskState.REJECTED, '当前仅支持识别连接配置。'); return; }
      const input: string = context.getUserInput().trim();
      if (input.length === 0 || input.length > 16000) { this.reply(context, TaskState.INPUT_REQUIRED, GUIDE); return; }
      const draft: ProviderSetupDraft = ProviderSetup.parse(input);
      try { ProviderSetup.validate(draft); }
      catch (_) { this.reply(context, TaskState.INPUT_REQUIRED, GUIDE); return; }
      const taskId: string | undefined = context.getTaskId();
      if (taskId === undefined || this.server === undefined) { return; }
      // Explicit allowlist: no API keys, raw prompts or private saved settings in artifacts.
      this.server.addArtifact(taskId, { name: 'connection-draft', artifactId: util.generateRandomUUID(true), lastChunk: true,
        parts: [{ text: JSON.stringify({ url: draft.url, model: draft.model, protocol: draft.protocol }), mediaType: 'application/json' }] });
      this.reply(context, TaskState.COMPLETED, '已识别连接草稿，尚未保存或测试。请在HarmonyTavern服务商管理中核对地址、模型和协议；密钥由你在应用内单独填写。');
    } catch (_) {
      try { this.reply(context, TaskState.FAILED, '本次识别未完成，请重新提供不含密钥的接口示例。'); }
      catch (_) { hilog.error(0x0003, TAG, 'A2A status update failed'); }
    }
  }

  onDestroy(): void {
    try { this.server?.stop(); }
    catch (_) { hilog.error(0x0003, TAG, 'A2A server shutdown failed'); }
    this.server = undefined;
  }
}
