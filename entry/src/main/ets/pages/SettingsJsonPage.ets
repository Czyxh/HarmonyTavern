import { ActionButtonStyle, ActionTone, TextAreaFieldStyle } from '../theme/ControlStyles';
import { HeaderAction } from '../components/HeaderAction';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { PageSurface } from '../components/PageSurface';
import { Radius as UIRadius, Typography as UIType } from '../theme/Tokens';
import { PageHeader } from '../components/PageHeader';
// SillyTavern 设置 JSON 编辑（P8-19）：人设文本 / 提示词 / 任意 settings.json 字段。
//
// 背景：原项目里 ST 的「人设 / 提示词 / 世界书」都是直接改 settings.json 的字段。
// TauriTavern 的 Rust 核心不提供"改某一项设置"的细粒度命令，只提供**整份设置的分块提交协议**：
//   begin_settings_commit → append_settings_commit_chunk(offset, base64) × N → finish_settings_commit(expectedSize)
// 所以这里做成"读整份 JSON → 编辑 → 分块写回"的通用编辑器，人设只是其中的快捷入口。
//
// 快捷人设：路径 power_user.persona_description（SillyTavern 用户人设正文）。
//
// 对应 DevEco 工程路径：entry/src/main/ets/pages/SettingsJsonPage.ets
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Backend, BackendError, CommitBeginDto, UserSettingsSaveResultDto, UserSettingsRevisionShape } from '../backend/Backend';
import { ROOT_PATH_STACK } from '../nav/RootNav';
import { Radius, Spacing, Touch, Typography } from '../theme/Tokens';
import { GLASS_CARD, GLASS_HEADER, glassEffect } from '../theme/Glass';
import { EmptyHint, ErrorBannerView, SectionTitle } from '../components/Builders';

const DOMAIN: number = 0x0004;
const TAG: string = 'HarmonyTavern';
/** 单块大小：协议给了 max_frame_bytes，这里再保守一点。 */
const CHUNK_BYTES: number = 128 * 1024;


@Component
export struct SettingsJsonPage {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @State loading: boolean = true;
  @State busy: boolean = false;
  @State errorText: string = '';
  @State statusText: string = '';

  private revision: UserSettingsRevisionShape | undefined = undefined;
  @State rawJson: string = '';
  @State originalJson: string = '';
  @State personaText: string = '';
  @State personaLoaded: boolean = false;
  @State sizeText: string = '';
  @State topKeys: string = '';

  aboutToAppear(): void {
    if (!Backend.isReady()) {
      this.errorText = '后端未就绪，请从首页进入';
      this.loading = false;
      return;
    }
    this.load();
  }

  async load(): Promise<void> {
    this.loading = true;
    this.errorText = '';
    try {
      const aggregate: ESObject = await Backend.getSillyTavernSettings();
      this.revision = aggregate.tauritavern_settings_revision as UserSettingsRevisionShape;
      // get_sillytavern_settings 返回的是 SillyTavern /api/settings/get 的聚合结构：
      //   { settings: "<整份 settings.json 的 JSON 文本>", koboldai_settings: [...], themes: [...], ... }
      // 真正的设置正文是那个 **字符串** settings 字段；提交协议要的也是这份正文，不是聚合。
      const inner: string = aggregate.settings as string;
      let text: string = '';
      if (inner !== undefined && inner !== null && inner.substring(0, 1) === '{') {
        text = JSON.stringify(JSON.parse(inner) as ESObject, null, 2);
      } else {
        // 兜底：万一以后聚合改成直接内嵌对象
        text = JSON.stringify(aggregate, null, 2);
      }
      this.rawJson = text;
      this.originalJson = text;
      this.sizeText = `${text.length} 字符`;

      // 快速人设：power_user.persona_description
      // 桥接回来的 napi 对象上 Object.keys 拿不到键，所以重新 parse 一遍字符串。
      try {
        const reparsed: ESObject = JSON.parse(text) as ESObject;
        this.topKeys = Object.keys(reparsed).join(', ');
        const powerUser: ESObject = reparsed.power_user as ESObject;
        if (powerUser !== undefined && powerUser !== null) {
          const persona: string | undefined = powerUser.persona_description as string;
          this.personaText = persona === undefined || persona === null ? '' : persona;
          this.personaLoaded = true;
        }
      } catch (err) {
        this.personaLoaded = false;
      }
      this.statusText = '已读取 settings.json';
    } catch (err) {
      this.errorText = `读取设置失败：${(err as BackendError).message}`;
    } finally {
      this.loading = false;
    }
  }

