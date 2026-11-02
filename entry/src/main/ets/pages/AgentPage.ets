import { SurfaceStyle } from '../theme/SurfaceStyles';
import { ActionButtonStyle, ActionTone } from '../theme/ControlStyles';
import { HeaderAction } from '../components/HeaderAction';
import { OriginMotion } from '../theme/OriginMotion';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { PageSurface } from '../components/PageSurface';
import { Radius as UIRadius, Typography as UIType } from '../theme/Tokens';
import { PageHeader } from '../components/PageHeader';
// Agent 运行记录与配置档（P8-8）：对应原项目 src/scripts/extensions/agent-system
//   RunHistoryPanel / RunTimelineApp / RunRetentionPanel / AgentSystemPanel（配置档列表）。
//
// 已搬：运行列表（可取消）、运行事件时间线、保留策略的"预览计划 → 执行清理"、
//       Agent 配置档列表与诊断。
// 未搬（后续）：配置档草稿编辑器（identity/policy/tools/resources 分区表单）、
//       子 Agent 时间线、嵌入资源包管理。这些依赖更细的后端读写协议，留待下一轮。
//
// 对应 DevEco 工程路径：entry/src/main/ets/pages/AgentPage.ets
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Backend, BackendError } from '../backend/Backend';
import {
  AgentListProfilesResultDto,
  AgentListRunsResultDto,
  AgentRunEventDto,
  AgentRunPruneApplyResultDto,
  AgentRunPrunePlanDto,
  AgentRunSummaryDto
} from '../backend/Types';
import { ROOT_PATH_STACK } from '../nav/RootNav';
import { Radius, Spacing, Typography } from '../theme/Tokens';
import { GLASS_CARD, GLASS_HEADER, glassEffect } from '../theme/Glass';
import { EmptyHint, ErrorBannerView, SectionTitle } from '../components/Builders';

const DOMAIN: number = 0x0004;
const TAG: string = 'HarmonyTavern';

@Component
export struct AgentPage {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  /** 'runs' | 'profiles' */
  @State tab: string = 'runs';
  @State loading: boolean = true;
  @State busy: boolean = false;
  @State errorText: string = '';
  @State statusText: string = '';

  @State runs: AgentRunSummaryDto[] = [];
  @State selectedRun: string = '';
  @State events: AgentRunEventDto[] = [];
  @State eventsNote: string = '';

  @State profiles: ESObject[] = [];
  @State profileNote: string = '';

  @State planText: string = '';

  // P8-20 会话 / 工具
  @State sessions: ESObject[] = [];
  @State sessionNote: string = '';
  @State selectedSession: string = '';
  @State sessionDetail: string = '';
  @State tools: ESObject[] = [];
  @State toolsNote: string = '';
  @State pruning: boolean = false;

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
      if (this.tab === 'runs') {
        const result: AgentListRunsResultDto = await Backend.listAgentRuns({ limit: 50 });
        this.runs = result.runs;
        if (this.runs.length === 0) {
          this.events = [];
          this.selectedRun = '';
          this.eventsNote = '';
        }
      } else if (this.tab === 'profiles') {
        const result: AgentListProfilesResultDto = await Backend.listAgentProfiles();
        const list: ESObject[] = [];
        for (let i = 0; i < result.profiles.length; i++) {
          list.push(result.profiles[i] as ESObject);
        }
        this.profiles = list;
        this.profileNote = `${result.profiles.length} 个配置档`;
      } else if (this.tab === 'sessions') {
        const result: ESObject = await Backend.listAgentSessions();
        const raw: ESObject[] = result.sessions as ESObject[];
        this.sessions = raw === undefined || raw === null ? [] : raw;
        this.sessionNote = `${this.sessions.length} 个会话`;
        if (this.sessions.length === 0) {
          this.selectedSession = '';
          this.sessionDetail = '';
        }
      } else {
        const result: ESObject = await Backend.listAgentTools();
        const raw: ESObject[] = result.tools as ESObject[];
        this.tools = raw === undefined || raw === null ? [] : raw;
        this.toolsNote = `${this.tools.length} 个工具`;
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
    this.reload();
  }

