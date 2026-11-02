import { ActionButtonStyle, ActionTone, InputFieldStyle, TextAreaFieldStyle } from '../theme/ControlStyles';
import { HeaderAction } from '../components/HeaderAction';
import { NativePreferencesPanel } from '../components/NativePreferencesPanel';
import { JellyTabBar, JellyTabItem } from '../components/JellyTabBar';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { PageSurface } from '../components/PageSurface';
import { Radius as UIRadius, Typography as UIType } from '../theme/Tokens';
import { PageHeader } from '../components/PageHeader';
// 应用设置按聊天、备份、连接、日志与高级功能组织。
// 聊天偏好由 NativePreferencesPanel 读写 ST 设置；壳层字段继续使用
// update_tauritavern_settings 部分更新并回读。桌面专用或 ArkUI 未消费的
// 开关不展示；主题与显示统一从个性化入口管理。
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Backend, BackendError } from '../backend/Backend';
import {
  ChatBackupStorageStats,
  TauriTavernSettings,
  UpdateTauriTavernSettings
} from '../backend/SettingsTypes';
import { ROOT_PATH_STACK } from '../nav/RootNav';
import { Radius, Spacing, Typography } from '../theme/Tokens';
import { GLASS_CARD, GLASS_HEADER, glassEffect } from '../theme/Glass';
import { ErrorBannerView, SectionTitle } from '../components/Builders';

const DOMAIN: number = 0x0004;
const TAG: string = 'HarmonyTavern';
const MB: number = 1024 * 1024;

@Component
export struct TauriSettingsPage {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @State loading: boolean = true;
  @State section: number = 0;
  @State preferencesBusy: boolean = false;
  private readonly sections: JellyTabItem[] = [
    { label: '聊天', glyph: '' }, { label: '备份', glyph: '' }, { label: '连接', glyph: '' },
    { label: '日志', glyph: '' }, { label: '高级', glyph: '' }
  ];
  @State busy: boolean = false;
  @State errorText: string = '';
  @State statusText: string = '';
  @State settings: TauriTavernSettings | undefined = undefined;
  /** 备份占用统计的展示文本（后端没备份时返回 null，不保留对象引用，避免空值取值崩溃）。 */
  @State statsText: string = '';

