import { ActionButtonStyle, ActionTone, InputFieldStyle } from '../theme/ControlStyles';
import { HeaderAction } from '../components/HeaderAction';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { PageSurface } from '../components/PageSurface';
import { Radius as UIRadius, Typography as UIType } from '../theme/Tokens';
import { PageHeader } from '../components/PageHeader';
// 密钥管理（P8-13）：对应原项目 SillyTavern 的 API 密钥面板 + Rust secret_service。
//
// 能力：按 key 列出多组密钥（id / label / 掩码值 / 是否生效）→ 新增 / 改名 / 删除 / 切换生效（rotate）
//      / 明文查看（需要"允许明文导出"开关，来自 read_secret_settings）。
//
// 数据形状（Rust）：
//   read_secret_state  → { "<key>": [{ id, value, label, active }] | null }
//   view_secrets       → { "<key>": "<掩码>" }
//   read_secret_settings → { allowKeysExposure }
//
// 对应 DevEco 工程路径：entry/src/main/ets/pages/SecretsPage.ets
import { Backend, BackendError } from '../backend/Backend';
import { ROOT_PATH_STACK } from '../nav/RootNav';
import { Radius, Spacing, Typography } from '../theme/Tokens';
import { GLASS_CARD, GLASS_HEADER, glassEffect } from '../theme/Glass';
import { EmptyHint, ErrorBannerView, SectionTitle } from '../components/Builders';

/** read_secret_state 的一项。 */
interface SecretItem {
  id: string;
  value: string;
  label: string;
  active: boolean;
}

/** 一个 key 下的所有项（渲染用，避免 ESObject 动态索引）。 */
interface SecretGroup {
  key: string;
  items: SecretItem[];
}

@Component
export struct SecretsPage {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @State loading: boolean = true;
  @State busy: boolean = false;
  @State errorText: string = '';
  @State statusText: string = '';
  @State groups: SecretGroup[] = [];
  @State allowExposure: boolean = false;

  @State newKey: string = '';
  @State newValue: string = '';
  @State newLabel: string = '';
  @State revealKey: string = '';
  @State revealText: string = '';

  aboutToAppear(): void {
    if (!Backend.isReady()) {
      this.errorText = '后端未就绪，请从首页进入';
      this.loading = false;
      return;
    }
    this.reload();
  }

  async reload(): Promise<void> {
    this.loading = true;
    this.errorText = '';
    try {
      const settings: ESObject = await Backend.readSecretSettings();
      const flag: ESObject = settings['allowKeysExposure'];
      this.allowExposure = flag === undefined || flag === null ? false : Boolean(flag);
    } catch (err) {
      this.allowExposure = false;
    }
    try {
      const state: ESObject = await Backend.readSecretState();
      const keys: string[] = this.keysOf(state);
      const next: SecretGroup[] = [];
      for (let i = 0; i < keys.length; i++) {
        const key: string = keys[i];
        const raw: ESObject = state[key];
        const items: SecretItem[] = [];
        if (raw !== undefined && raw !== null) {
          const list: ESObject[] = raw as ESObject[];
          if (list !== undefined && list !== null && list.length !== undefined) {
            for (let j = 0; j < list.length; j++) {
              const one: ESObject = list[j];
              items.push({
                id: String(one['id']),
                value: String(one['value']),
                label: String(one['label']),
                active: Boolean(one['active'])
              });
            }
          }
        }
        next.push({ key: key, items: items });
      }
      this.groups = next;
    } catch (err) {
      this.errorText = `读取密钥状态失败：${(err as BackendError).message}`;
      this.groups = [];
    } finally {
      this.loading = false;
    }
  }

  /** 从扁平对象里取 key 列表（优先 Object.keys，失败再用已知 key 表兜底）。 */
  keysOf(state: ESObject): string[] {
    const found: string[] = [];
    try {
      const names: string[] = Object.keys(state);
      for (let i = 0; i < names.length; i++) {
        if (state[names[i]] !== undefined) {
          found.push(names[i]);
        }
      }
      if (found.length > 0) {
        return found;
      }
    } catch (err) {
      // 忽略，走兜底
    }
    const known: string[] = [
      'api_key_openai', 'api_key_claude', 'api_key_gemini', 'api_key_makersuite',
      'api_key_vertexai', 'api_key_mistralai', 'api_key_cohere', 'api_key_perplexity',
      'api_key_groq', 'api_key_rwkv', 'api_key_deepseek', 'api_key_xai',
      'api_key_openrouter', 'api_key_nanogpt', 'api_key_siliconflow', 'api_key_workers_ai',
      'api_key_pollinations', 'api_key_ai21', 'api_key_fireworks', 'api_key_cometapi',
      'api_key_custom', 'api_key_azure_openai', 'api_key_azure_ai_studio',
      'api_key_aws_bedrock', 'api_key_google_ai_studio', 'api_key_vertexai_express',
      'api_key_zai', 'api_key_moonshot', 'api_key_baidu', 'api_key_qwen',
      'api_key_01ai', 'api_key_minimax', 'api_key_doubao'
    ];
    for (let i = 0; i < known.length; i++) {
      if (state[known[i]] !== undefined) {
        found.push(known[i]);
      }
    }
    return found;
  }