  async openRun(run: AgentRunSummaryDto): Promise<void> {
    this.selectedRun = run.runId;
    this.events = [];
    this.eventsNote = '读取事件…';
    this.busy = true;
    try {
      const result = await Backend.readAgentRunEvents({
        runId: run.runId,
        limit: 100,
        includeTimelineProjection: false
      });
      const list: AgentRunEventDto[] = [];
      for (let i = 0; i < result.events.length; i++) {
        list.push(result.events[i] as AgentRunEventDto);
      }
      this.events = list;
      this.eventsNote = `共 ${list.length} 条事件`;
    } catch (err) {
      this.eventsNote = '';
      this.errorText = `读取事件失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async cancelRun(run: AgentRunSummaryDto): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      await Backend.cancelAgentRun({ runId: run.runId });
      this.statusText = `已请求取消 ${run.runId.substring(0, 12)}…`;
      await this.reload();
    } catch (err) {
      this.errorText = `取消失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  /** 保留策略：先 plan 看会动多少，再 apply。 */
  async planPrune(): Promise<void> {
    this.busy = true;
    this.errorText = '';
    this.planText = '';
    try {
      const plan: AgentRunPrunePlanDto = await Backend.planAgentRunPrune({ detailLimit: 50 });
      this.planText = `终态运行 ${plan.terminalRunCount} 个，进行中 ${plan.nonTerminalRunCount} 个；`
        + `将精简 ${plan.slimCandidateCount} 个、删除 ${plan.deleteCandidateCount} 个`;
      this.pruning = true;
    } catch (err) {
      this.errorText = `计算清理计划失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async applyPrune(): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      const result: AgentRunPruneApplyResultDto = await Backend.applyAgentRunPrune({ detailLimit: 50 });
      this.statusText = `已精简 ${result.slimmedRuns} 个、删除 ${result.deletedRuns} 个运行，释放 ${result.freedBytes} 字节`;
      this.pruning = false;
      this.planText = '';
      await this.reload();
    } catch (err) {
      this.errorText = `执行清理失败：${(err as BackendError).message}`;
      hilog.error(DOMAIN, TAG, 'prune failed: %{public}s', this.errorText);
    } finally {
      this.busy = false;
    }
  }

  async diagnose(profile: ESObject): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      const id: ESObject = profile.id as ESObject;
      const result: ESObject = await Backend.diagnoseAgentProfile({ profileId: String(id) });
      this.statusText = `诊断：${JSON.stringify(result)}`;
    } catch (err) {
      this.errorText = `诊断失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  @Builder
  pageTopBar() {
    PageHeader({
        title: 'Agent',
        subtitle: '自动化任务与运行记录',
        onBack: () => {
            ROOT_PATH_STACK.pop();
        }
      }) {
        HeaderAction({ label: '刷新', marker: 'agentpage-refresh-1', available: !this.busy,
          pending: this.loading,
          onAction: async (): Promise<void> => { await this.reload(); } })
      }
  }

  @Builder
  buildSurfaceContent() {
      Column({ space: Spacing.sm }) {
        
  
        Row({ space: 6 }) {
          Button('运行记录', { type: ButtonType.Normal })
            .fontSize(UIType.caption)
            .constraintSize({ minHeight: 44 })
            .backgroundColor(this.tab === 'runs' ? this.uiColors.accent : this.uiColors.bgSurfaceHigh)
            .fontColor(this.tab === 'runs' ? this.uiColors.textInverse : this.uiColors.textSecondary)
            .onClick(() => {
              this.switchTab('runs');
            })
          .attributeModifier(new ActionButtonStyle(this.uiColors, (this.tab === 'runs') ? ActionTone.Selected : ActionTone.Normal))
      Button('配置档', { type: ButtonType.Normal })
            .fontSize(UIType.caption)
            .constraintSize({ minHeight: 44 })
            .backgroundColor(this.tab === 'profiles' ? this.uiColors.accent : this.uiColors.bgSurfaceHigh)
            .fontColor(this.tab === 'profiles' ? this.uiColors.textInverse : this.uiColors.textSecondary)
            .onClick(() => {
              this.switchTab('profiles');
            })
          .attributeModifier(new ActionButtonStyle(this.uiColors, (this.tab === 'profiles') ? ActionTone.Selected : ActionTone.Normal))
      Button('会话', { type: ButtonType.Normal })
            .fontSize(UIType.caption)
            .constraintSize({ minHeight: 44 })
            .backgroundColor(this.tab === 'sessions' ? this.uiColors.accent : this.uiColors.bgSurfaceHigh)
            .fontColor(this.tab === 'sessions' ? this.uiColors.textInverse : this.uiColors.textSecondary)
            .onClick(() => {
              this.switchTab('sessions');
            })
          .attributeModifier(new ActionButtonStyle(this.uiColors, (this.tab === 'sessions') ? ActionTone.Selected : ActionTone.Normal))
      Button('工具', { type: ButtonType.Normal })
            .fontSize(UIType.caption)
            .constraintSize({ minHeight: 44 })
            .backgroundColor(this.tab === 'tools' ? this.uiColors.accent : this.uiColors.bgSurfaceHigh)
            .fontColor(this.tab === 'tools' ? this.uiColors.textInverse : this.uiColors.textSecondary)
            .onClick(() => {
              this.switchTab('tools');
            })
        .attributeModifier(new ActionButtonStyle(this.uiColors, (this.tab === 'tools') ? ActionTone.Selected : ActionTone.Normal))
      }
        .width('100%')
        .padding({ left: Spacing.md })
  
        if (this.statusText !== '') {
          Text(this.statusText)
            .fontSize(Typography.micro)
            .fontColor(this.uiColors.textTertiary)
            .width('100%')
            .padding({ left: Spacing.md, right: Spacing.md })
            .maxLines(4)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        ErrorBannerView({ text: this.errorText })
  
        Column() {
          Column({ space: Spacing.md }) {
            if (this.loading) {
              Text('读取中…').fontSize(Typography.caption).fontColor(this.uiColors.textTertiary)
            } else if (this.tab === 'runs') {
              this.runsTab()
            } else if (this.tab === 'profiles') {
              this.profilesTab()
            } else if (this.tab === 'sessions') {
              this.sessionsTab()
            } else {
              this.toolsTab()
            }
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

  // ---- P8-20 会话 ----

  async createSession(): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      const created: ESObject = await Backend.createAgentSession();
      const createdSession: ESObject = created.session as ESObject;
      this.statusText = `已创建会话 ${(createdSession.id as string) ?? "?"}`;
      await this.reload();
    } catch (err) {
      this.errorText = `创建会话失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async openSession(session: ESObject): Promise<void> {
    const id: string = session.id as string;
    this.selectedSession = id;
    this.busy = true;
    this.errorText = '';
    try {
      const detail: ESObject = await Backend.readAgentSession({ sessionId: id });
      const info: ESObject = detail.session as ESObject;
      const msgs: ESObject[] = detail.messages as ESObject[];
      const lastSeq: number = (detail.lastSeq as number) ?? 0;
      const title: string = (info === undefined || info === null) ? id : ((info.title as string) ?? id);
      const count: number = msgs === undefined || msgs === null ? 0 : msgs.length;
      this.sessionDetail = `${title} · 已载入 ${count} 条消息 · lastSeq ${lastSeq}`;
    } catch (err) {
      this.sessionDetail = '';
      this.errorText = `读取会话失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async renameSession(session: ESObject): Promise<void> {
    const id: string = session.id as string;
    const current: string = (session.title as string) ?? '';
    this.getUIContext().showTextPickerDialog({
      range: [current],
      onAccept: (value: TextPickerResult) => {
        this.applyRename(id, value.value as string);
      }
    });
  }

  async applyRename(sessionId: string, title: string): Promise<void> {
    if (title === '' || title === undefined) {
      return;
    }
    this.busy = true;
    try {
      await Backend.renameAgentSession({ sessionId: sessionId, title: title });
      this.statusText = `已重命名为 ${title}`;
      await this.reload();
    } catch (err) {
      this.errorText = `重命名失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async deleteSession(session: ESObject): Promise<void> {
    const id: string = session.id as string;
    this.getUIContext().showAlertDialog({
      title: '删除会话',
      alignment: DialogAlignment.Center,
      transition: OriginMotion.dialog(this.getUIContext(), 'agent-delete-' + id),
      message: `确定删除会话「${(session.title as string) ?? id}」？`,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        action: () => {
          this.applyDeleteSession(id);
        }
      }
    });
  }

  async applyDeleteSession(sessionId: string): Promise<void> {
    this.busy = true;
    try {
      await Backend.deleteAgentSession({ sessionId: sessionId });
      this.statusText = `已删除会话 ${sessionId}`;
      if (this.selectedSession === sessionId) {
        this.selectedSession = '';
        this.sessionDetail = '';
      }
      await this.reload();
    } catch (err) {
      this.errorText = `删除失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  sessionLabel(session: ESObject): string {
    const id: string = session.id as string;
    const title: string = session.title as string;
    const updated: string = session.lastUsedAt as string;
    const head: string = title === undefined || title === null || title === '' ? id : title;
    return updated === undefined || updated === null ? head : `${head} · ${updated}`;
  }

  // ---- P8-20 工具 ----

  /** AgentToolCatalogItemDto：{ id, nativeName, title, description, source, enabled } */
  toolLabel(tool: ESObject): string {
    const title: string = tool.title as string;
    const native: string = tool.nativeName as string;
    const source: string = tool.source as string;
    const enabled: boolean = tool.enabled as boolean;
    const head: string = title === undefined || title === null || title === '' ? native : title;
    const parts: string = `${head} · ${source}`;
    return enabled === false ? `${parts}（已禁用）` : parts;
  }

  @Builder
  sessionsTab() {
    Column({ space: Spacing.md }) {
      Row({ space: Spacing.sm }) {
        Button('新建会话', { type: ButtonType.Normal })
          .fontSize(UIType.caption)
          .constraintSize({ minHeight: 44 })
          .layoutWeight(1)
          .enabled(!this.busy)
          .onClick(() => {
            this.createSession();
          })
        .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Text(this.sessionNote)
          .fontSize(Typography.micro)
          .fontColor(this.uiColors.textTertiary)
      }
      .width('100%')

      if (this.sessionDetail !== '') {
        Text(this.sessionDetail)
          .fontSize(Typography.caption)
          .fontColor(this.uiColors.textSecondary)
          .width('100%')
      }

      if (this.sessions.length === 0) {
        EmptyHint('还没有 Agent 会话', '点「新建会话」创建一个独立上下文；Agent 执行由聊天页触发', this.uiColors)
      } else {
        ForEach(this.sessions, (session: ESObject) => {
          Column({ space: 6 }) {
            Text(this.sessionLabel(session))
              .fontSize(Typography.caption)
              .fontColor(this.uiColors.textPrimary)
              .width('100%')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Row({ space: 6 }) {
              Button('查看', { type: ButtonType.Normal })
                .fontSize(UIType.micro)
                .constraintSize({ minHeight: 44 })
                .layoutWeight(1)
                .backgroundColor(this.uiColors.bgSurfaceHigh)
                .fontColor(this.uiColors.textSecondary)
                .onClick(() => {
                  this.openSession(session);
                })

              .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button('改名', { type: ButtonType.Normal })
                .fontSize(UIType.micro)
                .constraintSize({ minHeight: 44 })
                .layoutWeight(1)
                .backgroundColor(this.uiColors.bgSurfaceHigh)
                .fontColor(this.uiColors.textSecondary)
                .onClick(() => {
                  this.renameSession(session);
                })
              .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button('删除', { type: ButtonType.Normal })
                .fontSize(UIType.micro)
                .constraintSize({ minHeight: 44 })
                .layoutWeight(1)
                .backgroundColor(this.uiColors.danger)
                .id('agent-delete-' + (session.id as string))
                .onClick(() => {
                  this.deleteSession(session);
                })
            .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Danger))
      }
            .width('100%')
          }
          .width('100%')
          .padding(Spacing.md)
          .backgroundColor(this.uiColors.bgSurface)
          .borderRadius(Radius.md)
          .attributeModifier(new SurfaceStyle(this.uiColors, Radius.md))
        }, (session: ESObject) => (session.id as string) ?? 'session')
      }

      Text('Agent 会话 = 独立的对话上下文 + 配置档 + 工作区。运行由聊天页的 Agent 模式触发，这里看列表、改名和清理。')
        .fontSize(Typography.micro)
        .fontColor(this.uiColors.textTertiary)
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  toolsTab() {
    Column({ space: Spacing.sm }) {
      Text(`可用工具（${this.toolsNote}）`)
        .fontSize(Typography.caption)
        .fontColor(this.uiColors.textSecondary)
        .width('100%')
      if (this.tools.length === 0) {
        EmptyHint('没有可用工具', '工具由扩展注册；先在「扩展管理」里装一个带工具的扩展', this.uiColors)
      } else {
        ForEach(this.tools, (tool: ESObject) => {
          Column({ space: 2 }) {
            Text(this.toolLabel(tool))
              .fontSize(Typography.caption)
              .fontColor(this.uiColors.textPrimary)
              .width('100%')
            Text((tool.description as string) ?? '')
              .fontSize(Typography.micro)
              .fontColor(this.uiColors.textTertiary)
              .width('100%')
              .maxLines(2)
          }
          .width('100%')
          .padding(Spacing.sm)
          .backgroundColor(this.uiColors.bgSurface)
          .borderRadius(Radius.sm)
          .attributeModifier(new SurfaceStyle(this.uiColors, Radius.sm))
        }, (tool: ESObject) => ((tool.id as string) ?? 'tool'))
      }
    }
    .width('100%')
  }

  @Builder
  runsTab() {
    Column({ space: Spacing.md }) {
      Row({ space: Spacing.sm }) {
        Button('清理旧运行…', { type: ButtonType.Normal })
          .fontSize(UIType.caption)
          .constraintSize({ minHeight: 44 })
          .layoutWeight(1)
          .backgroundColor(this.uiColors.bgSurfaceHigh)
          .fontColor(this.uiColors.textSecondary)
          .enabled(!this.busy)
          .onClick(() => {
            this.planPrune();
          })
      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
      .width('100%')

      if (this.planText !== '') {
        Column({ space: 6 }) {
          Text(this.planText)
            .fontSize(Typography.caption)
            .fontColor(this.uiColors.textSecondary)
            .width('100%')
          Row({ space: Spacing.sm }) {
            Button('执行清理', { type: ButtonType.Normal })
              .fontSize(UIType.caption)
              .constraintSize({ minHeight: 44 })
              .layoutWeight(1)
              .backgroundColor(this.uiColors.danger)
              .enabled(!this.busy)
              .onClick(() => {
                this.applyPrune();
              })
            .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Danger))
      Button('取消', { type: ButtonType.Normal })
              .fontSize(UIType.caption)
              .constraintSize({ minHeight: 44 })
              .backgroundColor(this.uiColors.bgSurfaceHigh)
              .onClick(() => {
                this.planText = '';
                this.pruning = false;
              })
          .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
          .width('100%')
        }
        .width('100%')
        .padding(Spacing.md)
        .borderRadius(GLASS_CARD.radius)
        .backgroundColor(this.uiColors.bgSurface)
        .border({ width: 1, color: this.uiColors.borderSubtle })
      }

      if (this.runs.length === 0) {
        EmptyHint('还没有 Agent 运行记录', '在聊天页让 Agent 跑一次就会出现', this.uiColors)
      } else {
        ForEach(this.runs, (run: AgentRunSummaryDto) => {
          Column({ space: Spacing.sm }) {
            Row({ space: Spacing.sm }) {
              Text(run.runId.substring(0, Math.min(14, run.runId.length)))
                .fontSize(Typography.caption)
                .fontColor(this.uiColors.textPrimary)
                .layoutWeight(1)
                .maxLines(1)
              Text(run.status)
                .fontSize(Typography.micro)
                .fontColor(this.statusColor(run.status))
            }
            .width('100%')

            Text(`${run.generationType} · ${run.commitCount} 次提交 · ${run.createdAt}`)
              .fontSize(Typography.micro)
              .fontColor(this.uiColors.textTertiary)
              .width('100%')
              .maxLines(1)

            Row({ space: Spacing.sm }) {
              Button(this.selectedRun === run.runId ? '收起事件' : '查看事件', { type: ButtonType.Normal })
                .fontSize(UIType.caption)
                .constraintSize({ minHeight: 44 })
                .layoutWeight(1)
                .onClick(() => {
                  if (this.selectedRun === run.runId) {
                    this.selectedRun = '';
                    this.events = [];
                  } else {
                    this.openRun(run);
                  }
                })
              .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      if (run.status === 'running' || run.status === 'pending') {
                Button('取消', { type: ButtonType.Normal })
                  .fontSize(UIType.caption)
                  .constraintSize({ minHeight: 44 })
                  .backgroundColor(this.uiColors.danger)
                  .enabled(!this.busy)
                  .onClick(() => {
                    this.cancelRun(run);
                  })
              .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Danger))
      }
            }
            .width('100%')

            if (this.selectedRun === run.runId) {
              Divider().color(this.uiColors.borderSubtle)
              Text(this.eventsNote)
                .fontSize(Typography.micro)
                .fontColor(this.uiColors.textTertiary)
                .width('100%')
              ForEach(this.events, (event: AgentRunEventDto) => {
                Column({ space: 2 }) {
                  Row({ space: 6 }) {
                    Text(`#${event.seq}`)
                      .fontSize(Typography.micro)
                      .fontColor(this.uiColors.textTertiary)
                    Text(event.type)
                      .fontSize(Typography.micro)
                      .fontColor(this.levelColor(event.level))
                      .layoutWeight(1)
                      .maxLines(1)
                  }
                  .width('100%')
                  Text(this.payloadSnippet(event))
                    .fontSize(Typography.micro)
                    .fontColor(this.uiColors.textSecondary)
                    .width('100%')
                    .maxLines(3)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .width('100%')
                .padding({ top: 3, bottom: 3 })
              }, (event: AgentRunEventDto) => `${event.runId}|${event.seq}`)
            }
          }
          .width('100%')
          .padding(Spacing.md)
          .borderRadius(GLASS_CARD.radius)
          .backgroundColor(this.uiColors.bgSurface)
          .border({ width: 1, color: this.uiColors.borderSubtle })
        }, (run: AgentRunSummaryDto) => `${run.runId}|${run.status}`)
      }
    }
    .width('100%')
  }

  @Builder
  profilesTab() {
    Column({ space: Spacing.md }) {
      Text(this.profileNote)
        .fontSize(Typography.micro)
        .fontColor(this.uiColors.textTertiary)
        .width('100%')
      if (this.profiles.length === 0) {
        EmptyHint('没有 Agent 配置档', '原项目在 Agent 面板里新建；这里只做只读+诊断', this.uiColors)
      } else {
        ForEach(this.profiles, (profile: ESObject) => {
          Column({ space: 6 }) {
            Text(String(profile.displayName))
              .fontSize(Typography.subtitle)
              .fontColor(this.uiColors.textPrimary)
              .width('100%')
              .maxLines(1)
            Text(String(profile.id))
              .fontSize(Typography.micro)
              .fontColor(this.uiColors.textTertiary)
              .width('100%')
              .maxLines(1)
            Row({ space: Spacing.sm }) {
              Button('诊断', { type: ButtonType.Normal })
                .fontSize(UIType.caption)
                .constraintSize({ minHeight: 44 })
                .layoutWeight(1)
                .enabled(!this.busy)
                .onClick(() => {
                  this.diagnose(profile);
                })
            .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
            .width('100%')
          }
          .width('100%')
          .padding(Spacing.md)
          .borderRadius(GLASS_CARD.radius)
          .backgroundColor(this.uiColors.bgSurface)
          .border({ width: 1, color: this.uiColors.borderSubtle })
        }, (profile: ESObject) => String(profile.id))
      }
    }
    .width('100%')
  }

  statusColor(status: string): ResourceColor {
    if (status === 'running') {
      return this.uiColors.accent;
    }
    if (status === 'failed' || status === 'cancelled') {
      return this.uiColors.danger;
    }
    return this.uiColors.textTertiary;
  }

  levelColor(level: string): ResourceColor {
    if (level === 'error') {
      return this.uiColors.danger;
    }
    if (level === 'warn') {
      return this.uiColors.warning;
    }
    return this.uiColors.textSecondary;
  }

  payloadSnippet(event: AgentRunEventDto): string {
    if (event.payload === undefined || event.payload === null) {
      return '（无数据）';
    }
    const text: string = JSON.stringify(event.payload);
    if (text === undefined || text === null) {
      return '（无数据）';
    }
    return text.substring(0, Math.min(200, text.length));
  }
}