  /** 分块提交整份 JSON。 */
  async saveJson(jsonText: string): Promise<void> {
    // 先本地校验，避免把坏 JSON 写进去
    let parsedOk: boolean = true;
    let parseError: string = '';
    try {
      JSON.parse(jsonText);
    } catch (err) {
      parsedOk = false;
      parseError = (err as Error).message;
    }
    if (!parsedOk) {
      this.errorText = `JSON 语法错误，未保存：${parseError}`;
      return;
    }

    this.busy = true;
    this.errorText = '';
    let sessionId: string = '';
    try {
      const begin: CommitBeginDto = await Backend.beginSettingsCommit(this.revision);
      sessionId = begin.sessionId;
      const bytes: Uint8Array = new util.TextEncoder().encodeInto(jsonText);
      const total: number = bytes.length;
      this.statusText = `提交会话 ${begin.sessionId.substring(0, 8)}… 上传中 0 / ${total} 字节`;
      let offset: number = 0;
      while (offset < total) {
        const end: number = Math.min(offset + CHUNK_BYTES, total);
        const slice: Uint8Array = bytes.slice(offset, end);
        const b64: string = new util.Base64Helper().encodeToStringSync(slice);
        const next: number = await Backend.appendSettingsCommitChunk(sessionId, offset, b64);
        offset = next;
        this.statusText = `上传中 ${offset} / ${total} 字节…`;
      }
      const result: UserSettingsSaveResultDto = await Backend.finishSettingsCommit(sessionId, total);
      sessionId = '';
      this.revision = result.tauritavern_settings_revision;
      const personaErrors: string = result.persona_errors === undefined
        ? '' : Object.keys(result.persona_errors).join(', ');
      this.statusText = personaErrors === ''
        ? `已保存（${result.result}，hash ${result.tauritavern_settings_revision.settings_hash.substring(0, 12)}…）`
        : `已保存，但人设有问题：${personaErrors}`;
      this.originalJson = jsonText;
      hilog.info(DOMAIN, TAG, 'settings committed: %{public}d bytes', total);
    } catch (err) {
      this.errorText = `保存失败：${(err as BackendError).message}`;
      if (sessionId !== '') {
        // 失败就放弃这次会话，别在后端留半截提交
        try {
          await Backend.abortSettingsCommit(sessionId);
        } catch (abortErr) {
          hilog.error(DOMAIN, TAG, 'abort commit failed');
        }
      }
    } finally {
      this.busy = false;
    }
  }

  /** 把人设写回 power_user.persona_description 再整份提交。 */
  async savePersona(): Promise<void> {
    try {
      const settings: ESObject = JSON.parse(this.rawJson) as ESObject;
      let powerUser: ESObject = settings.power_user as ESObject;
      if (powerUser === undefined || powerUser === null) {
        powerUser = {} as ESObject;
        settings.power_user = powerUser;
      }
      powerUser.persona_description = this.personaText;
      const next: string = JSON.stringify(settings, null, 2);
      this.rawJson = next;
      await this.saveJson(next);
    } catch (err) {
      this.errorText = `写人设失败：${(err as Error).message}`;
    }
  }

  changed(): boolean {
    return this.rawJson !== this.originalJson;
  }

