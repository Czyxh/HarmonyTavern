import { SurfaceStyle } from '../theme/SurfaceStyles';
import { SegmentedPicker } from '../components/SegmentedPicker';
import { JellyTabItem } from '../components/JellyTabBar';
import { ActionButtonStyle, ActionTone, InputFieldStyle, TextAreaFieldStyle } from '../theme/ControlStyles';
import { HeaderAction } from '../components/HeaderAction';
import { OriginPanelState } from '../theme/OriginMotion';
import { OriginPanel } from '../components/OriginPanel';
import { ChatPanel } from '../components/ChatPanel';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { PageSurface } from '../components/PageSurface';
import { Radius as UIRadius, Typography as UIType } from '../theme/Tokens';
import { PageHeader } from '../components/PageHeader';
// 工具（P8-21）：设置快照 / 聊天搜索 / token 计数。
//
// 这三块在原项目里分别是：
//   - 设置快照：SillyTavern 的「备份当前设置 / 恢复」→ create_settings_snapshot 等 4 条命令
//   - 聊天搜索：ST 的搜索框（跨角色搜聊天正文预览）→ search_chats
//   - token 计数：ST 的 ContextMeter（显示上下文用了多少 token）→ count_openai_tokens_batch
//
// 对应 DevEco 工程路径：entry/src/main/ets/pages/ToolsPage.ets
import { Backend, BackendError, SettingsSnapshotDto } from '../backend/Backend';
import { ChatSearchResult } from '../backend/AdminTypes';
import { CharacterDto } from '../backend/Types';
import { ROOT_PATH_STACK } from '../nav/RootNav';
import { Radius, Spacing, Touch, Typography } from '../theme/Tokens';
import { GLASS_CARD, GLASS_HEADER, glassEffect } from '../theme/Glass';
import { EmptyHint, ErrorBannerView, SectionTitle } from '../components/Builders';

interface ToolTab {
  id: string;
  label: string;
}

const TABS: ToolTab[] = [
  { id: 'snapshots', label: '设置快照' },
  { id: 'search', label: '聊天搜索' },
  { id: 'tokens', label: 'Token 计数' }
];
const TOOL_ITEMS: JellyTabItem[] = TABS.map((item: ToolTab): JellyTabItem => ({ glyph: '', label: item.label }));

@Component
export struct ToolsPage {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @State tab: string = 'snapshots';
  @State loading: boolean = true;
  @State busy: boolean = false;
  @State errorText: string = '';
  @State statusText: string = '';

  // 设置快照
  @State snapshots: SettingsSnapshotDto[] = [];
  @State restoreOrigin: OriginPanelState = new OriginPanelState();
  @State pendingRestore: SettingsSnapshotDto | null = null;

  // 聊天搜索
  @State query: string = '';
  @State characterFilter: string = '';
  @State results: ChatSearchResult[] = [];
  @State searched: boolean = false;