  // 表单镜像（避免每次改都立刻落库；改动后由 apply 写回）
  @State autoBackup: boolean = false;
  @State zstd: boolean = false;
  @State maxPerPrefix: string = '10';
  @State maxTotalFiles: string = '100';
  @State maxTotalMb: string = '512';
  @State llmLogKeep: string = '50';
  @State proxyEnabled: boolean = false;
  @State proxyUrl: string = '';
  @State proxyBypass: string = '';
  @State allowKeysExposure: boolean = false;
  @State promptCacheTtl: string = 'off';
  @State autoPrune: boolean = true;
  @State keepTerminal: string = '50';
  @State keepFull: string = '10';

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
      const value: TauriTavernSettings = await Backend.getTauriTavernSettings();
      this.settings = value;
      this.fillForm(value);
      await this.loadStats();
    } catch (err) {
      this.errorText = `读取设置失败：${(err as BackendError).message}`;
      hilog.error(DOMAIN, TAG, 'load tauri settings failed: %{public}s', this.errorText);
    } finally {
      this.loading = false;
    }
  }

  /** 备份占用统计（可空）。 */
  async loadStats(): Promise<void> {
    this.statsText = '';
    try {
      const stats: ChatBackupStorageStats | null = await Backend.getChatBackupStorageStats();
      if (stats !== null && stats !== undefined) {
        this.statsText = `当前占用：原始 ${this.fmtBytes(stats.original_bytes)} / 实占 ${this.fmtBytes(stats.stored_bytes)}`;
      }
    } catch (err) {
      this.statsText = '';
    }
  }

  fillForm(value: TauriTavernSettings): void {
    this.autoBackup = value.chat_backups.automatic_enabled;
    this.zstd = value.chat_backups.zstd_compression_enabled;
    this.maxPerPrefix = String(value.chat_backups.max_files_per_prefix);
    this.maxTotalFiles = String(value.chat_backups.max_total_files);
    this.maxTotalMb = String(Math.round(value.chat_backups.max_total_bytes / MB));
    this.llmLogKeep = String(value.dev.llm_api_keep);
    this.proxyEnabled = value.request_proxy.enabled;
    this.proxyUrl = value.request_proxy.url;
    this.proxyBypass = value.request_proxy.bypass.join('\n');
    this.allowKeysExposure = value.allow_keys_exposure;
    this.promptCacheTtl = value.models.claude.prompt_cache_ttl;
    this.autoPrune = value.agent.retention.auto_prune_enabled;
    this.keepTerminal = String(value.agent.retention.keep_recent_terminal_runs);
    this.keepFull = String(value.agent.retention.keep_full_recent_runs);
  }

  /** 部分更新 + 回读（写入后必须确认后端真实状态，不能只改本地开关）。 */
  async apply(dto: UpdateTauriTavernSettings, label: string): Promise<void> {
    if (this.busy) { return; }
    this.busy = true;
    this.errorText = '';
    try {
      await Backend.updateTauriTavernSettings(dto);
      const fresh: TauriTavernSettings = await Backend.getTauriTavernSettings();
      this.settings = fresh;
      this.fillForm(fresh);
      this.statusText = `已保存：${label}`;
    } catch (err) {
      this.errorText = `${label} 保存失败：${(err as BackendError).message}`;
      // 失败后回读，把 UI 拉回真实状态。
      try {
        const fresh: TauriTavernSettings = await Backend.getTauriTavernSettings();
        this.settings = fresh;
        this.fillForm(fresh);
      } catch (again) {
        // 回读也失败时保持现状并保留错误提示。
      }
    } finally {
      this.busy = false;
    }
  }

  parseNumber(text: string, fallback: number): number {
    const value: number = Number.parseInt(text, 10);
    return Number.isNaN(value) || value < 0 ? fallback : value;
  }

  // ---- UI ----

  @Builder
  pageTopBar() {
    PageHeader({
        title: '应用设置',
        subtitle: '按你的习惯使用酒馆',
        onBack: () => {
            ROOT_PATH_STACK.pop();
        }
      }) {
        HeaderAction({ label: '刷新', marker: 'taurisettingspage-refresh-1', available: !this.busy && !this.preferencesBusy,
          pending: this.loading || this.preferencesBusy,
          onAction: async (): Promise<void> => { await this.reload(); } })
      }
  }

  @Builder
  buildSurfaceContent() {
      Column({ space: Spacing.sm }) {
        
  
        if (this.statusText !== '') {
          Text(this.statusText)
            .fontSize(Typography.caption)
            .fontColor(this.uiColors.textTertiary)
            .width('100%')
            .padding({ left: Spacing.md })
        }
        ErrorBannerView({ text: this.errorText })
  
        if (this.loading) {
          Text('读取中…')
            .fontSize(Typography.caption)
            .fontColor(this.uiColors.textTertiary)
        } else {
          Column() {
            Column({ space: Spacing.md }) {
              JellyTabBar({ items: this.sections, currentIndex: this.section, textOnly: true,
                onSelect: (index: number): void => { this.section = index; } })
              if (this.section === 0) {
                Button('用户设定管理 · 身份与人设', { type: ButtonType.Normal })
                  .onClick((): void => { ROOT_PATH_STACK.pushPathByName('pages/UserPage', null); })
                .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      NativePreferencesPanel({ identity: false,
                  onActivityChange: (active: boolean): void => { this.preferencesBusy = active; } })
              } else if (this.section === 1) {
                this.backupSection()
                Button('打开备份中心', { type: ButtonType.Normal })
                  .onClick((): void => { ROOT_PATH_STACK.pushPathByName('pages/BackupPage', null); })
              .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      } else if (this.section === 2) {
                Button('服务商与模型连接', { type: ButtonType.Normal })
                  .onClick((): void => { ROOT_PATH_STACK.pushPathByName('pages/ProviderPage', null); })
                .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      this.proxySection()
                this.modelsSection()
              } else if (this.section === 3) {
                this.logSection()
              } else {
                this.agentSection()
                this.miscSection()
              }
            }
            .width('100%')
            .padding({ bottom: Spacing.xxl })
          }
          .width('100%')
          .align(Alignment.Top)
        }
      }
      .width('100%')
      .backgroundColor(this.uiColors.bgBase)
    }

  build() {
    PageSurface({ topBar: () => { this.pageTopBar(); }, content: () => { this.buildSurfaceContent(); } })
  }

  @Builder
  backupSection() {
    Column({ space: Spacing.sm }) {
      SectionTitle('备份（Chat Backups）', this.uiColors)
      this.switchRow('自动备份会话', this.autoBackup, (next: boolean) => {
        this.autoBackup = next;
        this.apply({ chat_backups: { automatic_enabled: next } }, '自动备份');
      })
      this.switchRow('zstd 压缩（省空间，SillyTavern 读不了）', this.zstd, (next: boolean) => {
        this.zstd = next;
        this.apply({ chat_backups: { zstd_compression_enabled: next } }, 'zstd 压缩');
      })
      this.textRow('每个角色/群最多备份数', this.maxPerPrefix, (value: string) => {
        this.maxPerPrefix = value;
        this.apply({ chat_backups: { max_files_per_prefix: this.parseNumber(value, 10) } }, '备份数上限');
      })
      this.textRow('备份文件总数上限', this.maxTotalFiles, (value: string) => {
        this.maxTotalFiles = value;
        this.apply({ chat_backups: { max_total_files: this.parseNumber(value, 100) } }, '备份总数上限');
      })
      this.textRow('备份总容量上限（MB）', this.maxTotalMb, (value: string) => {
        this.maxTotalMb = value;
        this.apply({ chat_backups: { max_total_bytes: this.parseNumber(value, 512) * MB } }, '备份容量上限');
      })
      if (this.statsText !== '') {
        Text(this.statsText)
          .fontSize(Typography.caption)
          .fontColor(this.uiColors.textSecondary)
          .width('100%')
      }
    }
    .width('100%')
    .padding(Spacing.md)
    .borderRadius(GLASS_CARD.radius)
    .backgroundColor(this.uiColors.bgSurface)
    .border({ width: 1, color: this.uiColors.borderSubtle })
  }

  @Builder
  logSection() {
    Column({ space: Spacing.sm }) {
      SectionTitle('日志（Development）', this.uiColors)
      Button('查看应用活动日志', { type: ButtonType.Normal })
        .onClick((): void => { ROOT_PATH_STACK.pushPathByName('pages/LogsPage', null); })
      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      this.textRow('LLM API 日志保留条数', this.llmLogKeep, (value: string) => {
        this.llmLogKeep = value;
        this.apply({ dev: { llm_api_keep: this.parseNumber(value, 50) } }, 'LLM 日志条数');
      })
    }
    .width('100%')
    .padding(Spacing.md)
    .borderRadius(GLASS_CARD.radius)
    .backgroundColor(this.uiColors.bgSurface)
    .border({ width: 1, color: this.uiColors.borderSubtle })
  }

  @Builder
  proxySection() {
    Column({ space: Spacing.sm }) {
      SectionTitle('请求代理（Request Proxy）', this.uiColors)
      this.switchRow('启用代理（作用于所有后端请求）', this.proxyEnabled, (next: boolean) => {
        this.proxyEnabled = next;
        this.apply({
          request_proxy: { enabled: next, url: this.proxyUrl, bypass: this.splitBypass() }
        }, '代理开关');
      })
      this.textRow('代理地址', this.proxyUrl, (value: string) => {
        this.proxyUrl = value;
        this.apply({
          request_proxy: { enabled: this.proxyEnabled, url: value, bypass: this.splitBypass() }
        }, '代理地址');
      })
      this.textAreaRow('直连白名单（每行一个 host）', this.proxyBypass, (value: string) => {
        this.proxyBypass = value;
        this.apply({
          request_proxy: { enabled: this.proxyEnabled, url: this.proxyUrl, bypass: this.splitBypass() }
        }, '直连白名单');
      })
    }
    .width('100%')
    .padding(Spacing.md)
    .borderRadius(GLASS_CARD.radius)
    .backgroundColor(this.uiColors.bgSurface)
    .border({ width: 1, color: this.uiColors.borderSubtle })
  }

  @Builder
  modelsSection() {
    Column({ space: Spacing.sm }) {
      SectionTitle('模型（Models）', this.uiColors)
      Row({ space: Spacing.sm }) {
        Text('Claude Prompt Cache')
          .fontSize(Typography.caption)
          .fontColor(this.uiColors.textSecondary)
          .layoutWeight(1)
        ForEach(['off', '5m', '1h'], (option: string) => {
          Button(option, { type: ButtonType.Normal })
            .fontSize(UIType.caption)
            .constraintSize({ minHeight: 44 })
            .backgroundColor(this.promptCacheTtl === option ? this.uiColors.accent : this.uiColors.bgSurfaceHigh)
            .fontColor(this.promptCacheTtl === option ? this.uiColors.textInverse : this.uiColors.textSecondary)
            .onClick(() => {
              this.promptCacheTtl = option;
              this.apply({ models: { claude: { prompt_cache_ttl: option } } }, '提示缓存 TTL');
            })
        .attributeModifier(new ActionButtonStyle(this.uiColors, (this.promptCacheTtl === option) ? ActionTone.Selected : ActionTone.Normal))
      }, (option: string) => option)
      }
      .width('100%')
    }
    .width('100%')
    .padding(Spacing.md)
    .borderRadius(GLASS_CARD.radius)
    .backgroundColor(this.uiColors.bgSurface)
    .border({ width: 1, color: this.uiColors.borderSubtle })
  }

  @Builder
  agentSection() {
    Column({ space: Spacing.sm }) {
      SectionTitle('Agent 运行记录保留', this.uiColors)
      this.switchRow('自动清理旧运行记录', this.autoPrune, (next: boolean) => {
        this.autoPrune = next;
        this.apply({
          agent: {
            retention: {
              auto_prune_enabled: next,
              keep_recent_terminal_runs: this.parseNumber(this.keepTerminal, 50),
              keep_full_recent_runs: this.parseNumber(this.keepFull, 10)
            }
          }
        }, 'Agent 自动清理');
      })
      this.textRow('保留最近终态运行数', this.keepTerminal, (value: string) => {
        this.keepTerminal = value;
        this.apply({
          agent: {
            retention: {
              auto_prune_enabled: this.autoPrune,
              keep_recent_terminal_runs: this.parseNumber(value, 50),
              keep_full_recent_runs: this.parseNumber(this.keepFull, 10)
            }
          }
        }, '保留终态运行数');
      })
      this.textRow('保留完整运行数', this.keepFull, (value: string) => {
        this.keepFull = value;
        this.apply({
          agent: {
            retention: {
              auto_prune_enabled: this.autoPrune,
              keep_recent_terminal_runs: this.parseNumber(this.keepTerminal, 50),
              keep_full_recent_runs: this.parseNumber(value, 10)
            }
          }
        }, '保留完整运行数');
      })
    }
    .width('100%')
    .padding(Spacing.md)
    .borderRadius(GLASS_CARD.radius)
    .backgroundColor(this.uiColors.bgSurface)
    .border({ width: 1, color: this.uiColors.borderSubtle })
  }

  @Builder
  miscSection() {
    Column({ space: Spacing.sm }) {
      SectionTitle('杂项（Misc）', this.uiColors)
      this.switchRow('允许查看已保存的密钥明文', this.allowKeysExposure, (next: boolean) => {
        this.allowKeysExposure = next;
        this.apply({ allow_keys_exposure: next }, '密钥暴露');
      })
      Button('个性化 · 主题与显示', { type: ButtonType.Normal })
        .onClick((): void => { ROOT_PATH_STACK.pushPathByName('pages/AppearancePage', null); })
    .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
    .width('100%')
    .padding(Spacing.md)
    .borderRadius(GLASS_CARD.radius)
    .backgroundColor(this.uiColors.bgSurface)
    .border({ width: 1, color: this.uiColors.borderSubtle })
  }

  // ---- 行控件 ----

  @Builder
  switchRow(label: string, value: boolean, onChange: (next: boolean) => void) {
    Row({ space: Spacing.sm }) {
      Text(label)
        .fontSize(Typography.caption)
        .fontColor(this.uiColors.textSecondary)
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: value })
        .selectedColor(this.uiColors.accent)
        .onChange((isOn: boolean) => {
          onChange(isOn);
        })
    }
    .width('100%')
  }

  @Builder
  textRow(label: string, value: string, onCommit: (value: string) => void) {
    Column({ space: 2 }) {
      Text(label)
        .fontSize(Typography.micro)
        .fontColor(this.uiColors.textTertiary)
        .width('100%')
      TextInput({ text: value })
        .fontColor(this.uiColors.textPrimary)
        .placeholderColor(this.uiColors.textTertiary)
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(UIRadius.sm)
        .fontSize(Typography.caption)
        .constraintSize({ minHeight: 44 })
        .width('100%')
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(Radius.sm)
        .onSubmit(() => {
          onCommit(value);
        })
        .onChange((next: string) => {
          onCommit(next);
        })
    .attributeModifier(new InputFieldStyle(this.uiColors))
      }
    .width('100%')
  }

  @Builder
  textAreaRow(label: string, value: string, onCommit: (value: string) => void) {
    Column({ space: 2 }) {
      Text(label)
        .fontSize(Typography.micro)
        .fontColor(this.uiColors.textTertiary)
        .width('100%')
      TextArea({ text: value, placeholder: 'example.com' })
        .fontColor(this.uiColors.textPrimary)
        .placeholderColor(this.uiColors.textTertiary)
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(UIRadius.sm)
        .fontSize(Typography.caption)
        .height(72)
        .width('100%')
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(Radius.sm)
        .onChange((next: string) => {
          onCommit(next);
        })
    .attributeModifier(new TextAreaFieldStyle(this.uiColors))
      }
    .width('100%')
  }

  splitBypass(): string[] {
    const lines: string[] = this.proxyBypass.split('\n');
    const result: string[] = [];
    for (let i = 0; i < lines.length; i++) {
      const item: string = lines[i].trim();
      if (item !== '') {
        result.push(item);
      }
    }
    return result;
  }

  fmtBytes(value: number): string {
    if (value >= MB) {
      return `${Math.round(value / MB * 10) / 10} MB`;
    }
    if (value >= 1024) {
      return `${Math.round(value / 1024)} KB`;
    }
    return `${value} B`;
  }
}