  @Builder
  pageTopBar() {
    PageHeader({
        title: '高级用户设置',
        subtitle: '完整设置 JSON，请谨慎编辑',
        onBack: () => {
            ROOT_PATH_STACK.pop();
        }
      }) {
        HeaderAction({ label: '刷新', marker: 'settingsjsonpage-refresh-1', available: !this.busy,
          pending: this.loading,
          onAction: async (): Promise<void> => { await this.load(); } })
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
  
        if (this.loading) {
          EmptyHint('读取 settings.json…', '', this.uiColors)
        } else {
          Column() {
            Column({ space: Spacing.md }) {
              this.personaCard()
              this.jsonCard()
            }
            .width('100%')
            .padding({ bottom: 130 })
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
  personaCard() {
    Column({ space: Spacing.sm }) {
      SectionTitle('用户人设', this.uiColors)
      Text('对应 settings.json 的 power_user.persona_description，会作为 {{persona}} 注入提示词。')
        .fontSize(Typography.micro)
        .fontColor(this.uiColors.textTertiary)
        .width('100%')
      TextArea({ text: this.personaText, placeholder: '写下你希望 AI 记住的"你"…' })
        .fontColor(this.uiColors.textPrimary)
        .placeholderColor(this.uiColors.textTertiary)
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(UIRadius.sm)
        .fontSize(Typography.caption)
        .height(140)
        .width('100%')
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(Radius.sm)
        .enabled(!this.busy)
        .onChange((value: string) => {
          this.personaText = value;
        })
      .attributeModifier(new TextAreaFieldStyle(this.uiColors))
      Button('保存人设', { type: ButtonType.Normal })
        .fontSize(Typography.caption)
        .height(Touch.minTarget)
        .width('100%')
        .enabled(!this.busy && this.personaLoaded)
        .onClick(() => {
          this.savePersona();
        })
      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      if (!this.personaLoaded) {
        Text(`没有 power_user 段，人设快捷编辑不可用。顶层键：${this.topKeys}`)
          .fontSize(Typography.micro)
          .fontColor(this.uiColors.warning)
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
  jsonCard() {
    Column({ space: Spacing.sm }) {
      Row({ space: Spacing.sm }) {
        SectionTitle('settings.json', this.uiColors)
        Text(this.sizeText)
          .fontSize(Typography.micro)
          .fontColor(this.uiColors.textTertiary)
          .layoutWeight(1)
          .textAlign(TextAlign.End)
      }
      .width('100%')
      Text('整份设置按 128KB 分块上传（begin → append × N → finish）。保存前会先本地校验 JSON 语法。')
        .fontSize(Typography.micro)
        .fontColor(this.uiColors.textTertiary)
        .width('100%')
      TextArea({ text: this.rawJson })
        .fontColor(this.uiColors.textPrimary)
        .placeholderColor(this.uiColors.textTertiary)
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(UIRadius.sm)
        .fontSize(UIType.micro)
        .height(320)
        .width('100%')
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(Radius.sm)
        .enabled(!this.busy)
        .onChange((value: string) => {
          this.rawJson = value;
          this.sizeText = `${value.length} 字符`;
        })
      .attributeModifier(new TextAreaFieldStyle(this.uiColors))
      Row({ space: Spacing.sm }) {
        Button(this.changed() ? '保存 JSON *' : '保存 JSON', { type: ButtonType.Normal })
          .fontSize(Typography.caption)
          .height(Touch.minTarget)
          .layoutWeight(1)
          .enabled(!this.busy)
          .onClick(() => {
            this.saveJson(this.rawJson);
          })
        .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      Button('丢弃改动', { type: ButtonType.Normal })
          .fontSize(Typography.caption)
          .height(Touch.minTarget)
          .layoutWeight(1)
          .backgroundColor(this.uiColors.bgSurfaceHigh)
          .fontColor(this.uiColors.textSecondary)
          .enabled(!this.busy && this.changed())
          .onClick(() => {
            this.rawJson = this.originalJson;
            this.sizeText = `${this.originalJson.length} 字符`;
            this.statusText = '已丢弃未保存改动';
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
}
