import { ActionButtonStyle, ActionTone, InputFieldStyle, TextAreaFieldStyle } from '../theme/ControlStyles';
import { HeaderAction } from '../components/HeaderAction';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { PageSurface } from '../components/PageSurface';
import { Radius as UIRadius, Typography as UIType } from '../theme/Tokens';
import { PageHeader } from '../components/PageHeader';
// MCP 管理器（P8-6）：对应原项目 src/scripts/extensions/mcp-manager。
//
// 原面板能力：服务器列表 / 添加 / 编辑 / 启用停用 / 删除 / 发现工具 /
// 工具权限（off→ask→allow）/ 工具试调（填 JSON 参数看结果）。
// 这里逐项搬过来，全部走真实后端命令，不做假数据。
//
// 对应 DevEco 工程路径：entry/src/main/ets/pages/McpPage.ets
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Backend, BackendError } from '../backend/Backend';
import {
  CreateMcpServerDto,
  ListMcpServersResultDto,
  McpCallOutcomeDto,
  McpDiscoveryResultDto,
  McpServerDto,
  McpToolDto,
  TestMcpToolCallDto,
  UpdateMcpServerDto
} from '../backend/Types';
import { ROOT_PATH_STACK } from '../nav/RootNav';
import { Radius, Spacing, Typography } from '../theme/Tokens';
import { GLASS_CARD, GLASS_HEADER, glassEffect } from '../theme/Glass';
import { EmptyHint, ErrorBannerView, SectionTitle } from '../components/Builders';

const DOMAIN: number = 0x0004;
const TAG: string = 'HarmonyTavern';
const PROTOCOLS: string[] = ['auto', '2026-07-28', '2025-11-25', '2025-06-18', '2025-03-26'];

@Component
export struct McpPage {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @State loading: boolean = true;
  @State busy: boolean = false;
  @State errorText: string = '';
  @State statusText: string = '';
  @State servers: McpServerDto[] = [];

  // 表单：'list' | 'create' | 'edit'
  @State mode: string = 'list';
  @State editingId: string = '';
  @State formName: string = '';
  @State formEndpoint: string = '';
  @State formProtocol: string = 'auto';
  @State formHeaders: string = '';

  // 工具面板
  @State toolsFor: string = '';
  @State tools: McpToolDto[] = [];
  @State toolsNote: string = '';
  @State staleCount: number = 0;

  // 试调
  @State testTarget: string = '';
  @State testArgs: string = '{}';
  @State testResult: string = '';