  // token 计数
  @State tokenModel: string = 'gpt-3.5-turbo';
  @State tokenText: string = '';
  @State tokenCount: string = '';

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
      if (this.tab === 'snapshots') {
        this.snapshots = await Backend.getSettingsSnapshots();
        if (this.snapshots.length === 0) {
          this.statusText = '还没有设置快照';
        } else {
          this.statusText = `${this.snapshots.length} 份快照`;
        }
      }
    } catch (err) {
      this.errorText = `读取失败：${(err as BackendError).message}`;
    } finally {
      this.loading = false;
    }
  }

  switchTab(next: string): void {
    if (this.tab === next) {
      return;
    }
    this.tab = next;
    this.statusText = '';
    this.errorText = '';
    this.reload();
  }

  async createSnapshot(): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      await Backend.createSettingsSnapshot();
      this.statusText = '已创建设置快照';
      await this.reload();
    } catch (err) {
      this.errorText = `创建快照失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  confirmRestore(snapshot: SettingsSnapshotDto): void {
    if (this.busy) { return; }
    this.pendingRestore = snapshot;
    this.errorText = '';
    this.restoreOrigin.open(this.getUIContext(), 'snapshot-restore-' + snapshot.name, 0.58);
  }

  async restore(snapshot: SettingsSnapshotDto): Promise<void> {
    if (this.busy) { return; }
    this.busy = true;
    this.errorText = '';
    try {
      await Backend.restoreSettingsSnapshot(snapshot.name);
      this.statusText = `已恢复 ${snapshot.name}`;
      await this.reload();
      this.restoreOrigin.close();
    } catch (err) {
      this.errorText = `恢复失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async runSearch(): Promise<void> {
    if (this.query.trim() === '') {
      this.errorText = '先输入搜索关键字';
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      const rows: ChatSearchResult[] = await Backend.searchChats(
        this.query.trim(),
        this.characterFilter.trim() === '' ? undefined : this.characterFilter.trim());
      this.results = rows;
      this.searched = true;
      this.statusText = `命中 ${rows.length} 个聊天`;
    } catch (err) {
      this.errorText = `搜索失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async countTokens(): Promise<void> {
    if (this.tokenText.trim() === '') {
      this.errorText = '先输入要统计的文本';
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      const count: number = await Backend.countTokens(this.tokenModel.trim(), this.tokenText);
      this.tokenCount = `${count} tokens`;
      this.statusText = `按模型 ${this.tokenModel} 统计`;
    } catch (err) {
      this.errorText = `统计失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  snapshotTime(date: number): string {
    const d: Date = new Date(date);
    const pad = (v: number): string => v < 10 ? `0${v}` : `${v}`;
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  snapshotSize(size: number): string {
    if (size < 1024) {
      return `${size} B`;
    }
    if (size < 1024 * 1024) {
      return `${(size / 1024).toFixed(1)} KB`;
    }
    return `${(size / (1024 * 1024)).toFixed(1)} MB`;
  }

  searchTime(date: number): string {
    return this.snapshotTime(date);
  }

  @Builder
  pageTopBar() {
    PageHeader({
        title: '工具',
        subtitle: '扩展对话的可能性',
        onBack: () => {
            ROOT_PATH_STACK.pop();
        }
      }) {
        HeaderAction({ label: '刷新', marker: 'toolspage-refresh-1', available: !this.busy,
          pending: this.loading,
          onAction: async (): Promise<void> => { await this.reload(); } })
      }
  }

  @Builder
  buildSurfaceContent() {
      Column({ space: Spacing.sm }) {
        
  
        SegmentedPicker({ items: TOOL_ITEMS, selectedIndex: TABS.findIndex((item: ToolTab) => item.id === this.tab),
          available: !this.busy,
          onSelect: (index: number): void => { this.switchTab(TABS[index].id); } })

        if (this.statusText !== '') {
          Text(this.statusText)
            .fontSize(Typography.micro)
            .fontColor(this.uiColors.textTertiary)
            .width('100%')
            .padding({ left: Spacing.md, right: Spacing.md })
            .maxLines(3)
        }
        ErrorBannerView({ text: this.errorText })
  
        Column() {
          Column({ space: Spacing.md }) {
            if (this.loading) {
              Text('读取中…').fontSize(Typography.caption).fontColor(this.uiColors.textTertiary)
            } else if (this.tab === 'snapshots') {
              this.snapshotsTab()
            } else if (this.tab === 'search') {
              this.searchTab()
            } else {
              this.tokensTab()
            }
          }
          .width('100%')
          .padding({ bottom: 130 })
        }
        .width('100%')
        .align(Alignment.Top)
      }
      .width('100%')
      .backgroundColor(this.uiColors.bgBase)
    }

  @Builder
  restoreBody() {
    Text('用「' + (this.pendingRestore?.name ?? '') + '」覆盖当前设置？')
      .fontSize(16).fontColor(this.uiColors.textPrimary).lineHeight(25).width('100%')
    Text('不会删除聊天记录。恢复前自动保存当前设置快照，方便之后撤回。')
      .fontSize(14).fontColor(this.uiColors.textSecondary).lineHeight(22).width('100%')
    if (this.errorText !== '') { Text(this.errorText).fontColor(this.uiColors.danger).width('100%') }
    Button(this.busy ? '正在恢复…' : '确认恢复', { type: ButtonType.Normal })
      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary)).width('100%').constraintSize({ minHeight: 48 })
      .enabled(!this.busy && this.pendingRestore !== null).id('snapshot-confirm-restore')
      .onClick((): void => { if (this.pendingRestore !== null) { this.restore(this.pendingRestore); } })
    Button('取消', { type: ButtonType.Normal }).attributeModifier(new ActionButtonStyle(this.uiColors)).width('100%')
      .constraintSize({ minHeight: 48 }).enabled(!this.busy).id('snapshot-cancel-restore')
      .onClick((): void => { this.restoreOrigin.close(); })
  }

  @Builder
  restorePanel() {
    ChatPanel({ title: '恢复设置快照', subtitle: '恢复前会自动备份当前设置', managedLayout: true,
      onContentHeight: (height: number): void => { this.restoreOrigin.fitContentHeight(height); },
      onClose: (): void => { if (!this.busy) { this.restoreOrigin.close(); } },
      content: (): void => { this.restoreBody(); } })
  }

  @Builder
  restoreConfirmation() {
    OriginPanel({ state: this.restoreOrigin, preventClose: this.busy,
      onClosed: (): void => { this.pendingRestore = null; },
      content: (): void => { this.restorePanel(); } })
  }

  build() {
    PageSurface({ topBar: () => { this.pageTopBar(); }, content: () => { this.buildSurfaceContent(); } })
      .bindContentCover(this.restoreOrigin.presented, this.restoreConfirmation(), {
        modalTransition: ModalTransition.NONE, backgroundColor: Color.Transparent,
        onWillDismiss: (): void => { if (!this.busy) { this.restoreOrigin.close(); } },
        onDisappear: (): void => { this.restoreOrigin.dismissed(); }
      })
  }

  @Builder
  snapshotsTab() {
    Column({ space: Spacing.md }) {
      Text('设置快照 = 整份 settings.json 的时间点副本。改坏了随时回滚，恢复前会自动再存一份。')
        .fontSize(Typography.micro)
        .fontColor(this.uiColors.textTertiary)
        .width('100%')
      Button('立即创建快照', { type: ButtonType.Normal })
        .fontSize(Typography.caption)
        .height(Touch.minTarget)
        .width('100%')
        .enabled(!this.busy)
        .onClick(() => {
          this.createSnapshot();
        })

      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      if (this.snapshots.length === 0) {
        EmptyHint('还没有设置快照', '点上面「立即创建快照」，之后改设置前也能回滚', this.uiColors)
      } else {
        ForEach(this.snapshots, (snapshot: SettingsSnapshotDto) => {
          Column({ space: 6 }) {
            Text(snapshot.name)
              .fontSize(Typography.caption)
              .fontColor(this.uiColors.textPrimary)
              .width('100%')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(`${this.snapshotTime(snapshot.date)} · ${this.snapshotSize(snapshot.size)}`)
              .fontSize(Typography.micro)
              .fontColor(this.uiColors.textTertiary)
              .width('100%')
            Row({ space: 6 }) {
              Button('恢复这份', { type: ButtonType.Normal })
                .fontSize(UIType.micro)
                .constraintSize({ minHeight: 44 })
                .layoutWeight(1)
                .enabled(!this.busy)
                .id('snapshot-restore-' + snapshot.name)
                .onClick(() => {
                  this.confirmRestore(snapshot);
                })
            .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      }
            .width('100%')
          }
          .width('100%')
          .padding(Spacing.md)
          .backgroundColor(this.uiColors.bgSurface)
          .borderRadius(Radius.md)
          .attributeModifier(new SurfaceStyle(this.uiColors, Radius.md))
        }, (snapshot: SettingsSnapshotDto) => snapshot.name)
      }
    }
    .width('100%')
  }

  @Builder
  searchTab() {
    Column({ space: Spacing.md }) {
      Text('跨角色搜聊天正文，命中会给预览片段。')
        .fontSize(Typography.micro)
        .fontColor(this.uiColors.textTertiary)
        .width('100%')
      TextInput({ placeholder: '搜索关键字…', text: this.query })
        .fontColor(this.uiColors.textPrimary)
        .placeholderColor(this.uiColors.textTertiary)
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(UIRadius.sm)
        .fontSize(Typography.caption)
        .height(Touch.minTarget)
        .width('100%')
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .onChange((value: string) => {
          this.query = value;
        })
        .onSubmit(() => {
          this.runSearch();
        })
      .attributeModifier(new InputFieldStyle(this.uiColors))
      TextInput({ placeholder: '只看某个角色（可选）', text: this.characterFilter })
        .fontColor(this.uiColors.textPrimary)
        .placeholderColor(this.uiColors.textTertiary)
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(UIRadius.sm)
        .fontSize(Typography.caption)
        .height(Touch.minTarget)
        .width('100%')
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .onChange((value: string) => {
          this.characterFilter = value;
        })
      .attributeModifier(new InputFieldStyle(this.uiColors))
      Button('搜索', { type: ButtonType.Normal })
        .fontSize(Typography.caption)
        .height(Touch.minTarget)
        .width('100%')
        .enabled(!this.busy)
        .onClick(() => {
          this.runSearch();
        })

      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      if (this.searched && this.results.length === 0) {
        EmptyHint('没有命中', '换个关键字试试，或者清掉角色过滤', this.uiColors)
      } else {
        ForEach(this.results, (row: ChatSearchResult) => {
          Column({ space: 4 }) {
            Text(`${row.character_name} / ${row.file_name}`)
              .fontSize(Typography.caption)
              .fontColor(this.uiColors.textPrimary)
              .width('100%')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(`${row.message_count ?? 0} 条消息 · ${row.create_date ?? ""}`)
              .fontSize(Typography.micro)
              .fontColor(this.uiColors.textTertiary)
              .width('100%')
            Text((row.preview_message ?? row.last_message ?? ""))
              .fontSize(Typography.micro)
              .fontColor(this.uiColors.textSecondary)
              .width('100%')
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .padding(Spacing.md)
          .backgroundColor(this.uiColors.bgSurface)
          .borderRadius(Radius.md)
          .attributeModifier(new SurfaceStyle(this.uiColors, Radius.md))
        }, (row: ChatSearchResult) => `${row.character_name}/${row.file_name}`)
      }
    }
    .width('100%')
  }

  @Builder
  tokensTab() {
    Column({ space: Spacing.md }) {
      SectionTitle('上下文用量估算', this.uiColors)
      Text('按指定模型的分词器统计文本 token 数——粘贴一段提示词或历史记录，就能知道它占多少上下文。')
        .fontSize(Typography.micro)
        .fontColor(this.uiColors.textTertiary)
        .width('100%')
      TextInput({ placeholder: '模型名，例如 gpt-3.5-turbo', text: this.tokenModel })
        .fontColor(this.uiColors.textPrimary)
        .placeholderColor(this.uiColors.textTertiary)
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(UIRadius.sm)
        .fontSize(Typography.caption)
        .height(Touch.minTarget)
        .width('100%')
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .onChange((value: string) => {
          this.tokenModel = value;
        })
      .attributeModifier(new InputFieldStyle(this.uiColors))
      TextArea({ text: this.tokenText, placeholder: '粘贴要统计的文本…' })
        .fontColor(this.uiColors.textPrimary)
        .placeholderColor(this.uiColors.textTertiary)
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(UIRadius.sm)
        .fontSize(Typography.caption)
        .height(160)
        .width('100%')
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(Radius.sm)
        .onChange((value: string) => {
          this.tokenText = value;
        })
      .attributeModifier(new TextAreaFieldStyle(this.uiColors))
      Button('统计', { type: ButtonType.Normal })
        .fontSize(Typography.caption)
        .height(Touch.minTarget)
        .width('100%')
        .enabled(!this.busy)
        .onClick(() => {
          this.countTokens();
        })
      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      if (this.tokenCount !== '') {
        Text(this.tokenCount)
          .fontSize(Typography.title)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.uiColors.accent)
          .width('100%')
          .textAlign(TextAlign.Center)
        Text(`${this.tokenText.length} 字符`)
          .fontSize(Typography.micro)
          .fontColor(this.uiColors.textTertiary)
          .width('100%')
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .padding(Spacing.md)
    .borderRadius(GLASS_CARD.radius)
    .backgroundColor(this.uiColors.bgSurface)
    .border({ width: 1, color: this.uiColors.borderSubtle })
  }
}
