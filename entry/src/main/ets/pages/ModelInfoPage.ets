import { SurfaceStyle } from '../theme/SurfaceStyles';
import { ActionButtonStyle, ActionTone, InputFieldStyle } from '../theme/ControlStyles';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { PageSurface } from '../components/PageSurface';
import { Radius as UIRadius, Typography as UIType } from '../theme/Tokens';
import { PageHeader } from '../components/PageHeader';
// 模型与联网（P8-24）：余额查询 / 嵌入模型目录 / SearXNG 搜索测试。
//
// 对应 DevEco 工程路径：entry/src/main/ets/pages/ModelInfoPage.ets
//
// 这些都是「已经包好了后端、但一直没人调用」的命令，共 6 条：
//   get_openrouter_credits / get_nanogpt_credits
//   get_siliconflow_embedding_models / get_workers_ai_embedding_models / get_workers_ai_multimodal_models
//   search_searxng
//
// 余额和模型目录依赖已保存的 API key（密钥页写入），SearXNG 需要先填实例地址。
import { Backend, BackendError } from '../backend/Backend';
import {
  ProviderModelProvidersRequestDto,
  SearxngSearchRequestDto,
  SiliconFlowEmbeddingModelsRequestDto,
  WorkersAiModelsRequestDto
} from '../backend/Types';
import { ROOT_PATH_STACK } from '../nav/RootNav';
import { Radius, Spacing, Touch, Typography } from '../theme/Tokens';
import { GLASS_HEADER, glassEffect } from '../theme/Glass';
import { EmptyHint, ErrorBannerView } from '../components/Builders';

@Component
export struct ModelInfoPage {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @State busy: boolean = false;
  @State errorText: string = '';
  @State statusText: string = '';

  @State openrouterCredits: string = '';
  @State nanogptCredits: string = '';

  @State siliconflowEndpoint: string = '';
  @State workersAccountId: string = '';
  @State embeddingModels: string[] = [];
  @State embeddingNote: string = '';

  @State searxngBaseUrl: string = '';
  @State searxngQuery: string = '';
  @State searxngResult: string = '';

  aboutToAppear(): void {
    if (!Backend.isReady()) {
      this.errorText = '后端未就绪，请从首页进入';
    }
  }