  // 删除确认
  @State deletingId: string = '';

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
      const result: ListMcpServersResultDto = await Backend.listMcpServers();
      this.servers = result.servers;
      if (result.storageIssues.length > 0) {
        this.errorText = `存储告警：${result.storageIssues[0].message}`;
      }
    } catch (err) {
      this.errorText = `读取 MCP 服务器失败：${(err as BackendError).message}`;
    } finally {
      this.loading = false;
    }
  }

  openCreate(): void {
    this.mode = 'create';
    this.editingId = '';
    this.formName = '';
    this.formEndpoint = '';
    this.formProtocol = 'auto';
    this.formHeaders = '';
    this.statusText = '';
    this.errorText = '';
  }

  openEdit(server: McpServerDto): void {
    this.mode = 'edit';
    this.editingId = server.id;
    this.formName = server.displayName;
    this.formEndpoint = server.endpoint;
    this.formProtocol = server.protocolVersion;
    this.formHeaders = this.headersToText(server.headers);
    this.errorText = '';
  }

  headersToText(headers: Record<string, string>): string {
    const keys: string[] = Object.keys(headers);
    const lines: string[] = [];
    for (let i = 0; i < keys.length; i++) {
      lines.push(`${keys[i]}: ${headers[keys[i]]}`);
    }
    return lines.join('\n');
  }

  textToHeaders(text: string): Record<string, string> {
    const result: Record<string, string> = {};
    const lines: string[] = text.split('\n');
    for (let i = 0; i < lines.length; i++) {
      const line: string = lines[i].trim();
      if (line === '') {
        continue;
      }
      const index: number = line.indexOf(':');
      if (index <= 0) {
        continue;
      }
      const key: string = line.substring(0, index).trim();
      const value: string = line.substring(index + 1).trim();
      if (key !== '') {
        result[key] = value;
      }
    }
    return result;
  }

  async save(): Promise<void> {
    const name: string = this.formName.trim();
    const endpoint: string = this.formEndpoint.trim();
    if (name === '' || endpoint === '') {
      this.errorText = '名称与 endpoint 都不能为空';
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      if (this.mode === 'create') {
        const dto: CreateMcpServerDto = {
          displayName: name,
          endpoint: endpoint,
          headers: this.textToHeaders(this.formHeaders),
          protocolVersion: this.formProtocol
        };
        await Backend.createMcpServer(dto);
        this.statusText = `已添加：${name}`;
      } else {
        const dto: UpdateMcpServerDto = {
          registrationId: this.editingId,
          displayName: name,
          endpoint: endpoint,
          headers: this.textToHeaders(this.formHeaders),
          protocolVersion: this.formProtocol
        };
        await Backend.updateMcpServer(dto);
        this.statusText = `已更新：${name}`;
      }
      this.mode = 'list';
      await this.reload();
    } catch (err) {
      this.errorText = `保存失败：${(err as BackendError).message}`;
      hilog.error(DOMAIN, TAG, 'mcp save failed: %{public}s', this.errorText);
    } finally {
      this.busy = false;
    }
  }

  async toggleState(server: McpServerDto): Promise<void> {
    this.busy = true;
    this.errorText = '';
    const next: string = server.state === 'active' ? 'paused' : 'active';
    try {
      await Backend.setMcpServerState({ registrationId: server.id, state: next });
      this.statusText = `${server.displayName} → ${next === 'active' ? '启用' : '停用'}`;
      await this.reload();
    } catch (err) {
      this.errorText = `切换状态失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async doRemove(): Promise<void> {
    if (this.deletingId === '') {
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      await Backend.removeMcpServer({ registrationId: this.deletingId });
      this.deletingId = '';
      this.toolsFor = '';
      this.tools = [];
      this.statusText = '已删除服务器';
      await this.reload();
    } catch (err) {
      this.errorText = `删除失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async discoverTools(server: McpServerDto): Promise<void> {
    this.busy = true;
    this.errorText = '';
    this.toolsNote = `正在连接 ${server.endpoint} …`;
    this.toolsFor = server.id;
    this.tools = [];
    try {
      const result: McpDiscoveryResultDto = await Backend.discoverMcpTools({ registrationId: server.id });
      this.tools = result.tools;
      this.staleCount = result.staleTools.length;
      const version: string = result.serverName !== undefined && result.serverName !== null
        ? `${result.serverName} ${result.serverVersion ?? ''}`
        : result.protocolVersion;
      this.toolsNote = this.tools.length > 0
        ? `已连接 ${version}：${this.tools.length} 个工具`
        : `已连接 ${version}：该服务器没有暴露工具`;
      if (result.diagnostics.length > 0) {
        this.errorText = `诊断：${result.diagnostics[0].message}`;
      }
    } catch (err) {
      this.toolsNote = '';
      this.errorText = `发现工具失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async cyclePermission(tool: McpToolDto): Promise<void> {
    const order: string[] = ['off', 'ask', 'allow'];
    const current: number = order.indexOf(tool.permission);
    const next: string = order[(current + 1) % order.length];
    this.busy = true;
    try {
      await Backend.setMcpToolPermission({
        registrationId: this.toolsFor,
        nativeName: tool.nativeName,
        permission: next
      });
      const refreshed: McpToolDto[] = [];
      for (let i = 0; i < this.tools.length; i++) {
        const item: McpToolDto = this.tools[i];
        if (item.nativeName === tool.nativeName) {
          item.permission = next;
        }
        refreshed.push(item);
      }
      this.tools = refreshed;
      this.statusText = `${tool.nativeName} 权限 → ${next}`;
    } catch (err) {
      this.errorText = `设置权限失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async runTest(): Promise<void> {
    if (this.testTarget === '') {
      return;
    }
    this.busy = true;
    this.errorText = '';
    this.testResult = '调用中…';
    try {
      const dto: TestMcpToolCallDto = {
        callId: `test-${Date.now()}`,
        registrationId: this.toolsFor,
        nativeName: this.testTarget,
        argumentsJson: this.testArgs.trim() === '' ? '{}' : this.testArgs
      };
      const outcome: McpCallOutcomeDto = await Backend.testMcpToolCall(dto);
      this.testResult = this.describeOutcome(outcome);
    } catch (err) {
      this.testResult = '';
      this.errorText = `试调失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  /** 把 McpCallOutcomeDto 压成一段可读文本（原面板也是"结果 + 诊断"两段）。 */
  describeOutcome(outcome: McpCallOutcomeDto): string {
    const parts: string[] = [];
    parts.push(`结果：${outcome.outcome}`);
    if (outcome.code !== undefined && outcome.code !== null) {
      parts.push(`错误码：${outcome.code}`);
    }
    if (outcome.message !== undefined && outcome.message !== null) {
      parts.push(`消息：${outcome.message}`);
    }
    const response: ESObject = outcome.response as ESObject;
    if (response !== undefined && response !== null) {
      const blocks: ESObject = response.textBlocks as ESObject;
      if (blocks !== undefined && blocks !== null && Array.isArray(blocks)) {
        const texts: string[] = [];
        for (let i = 0; i < (blocks as ESObject[]).length; i++) {
          const block: ESObject = (blocks as ESObject[])[i] as ESObject;
          const text: ESObject = block.text as ESObject;
          if (text !== undefined && text !== null) {
            texts.push(String(text));
          }
        }
        if (texts.length > 0) {
          parts.push(`返回文本：\n${texts.join('\n')}`);
        }
      }
      const structured: ESObject = response.structuredJson as ESObject;
      if (structured !== undefined && structured !== null) {
        parts.push(`结构化结果：\n${String(structured)}`);
      }
    }
    return parts.join('\n');
  }

  @Builder
  pageTopBar() {
    PageHeader({
        title: 'MCP 服务器',
        subtitle: '连接你的工具与服务',
        onBack: () => {
            ROOT_PATH_STACK.pop();
        }
      }) {
        HeaderAction({ label: '刷新', marker: 'mcppage-refresh-1', available: !this.busy,
          pending: this.loading,
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
  
        Column() {
          Column({ space: Spacing.md }) {
            if (this.mode === 'list') {
              Row({ space: Spacing.sm }) {
                Button('＋ 添加服务器', { type: ButtonType.Normal })
                  .fontSize(Typography.caption)
                  .constraintSize({ minHeight: 44 })
                  .layoutWeight(1)
                  .onClick(() => {
                    this.openCreate();
                  })
              .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
              .width('100%')
  
              if (this.loading) {
                Text('读取中…').fontSize(Typography.caption).fontColor(this.uiColors.textTertiary)
              } else if (this.servers.length === 0) {
                EmptyHint('还没有 MCP 服务器', '添加一个 SSE / HTTP endpoint 试试', this.uiColors)
              } else {
                ForEach(this.servers, (server: McpServerDto) => {
                  this.serverCard(server)
                }, (server: McpServerDto) => `${server.id}|${server.state}`)
              }
  
              if (this.toolsFor !== '') {
                this.toolsPanel()
              }
            } else {
              this.formPanel()
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

  @Builder
  serverCard(server: McpServerDto) {
    Column({ space: Spacing.sm }) {
      Row({ space: Spacing.sm }) {
        Text(server.displayName)
          .fontSize(Typography.subtitle)
          .fontColor(this.uiColors.textPrimary)
          .layoutWeight(1)
          .maxLines(1)
        Text(server.state === 'active' ? '启用' : '停用')
          .fontSize(Typography.micro)
          .fontColor(server.state === 'active' ? this.uiColors.accent : this.uiColors.textTertiary)
      }
      .width('100%')

      Text(server.endpoint)
        .fontSize(Typography.caption)
        .fontColor(this.uiColors.textSecondary)
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(`协议 ${server.protocolVersion} · 已配置权限 ${Object.keys(server.toolPermissions).length} 个工具`)
        .fontSize(Typography.micro)
        .fontColor(this.uiColors.textTertiary)
        .width('100%')

      Row({ space: Spacing.sm }) {
        Button('发现工具', { type: ButtonType.Normal })
          .fontSize(UIType.caption)
          .constraintSize({ minHeight: 44 })
          .layoutWeight(1)
          .enabled(!this.busy)
          .onClick(() => {
            this.discoverTools(server);
          })
        .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button('编辑', { type: ButtonType.Normal })
          .fontSize(UIType.caption)
          .constraintSize({ minHeight: 44 })
          .backgroundColor(this.uiColors.bgSurfaceHigh)
          .fontColor(this.uiColors.textSecondary)
          .onClick(() => {
            this.openEdit(server);
          })
        .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button(server.state === 'active' ? '停用' : '启用', { type: ButtonType.Normal })
          .fontSize(UIType.caption)
          .constraintSize({ minHeight: 44 })
          .backgroundColor(this.uiColors.bgSurfaceHigh)
          .fontColor(this.uiColors.textSecondary)
          .enabled(!this.busy)
          .onClick(() => {
            this.toggleState(server);
          })
        .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button('删除', { type: ButtonType.Normal })
          .fontSize(UIType.caption)
          .constraintSize({ minHeight: 44 })
          .backgroundColor(this.uiColors.danger)
          .onClick(() => {
            this.deletingId = server.id;
          })
      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Danger))
      }
      .width('100%')

      if (this.deletingId === server.id) {
        Row({ space: Spacing.sm }) {
          Text('确认删除？')
            .fontSize(Typography.caption)
            .fontColor(this.uiColors.textSecondary)
            .layoutWeight(1)
          Button('确认', { type: ButtonType.Normal })
            .fontSize(UIType.caption)
            .constraintSize({ minHeight: 44 })
            .backgroundColor(this.uiColors.danger)
            .enabled(!this.busy)
            .onClick(() => {
              this.doRemove();
            })
          .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Danger))
      Button('取消', { type: ButtonType.Normal })
            .fontSize(UIType.caption)
            .constraintSize({ minHeight: 44 })
            .backgroundColor(this.uiColors.bgSurfaceHigh)
            .onClick(() => {
              this.deletingId = '';
            })
        .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
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
  toolsPanel() {
    Column({ space: Spacing.sm }) {
      SectionTitle('工具', this.uiColors)
      if (this.toolsNote !== '') {
        Text(this.toolsNote)
          .fontSize(Typography.caption)
          .fontColor(this.uiColors.textSecondary)
          .width('100%')
      }
      if (this.staleCount > 0) {
        Text(`有 ${this.staleCount} 个旧工具记录已被服务器移除`)
          .fontSize(Typography.micro)
          .fontColor(this.uiColors.textTertiary)
          .width('100%')
      }
      ForEach(this.tools, (tool: McpToolDto) => {
        Column({ space: 4 }) {
          Row({ space: Spacing.sm }) {
            Text(tool.nativeName)
              .fontSize(Typography.caption)
              .fontColor(this.uiColors.textPrimary)
              .layoutWeight(1)
              .maxLines(1)
            Button(tool.permission, { type: ButtonType.Normal })
              .fontSize(UIType.micro)
              .constraintSize({ minHeight: 44 })
              .backgroundColor(tool.permission === 'allow' ? this.uiColors.accent
                : (tool.permission === 'ask' ? this.uiColors.warning : this.uiColors.bgSurfaceHigh))
              .fontColor(tool.permission === 'allow' ? this.uiColors.textInverse : this.uiColors.textSecondary)
              .enabled(!this.busy)
              .onClick(() => {
                this.cyclePermission(tool);
              })
            .attributeModifier(new ActionButtonStyle(this.uiColors, tool.permission === 'allow' ? ActionTone.Selected : (tool.permission === 'ask' ? ActionTone.Warning : ActionTone.Normal)))
      Button('试调', { type: ButtonType.Normal })
              .fontSize(UIType.micro)
              .constraintSize({ minHeight: 44 })
              .backgroundColor(this.uiColors.bgSurfaceHigh)
              .fontColor(this.uiColors.textSecondary)
              .onClick(() => {
                this.testTarget = tool.nativeName;
                this.testResult = '';
                this.testArgs = '{}';
              })
          .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
          .width('100%')

          if (tool.description !== undefined && tool.description !== null) {
            Text(tool.description)
              .fontSize(Typography.micro)
              .fontColor(this.uiColors.textTertiary)
              .width('100%')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }

          if (this.testTarget === tool.nativeName) {
            Column({ space: 4 }) {
              Text('参数 JSON')
                .fontSize(Typography.micro)
                .fontColor(this.uiColors.textTertiary)
                .width('100%')
              TextArea({ text: this.testArgs, placeholder: '{}' })
                .fontColor(this.uiColors.textPrimary)
                .placeholderColor(this.uiColors.textTertiary)
                .backgroundColor(this.uiColors.bgSurfaceHigh)
                .borderRadius(UIRadius.sm)
                .fontSize(Typography.caption)
                .height(88)
                .width('100%')
                .backgroundColor(this.uiColors.bgSurfaceHigh)
                .borderRadius(Radius.sm)
                .onChange((value: string) => {
                  this.testArgs = value;
                })
              .attributeModifier(new TextAreaFieldStyle(this.uiColors))
      Row({ space: Spacing.sm }) {
                Button('调用', { type: ButtonType.Normal })
                  .fontSize(UIType.caption)
                  .constraintSize({ minHeight: 44 })
                  .layoutWeight(1)
                  .enabled(!this.busy)
                  .onClick(() => {
                    this.runTest();
                  })
                .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button('收起', { type: ButtonType.Normal })
                  .fontSize(UIType.caption)
                  .constraintSize({ minHeight: 44 })
                  .backgroundColor(this.uiColors.bgSurfaceHigh)
                  .onClick(() => {
                    this.testTarget = '';
                    this.testResult = '';
                  })
              .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
              .width('100%')
              if (this.testResult !== '') {
                Text(this.testResult)
                  .fontSize(Typography.micro)
                  .fontColor(this.uiColors.textSecondary)
                  .width('100%')
                  .maxLines(12)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
            }
            .width('100%')
            .padding(Spacing.sm)
            .backgroundColor(this.uiColors.bgSurfaceHigh)
            .borderRadius(Radius.sm)
          }
        }
        .width('100%')
        .padding({ top: 6, bottom: 6 })
      }, (tool: McpToolDto) => `${tool.nativeName}|${tool.permission}`)
    }
    .width('100%')
    .padding(Spacing.md)
    .borderRadius(GLASS_CARD.radius)
    .backgroundColor(this.uiColors.bgSurface)
    .border({ width: 1, color: this.uiColors.borderSubtle })
  }

  @Builder
  formPanel() {
    Column({ space: Spacing.sm }) {
      SectionTitle(this.mode === 'create' ? '添加 MCP 服务器' : '编辑 MCP 服务器', this.uiColors)
      this.field('显示名称', this.formName, (value: string) => {
        this.formName = value;
      })
      this.field('Endpoint（SSE / HTTP）', this.formEndpoint, (value: string) => {
        this.formEndpoint = value;
      })
      Text('协议版本')
        .fontSize(Typography.micro)
        .fontColor(this.uiColors.textTertiary)
        .width('100%')
      Row({ space: 6 }) {
        ForEach(PROTOCOLS, (option: string) => {
          Button(option, { type: ButtonType.Normal })
            .fontSize(UIType.micro)
            .constraintSize({ minHeight: 44 })
            .backgroundColor(this.formProtocol === option ? this.uiColors.accent : this.uiColors.bgSurfaceHigh)
            .fontColor(this.formProtocol === option ? this.uiColors.textInverse : this.uiColors.textSecondary)
            .onClick(() => {
              this.formProtocol = option;
            })
        .attributeModifier(new ActionButtonStyle(this.uiColors, (this.formProtocol === option) ? ActionTone.Selected : ActionTone.Normal))
      }, (option: string) => option)
      }
      .width('100%')

      Text('自定义 Header（每行 Key: Value）')
        .fontSize(Typography.micro)
        .fontColor(this.uiColors.textTertiary)
        .width('100%')
      TextArea({ text: this.formHeaders, placeholder: 'Authorization: Bearer xxx' })
        .fontColor(this.uiColors.textPrimary)
        .placeholderColor(this.uiColors.textTertiary)
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(UIRadius.sm)
        .fontSize(Typography.caption)
        .height(88)
        .width('100%')
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(Radius.sm)
        .onChange((value: string) => {
          this.formHeaders = value;
        })

      .attributeModifier(new TextAreaFieldStyle(this.uiColors))
      Row({ space: Spacing.sm }) {
        Button(this.mode === 'create' ? '添加' : '保存', { type: ButtonType.Normal })
          .fontSize(Typography.caption)
          .constraintSize({ minHeight: 44 })
          .layoutWeight(1)
          .enabled(!this.busy)
          .onClick(() => {
            this.save();
          })
        .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      Button('取消', { type: ButtonType.Normal })
          .fontSize(Typography.caption)
          .constraintSize({ minHeight: 44 })
          .backgroundColor(this.uiColors.bgSurfaceHigh)
          .fontColor(this.uiColors.textSecondary)
          .onClick(() => {
            this.mode = 'list';
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

  @Builder
  field(label: string, value: string, onChange: (value: string) => void) {
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
        .onChange((next: string) => {
          onChange(next);
        })
    .attributeModifier(new InputFieldStyle(this.uiColors))
      }
    .width('100%')
  }
}
