import { AuxiliaryModel, AuxiliaryModels } from '../backend/AuxiliaryModels';
import { Backend } from '../backend/Backend';
import { BuiltinAssistant } from '../backend/BuiltinAssistant';
import { ProviderPreferences, ProviderSecretState } from '../backend/ProviderCatalog';
import { COLORS, ColorTokens } from '../theme/Tokens';
import { ActionButtonStyle } from '../theme/ControlStyles';
import { SettingsChoice, SettingsPicker } from './SettingsPicker';
import { ROOT_PATH_STACK } from '../nav/RootNav';
import { GenerateRequestDto } from '../backend/Types';
import { ProviderSetup } from '../backend/ProviderSetup';

@Component
export struct AuxiliaryModelSettings {
  @StorageProp('uiColors') colors: ColorTokens = COLORS;
  @StorageProp('auxiliaryModelId') selectedId: string = 'builtin';
  @StorageProp('providerPreferences') @Watch('refresh') providerPreferences: string = '[]';
  @State models: AuxiliaryModel[] = [];
  @State builtinReady: boolean = false;
  @State loading: boolean = true;
  @State error: string = '';
  @State testing: boolean = false;
  @State testResult: string = '';
  @State testFailed: boolean = false;
  private testRequest: string = '';
  @Prop readOnly: boolean = false;
  onChanged: () => void = (): void => {};
  private alive: boolean = false;
  private revision: number = 0;

  aboutToAppear(): void { this.alive = true; this.refresh(); }
  aboutToDisappear(): void {
    this.alive = false; this.revision++;
    if (this.testRequest !== '') { Backend.cancelChatCompletionGeneration(this.testRequest).catch((): void => {}); }
  }
  /** Sends one tiny real request through the selected auxiliary route and reports the real outcome. */
  private async testConnection(): Promise<void> {
    if (this.testing) { return; }
    this.testing = true; this.testFailed = false; this.testResult = '';
    const request: string = 'aux_test_' + Date.now();
    this.testRequest = request;
    const started: number = Date.now();
    try {
      const dto: GenerateRequestDto = await AuxiliaryModels.route({ messages: [{ role: 'user', content: '只回复一个字：好' }],
        max_tokens: 16, temperature: 0 });
      let response: ESObject;
      try { response = await Backend.generateChatCompletion(request, dto); }
      catch (error) {
        const marker: string = 'endpoint_authorization_required|';
        const message: string = (error as Error).message;
        const position: number = message.indexOf(marker);
        if (position < 0) { throw new Error(message); }
        const endpoint: string = message.substring(position + marker.length).trim();
        const trusted: boolean = await new Promise<boolean>((resolve) => {
          this.getUIContext().showAlertDialog({ title: '信任端点', message: '测试连接会向 ' + endpoint + ' 发送一条很短的测试消息。',
            primaryButton: { value: '取消', action: (): void => { resolve(false); } },
            secondaryButton: { value: '信任并连接', action: (): void => { resolve(true); } }, cancel: (): void => { resolve(false); } });
        });
        if (!trusted) { throw new Error('已取消，未发送测试消息。'); }
        await Backend.grantUserEndpointAccess(endpoint);
        response = await Backend.generateChatCompletion(request, dto);
      }
      const reply: string = ProviderSetup.responseText(response).trim();
      if (!this.alive) { return; }
      this.testResult = '连接成功 · ' + dto.model + ' · ' + ((Date.now() - started) / 1000).toFixed(1) + ' 秒' +
        (reply === '' ? '（模型返回为空）' : '');
    } catch (error) {
      if (this.alive) { this.testFailed = true; this.testResult = '连接失败：' + (error as Error).message; }
    } finally {
      this.testRequest = '';
      if (this.alive) { this.testing = false; }
    }
  }  private async refresh(): Promise<void> {
    if (!this.alive) { return; }
    const revision: number = ++this.revision;
    this.loading = true; this.error = '';
    try {
      const state: Record<string, ProviderSecretState[]> = await Backend.readSecretState() as Record<string, ProviderSecretState[]>;
      ProviderPreferences.hydrate(state);
      const ready: boolean = await BuiltinAssistant.configured();
      if (!this.alive || revision !== this.revision) { return; }
      this.models = AuxiliaryModels.choices(state); this.builtinReady = ready;
    } catch (error) { if (this.alive && revision === this.revision) { this.error = '读取模型失败：' + (error as Error).message; } }
    finally { if (this.alive && revision === this.revision) { this.loading = false; } }
  }
  private options(): SettingsChoice[] {
    const options: SettingsChoice[] = [{ id: 'builtin', label: '内置 Qwen · Qwen3.5-4B', detail: '硅基流动 · 联网辅助模型', model: 'Qwen/Qwen3.5-4B' }];
    for (const model of this.models) {
      options.push({ id: model.id, label: model.label + ' · ' + model.model, detail: ProviderPreferences.protocolLabel(model.protocol), model: model.model });
    }
    return options;
  }
  private select(id: string): void {
    try { AuxiliaryModels.select(id); this.error = ''; this.onChanged(); }
    catch (error) { this.error = (error as Error).message; }
  }
  @Builder
  providerAction() {
    Button('前往服务商管理添加模型').attributeModifier(new ActionButtonStyle(this.colors)).width('100%')
      .id('auxiliary-open-providers').onClick((): void => { ROOT_PATH_STACK.pushPathByName('pages/ProviderPage', null); })
  }
  build() {
    Column({ space: 14 }) {
      Text('为连接配置、普通对话草稿与创造模式状态栏选择辅助模型。可使用内置助手，或从服务商管理中已配置的模型选择。')
        .fontSize(13).fontColor(this.colors.textSecondary).lineHeight(21).width('100%')
      SettingsPicker({ title: '辅助模型', marker: 'auxiliary-model-picker', selectedId: this.selectedId,
        options: this.options(), placeholder: '原辅助配置暂不可选，请重新选择',
        available: !this.readOnly && !this.loading,
        onSelect: (id: string): void => { this.select(id); } })
      if (this.models.length === 0 && !this.loading) {
        Text('服务商管理中还没有可选的已配置模型。添加并保存服务商连接后，可在这里展开选择。')
          .fontSize(13).fontColor(this.colors.textSecondary).lineHeight(21).width('100%')
      }
      this.providerAction()
      if (this.selectedId === 'builtin') {
        Text(this.builtinReady ? '硅基流动 · 内置助手已就绪' : '硅基流动 · 内置助手暂不可用，请选择已配置的服务商模型')
          .fontSize(12).fontColor(this.colors.textSecondary).width('100%')
      }
      Button(this.testing ? '正在测试连接…' : '测试当前辅助模型连接').attributeModifier(new ActionButtonStyle(this.colors)).width('100%')
        .enabled(!this.testing && !this.loading).id('auxiliary-test-connection')
        .onClick((): void => { this.testConnection(); })
      if (this.testResult !== '') {
        Text(this.testResult).fontSize(13).lineHeight(21).width('100%').id('auxiliary-test-result')
          .fontColor(this.testFailed ? this.colors.danger : this.colors.success)
      }
      if (this.loading) { Text('正在读取已配置模型…').fontColor(this.colors.textSecondary) }
      if (this.error !== '') { Text(this.error).fontColor(this.colors.danger).width('100%') }
      Text('选择后立即用于辅助任务，会产生所选服务的用量。聊天主模型仍在服务商管理中设置。')
        .fontSize(12).fontColor(this.colors.textSecondary).lineHeight(20).width('100%')
    }.width('100%').enabled(!this.readOnly)
  }
}