  async addSecret(): Promise<void> {
    const key: string = this.newKey.trim();
    const value: string = this.newValue.trim();
    if (key === '' || value === '') {
      this.errorText = 'key 和密钥值都要填';
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      await Backend.writeSecret(key, value);
      this.statusText = `已保存 ${key}`;
      this.newKey = '';
      this.newValue = '';
      this.newLabel = '';
      await this.reload();
    } catch (err) {
      this.errorText = `保存失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async remove(key: string, item: SecretItem): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      await Backend.deleteSecret(key, item.id);
      this.statusText = `已删除 ${key} / ${item.label}`;
      await this.reload();
    } catch (err) {
      this.errorText = `删除失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async activate(key: string, item: SecretItem): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      await Backend.rotateSecret(key, item.id);
      this.statusText = `已切换到 ${key} / ${item.label}`;
      await this.reload();
    } catch (err) {
      this.errorText = `切换失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async rename(key: string, item: SecretItem): Promise<void> {
    if (this.newLabel.trim() === '') {
      this.errorText = '改名要先在上面「备注」里填新名字';
      return;
    }
    this.busy = true;
    try {
      await Backend.renameSecret(key, item.id, this.newLabel.trim());
      this.statusText = `已重命名 ${item.label} → ${this.newLabel.trim()}`;
      this.newLabel = '';
      await this.reload();
    } catch (err) {
      this.errorText = `改名失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async reveal(key: string, item: SecretItem): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      const result: ESObject = await Backend.findSecret(key, item.id);
      const value: ESObject = result['value'];
      this.revealKey = `${key} / ${item.label}`;
      this.revealText = value === undefined || value === null ? '（空）' : String(value);
    } catch (err) {
      this.errorText = `读取明文失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  @Builder
  pageTopBar() {
    PageHeader({
        title: '密钥',
        subtitle: '管理服务凭据',
        onBack: () => {
            ROOT_PATH_STACK.pop();
        }
      }) {
        HeaderAction({ label: '刷新', marker: 'secretspage-refresh-1', available: !this.busy,
          pending: this.loading,
          onAction: async (): Promise<void> => { await this.reload(); } })
      }
  }

  @Builder
  buildSurfaceContent() {
      Column({ space: Spacing.sm }) {
        
  
        if (this.statusText !== '') {
          Text(this.statusText)
            .fontSize(Typography.micro)
            .fontColor(this.uiColors.textTertiary)
            .width('100%')
            .padding({ left: Spacing.md })
        }
        ErrorBannerView({ text: this.errorText })
  
        Column() {
          Column({ space: Spacing.md }) {
            this.addCard()
            if (this.revealKey !== '') {
              Column({ space: 4 }) {
                Text(`明文：${this.revealKey}`)
                  .fontSize(Typography.micro)
                  .fontColor(this.uiColors.textTertiary)
                  .width('100%')
                Text(this.revealText)
                  .fontSize(Typography.micro)
                  .fontColor(this.uiColors.textPrimary)
                  .width('100%')
                  .copyOption(CopyOptions.LocalDevice)
                Text(this.allowExposure ? '' : '提示：当前"允许明文导出"是关闭的，明文可能仍拿不到。')
                  .fontSize(Typography.micro)
                  .fontColor(this.uiColors.textTertiary)
                  .width('100%')
              }
              .width('100%')
              .padding(Spacing.md)
              .borderRadius(GLASS_CARD.radius)
              .backgroundColor(this.uiColors.bgSurface)
              .border({ width: 1, color: this.uiColors.borderSubtle })
            }
  
            if (this.loading) {
              Text('读取中…').fontSize(Typography.caption).fontColor(this.uiColors.textTertiary)
            } else if (this.groups.length === 0) {
              EmptyHint('还没有任何密钥', '在下面填入 key 与值即可', this.uiColors)
            } else {
              ForEach(this.groups, (group: SecretGroup) => {
                Column({ space: 6 }) {
                  Row({ space: 6 }) {
                    Text(group.key)
                      .fontSize(Typography.caption)
                      .fontColor(this.uiColors.textPrimary)
                      .layoutWeight(1)
                    Text(`${group.items.length} 组`)
                      .fontSize(Typography.micro)
                      .fontColor(this.uiColors.textTertiary)
                  }
                  .width('100%')
  
                  if (group.items.length === 0) {
                    Text('该 key 下没有保存密钥')
                      .fontSize(Typography.micro)
                      .fontColor(this.uiColors.textTertiary)
                      .width('100%')
                  } else {
                    ForEach(group.items, (item: SecretItem) => {
                      Column({ space: 4 }) {
                        Row({ space: 6 }) {
                          Text(item.label !== '' ? item.label : '（无备注）')
                            .fontSize(Typography.micro)
                            .fontColor(item.active ? this.uiColors.accent : this.uiColors.textSecondary)
                            .layoutWeight(1)
                            .maxLines(1)
                          if (item.active) {
                            Text('生效中')
                              .fontSize(Typography.micro)
                              .fontColor(this.uiColors.accent)
                          }
                        }
                        .width('100%')
                        Text(`${item.value} · id ${item.id.substring(0, Math.min(8, item.id.length))}`)
                          .fontSize(Typography.micro)
                          .fontColor(this.uiColors.textTertiary)
                          .width('100%')
                          .maxLines(1)
                        Row({ space: 4 }) {
                          Button('查看', { type: ButtonType.Normal })
                            .fontSize(UIType.micro)
                            .constraintSize({ minHeight: 44 })
                            .layoutWeight(1)
                            .enabled(!this.busy)
                            .onClick(() => {
                              this.reveal(group.key, item);
                            })
                          .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button('生效', { type: ButtonType.Normal })
                            .fontSize(UIType.micro)
                            .constraintSize({ minHeight: 44 })
                            .layoutWeight(1)
                            .backgroundColor(this.uiColors.bgSurfaceHigh)
                            .fontColor(this.uiColors.textSecondary)
                            .enabled(!this.busy && !item.active)
                            .onClick(() => {
                              this.activate(group.key, item);
                            })
                          .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button('改名', { type: ButtonType.Normal })
                            .fontSize(UIType.micro)
                            .constraintSize({ minHeight: 44 })
                            .layoutWeight(1)
                            .backgroundColor(this.uiColors.bgSurfaceHigh)
                            .fontColor(this.uiColors.textSecondary)
                            .enabled(!this.busy)
                            .onClick(() => {
                              this.rename(group.key, item);
                            })
                          .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button('删除', { type: ButtonType.Normal })
                            .fontSize(UIType.micro)
                            .constraintSize({ minHeight: 44 })
                            .layoutWeight(1)
                            .backgroundColor(this.uiColors.danger)
                            .enabled(!this.busy)
                            .onClick(() => {
                              this.remove(group.key, item);
                            })
                        .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Danger))
      }
                        .width('100%')
                      }
                      .width('100%')
                      .padding({ top: 4, bottom: 4 })
                    }, (item: SecretItem) => `${group.key}|${item.id}`)
                  }
                }
                .width('100%')
                .padding(Spacing.md)
                .borderRadius(GLASS_CARD.radius)
                .backgroundColor(this.uiColors.bgSurface)
                .border({ width: 1, color: this.uiColors.borderSubtle })
              }, (group: SecretGroup) => group.key)
            }
  
            Text('「改名」用的是上面「备注」框里的文字；先把新名字填进去，再点某条的「改名」。')
              .fontSize(Typography.micro)
              .fontColor(this.uiColors.textTertiary)
              .width('100%')
          }
          .width('100%')
          .padding({ bottom: Spacing.xxl })
        }
        .width('100%')
        .align(Alignment.Top)
      }
      .width('100%')
      .backgroundColor(this.uiColors.bgBase)
    }

  build() {
    PageSurface({ topBar: () => { this.pageTopBar(); }, content: () => { this.buildSurfaceContent(); } })
  }

  @Builder
  addCard() {
    Column({ space: Spacing.sm }) {
      SectionTitle('新增 / 更新密钥', this.uiColors)
      TextInput({ text: this.newKey, placeholder: 'key，例如 api_key_openai' })
        .fontColor(this.uiColors.textPrimary)
        .placeholderColor(this.uiColors.textTertiary)
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(UIRadius.sm)
        .fontSize(Typography.caption)
        .constraintSize({ minHeight: 44 })
        .width('100%')
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(Radius.sm)
        .onChange((value: string) => {
          this.newKey = value;
        })
      .attributeModifier(new InputFieldStyle(this.uiColors))
      TextInput({ text: this.newValue, placeholder: '密钥值' })
        .fontColor(this.uiColors.textPrimary)
        .placeholderColor(this.uiColors.textTertiary)
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(UIRadius.sm)
        .fontSize(Typography.caption)
        .constraintSize({ minHeight: 44 })
        .width('100%')
        .type(InputType.Password)
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(Radius.sm)
        .onChange((value: string) => {
          this.newValue = value;
        })
      .attributeModifier(new InputFieldStyle(this.uiColors))
      TextInput({ text: this.newLabel, placeholder: '备注（改名时也用它）' })
        .fontColor(this.uiColors.textPrimary)
        .placeholderColor(this.uiColors.textTertiary)
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(UIRadius.sm)
        .fontSize(Typography.caption)
        .constraintSize({ minHeight: 44 })
        .width('100%')
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(Radius.sm)
        .onChange((value: string) => {
          this.newLabel = value;
        })
      .attributeModifier(new InputFieldStyle(this.uiColors))
      Button('保存密钥', { type: ButtonType.Normal })
        .fontSize(Typography.caption)
        .constraintSize({ minHeight: 44 })
        .width('100%')
        .enabled(!this.busy)
        .onClick(() => {
          this.addSecret();
        })
    .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      }
    .width('100%')
    .padding(Spacing.md)
    .borderRadius(GLASS_CARD.radius)
    .backgroundColor(this.uiColors.bgSurface)
    .border({ width: 1, color: this.uiColors.borderSubtle })
  }
}
