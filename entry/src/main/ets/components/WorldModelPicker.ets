import { AuxiliaryModels, AuxiliaryModel } from '../backend/AuxiliaryModels';
import { Backend } from '../backend/Backend';
import { ProviderPreferences, ProviderSecretState } from '../backend/ProviderCatalog';
import { SettingsChoice, SettingsPicker } from './SettingsPicker';
import { COLORS, ColorTokens } from '../theme/Tokens';

@Component
export struct WorldModelPicker {
  @StorageProp('uiColors') colors: ColorTokens = COLORS;
  @StorageProp('providerPreferences') @Watch('refresh') preferences: string = '[]';
  @Prop selectedId: string = '';
  @Prop available: boolean = true;
  @State options: SettingsChoice[] = [];
  @State error: string = '';
  private alive: boolean = false;
  private revision: number = 0;
  onSelect: (id: string) => void = (_id: string): void => {};

  aboutToAppear(): void { this.alive = true; this.refresh(); }
  aboutToDisappear(): void { this.alive = false; this.revision++; }
  private async refresh(): Promise<void> {
    if (!this.alive) { return; }
    const revision: number = ++this.revision;
    try {
      const state: Record<string, ProviderSecretState[]> = await Backend.readSecretState() as Record<string, ProviderSecretState[]>;
      ProviderPreferences.hydrate(state);
      if (!this.alive || revision !== this.revision) { return; }
      const options: SettingsChoice[] = [
        { id: '', label: '跟随全局辅助模型', detail: '使用辅助模型设置中的当前选择' },
        { id: 'builtin', label: '内置 Qwen · Qwen3.5-4B', detail: '硅基流动', model: 'Qwen/Qwen3.5-4B' }
      ];
      for (const model of AuxiliaryModels.choices(state)) {
        options.push({ id: model.id, label: model.label + ' · ' + model.model, detail: ProviderPreferences.protocolLabel(model.protocol), model: model.model });
      }
      this.options = options; this.error = '';
    } catch (error) {
      if (this.alive && revision === this.revision) { this.error = '读取模型失败：' + (error as Error).message; }
    }
  }
  build() {
    Column({ space: 8 }) {
      SettingsPicker({ title: '状态栏生成模型', marker: 'world-model-picker', selectedId: this.selectedId,
        options: this.options, available: this.available, placeholder: '所选模型暂不可用，请重新选择',
        onSelect: (id: string): void => { this.onSelect(id); } })
      if (this.error !== '') {
        Text(this.error).fontSize(13).fontColor(this.colors.danger).width('100%')
        Button('重新读取模型').onClick((): void => { this.refresh(); })
      }
    }.width('100%')
  }
}