  /** 余额接口返回结构不稳定（上游会改字段），所以直接展示格式化后的 JSON 关键字段。 */
  async loadCredits(): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      const openrouter: ESObject = await Backend.getOpenrouterCredits();
      this.openrouterCredits = ModelInfoPage.describeCredits(openrouter);
      const nanogpt: ESObject = await Backend.getNanogptCredits();
      this.nanogptCredits = ModelInfoPage.describeCredits(nanogpt);
      this.statusText = '余额已刷新';
    } catch (err) {
      const message: string = (err as BackendError).message;
      this.errorText = `查余额失败：${message}`;
      this.statusText = `查余额失败：${message}`;
    } finally {
      this.busy = false;
    }
  }

  static describeCredits(value: ESObject): string {
    if (value === undefined || value === null) {
      return '（无数据）';
    }
    const keys: string[] = Object.keys(value);
    if (keys.length === 0) {
      return JSON.stringify(value);
    }
    const parts: string[] = [];
    for (let i = 0; i < keys.length; i++) {
      const key: string = keys[i];
      const raw: ESObject = value[key] as ESObject;
      if (raw === undefined || raw === null) {
        continue;
      }
      if (typeof raw === 'object') {
        parts.push(`${key}: ${JSON.stringify(raw)}`);
      } else {
        parts.push(`${key}: ${raw}`);
      }
    }
    return parts.join('\n');
  }

  async loadSiliconflowModels(): Promise<void> {
    if (this.siliconflowEndpoint.trim() === '') {
      this.errorText = '先填 SiliconFlow endpoint';
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      const dto: SiliconFlowEmbeddingModelsRequestDto = {
        siliconflow_endpoint: this.siliconflowEndpoint.trim()
      };
      const result: ESObject = await Backend.getSiliconflowEmbeddingModels(dto);
      this.embeddingModels = ModelInfoPage.pickModels(result, 'siliconflow');
      this.embeddingNote = `SiliconFlow：${this.embeddingModels.length} 个嵌入模型`;
    } catch (err) {
      const message: string = (err as BackendError).message;
      this.errorText = `取嵌入模型失败：${message}`;
      this.statusText = `取嵌入模型失败：${message}`;
    } finally {
      this.busy = false;
    }
  }

  async loadWorkersModels(): Promise<void> {
    if (this.workersAccountId.trim() === '') {
      this.errorText = '先填 Cloudflare account id';
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      const dto: WorkersAiModelsRequestDto = {
        workers_ai_account_id: this.workersAccountId.trim()
      };
      const embed: ESObject = await Backend.getWorkersAiEmbeddingModels(dto);
      const multi: ESObject = await Backend.getWorkersAiMultimodalModels(dto);
      const models: string[] = ModelInfoPage.pickModels(embed, 'workers-embed');
      const multiModels: string[] = ModelInfoPage.pickModels(multi, 'workers-multi');
      this.embeddingModels = models.concat(multiModels);
      this.embeddingNote = `Workers AI：${models.length} 个嵌入 + ${multiModels.length} 个多模态`;
    } catch (err) {
      const message: string = (err as BackendError).message;
      this.errorText = `Workers AI 失败：${message}`;
      this.statusText = `Workers AI 失败：${message}`;
    } finally {
      this.busy = false;
    }
  }

  /** 响应可能是 {data:[{id}]} / {models:[{name}]} / string[]，都摊平成 id 列表。 */
  static pickModels(value: ESObject, tag: string): string[] {
    const out: string[] = [];
    if (value === undefined || value === null) {
      return out;
    }
    const list: ESObject[] = (value.data as ESObject[]) ?? (value.models as ESObject[]) ?? (value as ESObject[]);
    if (list === undefined || list === null || list.length === undefined) {
      return out;
    }
    for (let i = 0; i < list.length; i++) {
      const item: ESObject = list[i];
      if (item === undefined || item === null) {
        continue;
      }
      const id: string = (item.id as string) ?? (item.name as string) ?? `${item}`;
      out.push(id);
    }
    return out;
  }

  async runSearxng(): Promise<void> {
    if (this.searxngBaseUrl.trim() === '' || this.searxngQuery.trim() === '') {
      this.errorText = 'SearXNG 需要实例地址 + 查询词';
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      const dto: SearxngSearchRequestDto = {
        baseUrl: this.searxngBaseUrl.trim(),
        query: this.searxngQuery.trim()
      };
      const result: string = await Backend.searchSearxng(dto, 'zh-CN');
      this.searxngResult = result;
      this.statusText = `SearXNG 返回 ${result.length} 字符`;
    } catch (err) {
      const message: string = (err as BackendError).message;
      if (message.startsWith('endpoint_authorization_required|')) {
        const endpoint: string = message.split('|')[1];
        this.errorText = `端点需要授权：${endpoint}（去「应用设置」里授权后重试）`;
      } else {
        this.errorText = `搜索失败：${message}`;
      }
    } finally {
      this.busy = false;
    }
  }

  @Builder
  pageTopBar() {
    PageHeader({
        title: '模型与联网',
        subtitle: '模型目录、余额与连接',
        onBack: () => {
            ROOT_PATH_STACK.pop();
        }
      }) {

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
            .padding({ left: Spacing.md, right: Spacing.md })
            .maxLines(2)
        }
        ErrorBannerView({ text: this.errorText })
  
        Column() {
          Column({ space: Spacing.lg }) {
            // ---- 余额 ----
            Column({ space: Spacing.sm }) {
              Text('账户余额')
                .fontSize(Typography.caption)
                .fontColor(this.uiColors.textSecondary)
                .width('100%')
              Button('查询 OpenRouter / NanoGPT 余额', { type: ButtonType.Normal })
                .fontSize(Typography.caption)
                .height(Touch.minTarget)
                .width('100%')
                .enabled(!this.busy)
                .onClick(() => {
                  this.loadCredits();
                })
              .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      if (this.openrouterCredits !== '') {
                Text(`OpenRouter\n${this.openrouterCredits}`)
                  .fontSize(Typography.micro)
                  .fontColor(this.uiColors.textPrimary)
                  .width('100%')
              }
              if (this.nanogptCredits !== '') {
                Text(`NanoGPT\n${this.nanogptCredits}`)
                  .fontSize(Typography.micro)
                  .fontColor(this.uiColors.textPrimary)
                  .width('100%')
              }
            }
            .width('100%')
            .padding(Spacing.md)
            .backgroundColor(this.uiColors.bgSurface)
            .borderRadius(Radius.md)
            .attributeModifier(new SurfaceStyle(this.uiColors, Radius.md))
  
            // ---- 嵌入/多模态模型 ----
            Column({ space: Spacing.sm }) {
              Text('向量模型目录')
                .fontSize(Typography.caption)
                .fontColor(this.uiColors.textSecondary)
                .width('100%')
              Text('填 SiliconFlow 的 endpoint 或 Cloudflare account id，拉取该账户可用的嵌入模型（向量记忆库要用）。')
                .fontSize(Typography.micro)
                .fontColor(this.uiColors.textTertiary)
                .width('100%')
              TextInput({ placeholder: 'SiliconFlow endpoint', text: this.siliconflowEndpoint })
                .fontColor(this.uiColors.textPrimary)
                .placeholderColor(this.uiColors.textTertiary)
                .backgroundColor(this.uiColors.bgSurfaceHigh)
                .borderRadius(UIRadius.sm)
                .fontSize(Typography.caption)
                .height(Touch.minTarget)
                .width('100%')
                .backgroundColor(this.uiColors.bgSurfaceHigh)
                .onChange((value: string) => {
                  this.siliconflowEndpoint = value;
                })
              .attributeModifier(new InputFieldStyle(this.uiColors))
      Button('拉取 SiliconFlow 嵌入模型', { type: ButtonType.Normal })
                .fontSize(Typography.caption)
                .height(Touch.minTarget)
                .width('100%')
                .enabled(!this.busy)
                .onClick(() => {
                  this.loadSiliconflowModels();
                })
              .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      TextInput({ placeholder: 'Cloudflare Workers AI account id', text: this.workersAccountId })
                .fontColor(this.uiColors.textPrimary)
                .placeholderColor(this.uiColors.textTertiary)
                .backgroundColor(this.uiColors.bgSurfaceHigh)
                .borderRadius(UIRadius.sm)
                .fontSize(Typography.caption)
                .height(Touch.minTarget)
                .width('100%')
                .backgroundColor(this.uiColors.bgSurfaceHigh)
                .onChange((value: string) => {
                  this.workersAccountId = value;
                })
              .attributeModifier(new InputFieldStyle(this.uiColors))
      Button('拉取 Workers AI 模型', { type: ButtonType.Normal })
                .fontSize(Typography.caption)
                .height(Touch.minTarget)
                .width('100%')
                .enabled(!this.busy)
                .onClick(() => {
                  this.loadWorkersModels();
                })
              .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      if (this.embeddingNote !== '') {
                Text(this.embeddingNote)
                  .fontSize(Typography.micro)
                  .fontColor(this.uiColors.accent)
                  .width('100%')
              }
              ForEach(this.embeddingModels, (model: string) => {
                Text(`· ${model}`)
                  .fontSize(Typography.micro)
                  .fontColor(this.uiColors.textSecondary)
                  .width('100%')
              }, (model: string) => model)
            }
            .width('100%')
            .padding(Spacing.md)
            .backgroundColor(this.uiColors.bgSurface)
            .borderRadius(Radius.md)
            .attributeModifier(new SurfaceStyle(this.uiColors, Radius.md))
  
            // ---- SearXNG ----
            Column({ space: Spacing.sm }) {
              Text('联网搜索（SearXNG）')
                .fontSize(Typography.caption)
                .fontColor(this.uiColors.textSecondary)
                .width('100%')
              Text('角色在聊天里「搜网页」走的就是这条链路。填自己的 SearXNG 实例地址做连通性测试。')
                .fontSize(Typography.micro)
                .fontColor(this.uiColors.textTertiary)
                .width('100%')
              TextInput({ placeholder: 'https://searx.example.com', text: this.searxngBaseUrl })
                .fontColor(this.uiColors.textPrimary)
                .placeholderColor(this.uiColors.textTertiary)
                .backgroundColor(this.uiColors.bgSurfaceHigh)
                .borderRadius(UIRadius.sm)
                .fontSize(Typography.caption)
                .height(Touch.minTarget)
                .width('100%')
                .backgroundColor(this.uiColors.bgSurfaceHigh)
                .onChange((value: string) => {
                  this.searxngBaseUrl = value;
                })
              .attributeModifier(new InputFieldStyle(this.uiColors))
      TextInput({ placeholder: '查询词', text: this.searxngQuery })
                .fontColor(this.uiColors.textPrimary)
                .placeholderColor(this.uiColors.textTertiary)
                .backgroundColor(this.uiColors.bgSurfaceHigh)
                .borderRadius(UIRadius.sm)
                .fontSize(Typography.caption)
                .height(Touch.minTarget)
                .width('100%')
                .backgroundColor(this.uiColors.bgSurfaceHigh)
                .onChange((value: string) => {
                  this.searxngQuery = value;
                })
              .attributeModifier(new InputFieldStyle(this.uiColors))
      Button('测试搜索', { type: ButtonType.Normal })
                .fontSize(Typography.caption)
                .height(Touch.minTarget)
                .width('100%')
                .enabled(!this.busy)
                .onClick(() => {
                  this.runSearxng();
                })
              .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      if (this.searxngResult !== '') {
                Text(this.searxngResult)
                  .fontSize(Typography.micro)
                  .fontColor(this.uiColors.textPrimary)
                  .width('100%')
                  .maxLines(14)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              } else {
                EmptyHint('还没搜索过', '填实例地址和查询词，点「测试搜索」看能不能拿到结果', this.uiColors)
              }
            }
            .width('100%')
            .padding(Spacing.md)
            .backgroundColor(this.uiColors.bgSurface)
            .borderRadius(Radius.md)
            .attributeModifier(new SurfaceStyle(this.uiColors, Radius.md))
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

  build() {
    PageSurface({ topBar: () => { this.pageTopBar(); }, content: () => { this.buildSurfaceContent(); } })
  }
}
