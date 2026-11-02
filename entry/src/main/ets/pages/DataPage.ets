import { ActionButtonStyle, ActionTone } from '../theme/ControlStyles';
import { HeaderAction } from '../components/HeaderAction';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { PageSurface } from '../components/PageSurface';
import { SCROLL_EDGE_OPTIONS, SCROLL_NESTED_OPTIONS } from '../theme/ScrollFeedback';
import { Radius as UIRadius, Typography as UIType } from '../theme/Tokens';
import { PageHeader } from '../components/PageHeader';
// 导入导出（P8-16）：对应原项目 SillyTavern 的「导入聊天 / 导出角色卡 / 数据归档」。
//
// 鸿蒙端的文件 I/O 要点：
//   1. 选文件：picker.DocumentViewPicker.select({ maxSelectNumber, fileSuffixFilters })
//      → 拿到 file:// URI（用户目录，后端不可见）。
//   2. 必须**先拷贝到应用沙箱**（context.filesDir/imports/xxx），再把沙箱路径交给 Rust 命令。
//   3. 导出：Rust 把产物写进沙箱并返回 path（DeliveryResult），ArkTS 再
//      picker.DocumentViewPicker.save({ newFileNames }) 让用户选落地位置，然后字节拷贝。
//
// △ 需在 DevEco 编译验证：DocumentViewPicker 的构造与 select/save 参数、picker URI 的
//    fs.openSync(uri) 读写、save 返回 URI 的写权限。
//
// 对应 DevEco 工程路径：entry/src/main/ets/pages/DataPage.ets
import { picker } from '@kit.CoreFileKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Backend, BackendError } from '../backend/Backend';
import { CharacterDto, ChatDto, DataArchiveJobStatus, DeliveryResult, ExportedCharacterContent } from '../backend/Types';
import { ROOT_PATH_STACK } from '../nav/RootNav';
import { Radius, Spacing, Typography } from '../theme/Tokens';
import { GLASS_CARD, GLASS_HEADER, glassEffect } from '../theme/Glass';
import { EmptyHint, ErrorBannerView, SectionTitle } from '../components/Builders';

const DOMAIN: number = 0x0004;
const TAG: string = 'HarmonyTavern';

/** 导入格式（对应 Rust ChatImportFormat）。 */
interface ImportFormat {
  id: string;
  label: string;
}

const IMPORT_FORMATS: ImportFormat[] = [
  { id: 'sillytavern', label: 'SillyTavern (jsonl)' },
  { id: 'json', label: '通用 JSON' },
  { id: 'ooba', label: 'text-generation-webui' },
  { id: 'agnai', label: 'Agnai' },
  { id: 'koboldlite', label: 'Kobold Lite' },
  { id: 'risuai', label: 'RisuAI' }
];

@Component
export struct DataPage {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @State loading: boolean = true;
  @State busy: boolean = false;
  @State errorText: string = '';
  @State statusText: string = '';

  @State characters: CharacterDto[] = [];
  @State selectedCharacter: string = '';
  @State importFormat: string = 'sillytavern';
  @State exportFormat: string = 'json';
  @State includeSecrets: boolean = false;
  @State jobText: string = '';

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
      this.characters = await Backend.getAllCharacters();
      if (this.selectedCharacter === '' && this.characters.length > 0) {
        this.selectedCharacter = this.characters[0].name;
      }
    } catch (err) {
      this.errorText = `读取角色失败：${(err as BackendError).message}`;
    } finally {
      this.loading = false;
    }
  }

  context(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext;
  }

  /** 选一个文件，返回 URI（用户取消返回空串）。 */
  async pickFile(suffixes: string[]): Promise<string> {
    const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(this.context());
    const options: picker.DocumentSelectOptions = {
      maxSelectNumber: 1,
      fileSuffixFilters: suffixes
    };
    const uris: string[] = await documentPicker.select(options);
    if (uris === undefined || uris === null || uris.length === 0) {
      return '';
    }
    return uris[0];
  }

  /** 把选择器 URI 拷贝到沙箱，返回沙箱绝对路径。 */
  copyToSandbox(uri: string, subdir: string): string {
    const ctx: common.UIAbilityContext = this.context();
    const dir: string = `${ctx.filesDir}/${subdir}`;
    if (!fs.accessSync(dir)) {
      fs.mkdirSync(dir, true);
    }
    const nameFromUri: string = uri.substring(uri.lastIndexOf('/') + 1);
    const safeName: string = nameFromUri === '' ? `import_${Date.now()}.json` : nameFromUri;
    const dest: string = `${dir}/${safeName}`;
    const src: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    const stat: fs.Stat = fs.statSync(src.fd);
    const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
    fs.readSync(src.fd, buffer);
    fs.closeSync(src);
    const out: fs.File = fs.openSync(dest, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    fs.writeSync(out.fd, buffer);
    fs.closeSync(out);
    return dest;
  }

  /** 把 base64 内容写到用户选择的位置，返回落地 URI。 */
  async saveBase64(fileName: string, base64: string): Promise<string> {
    const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(this.context());
    const saveOptions: picker.DocumentSaveOptions = { newFileNames: [fileName] };
    const uris: string[] = await documentPicker.save(saveOptions);
    if (uris === undefined || uris === null || uris.length === 0) {
      return '';
    }
    const bytes: Uint8Array = new util.Base64Helper().decodeSync(base64);
    const out: fs.File = fs.openSync(uris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    fs.writeSync(out.fd, bytes.buffer as ArrayBuffer);
    fs.closeSync(out);
    return uris[0];
  }

  /** 把沙箱里的文件写到用户选择的位置，返回落地 URI。 */
  async saveSandboxFile(sandboxPath: string, fileName: string): Promise<string> {
    const src: fs.File = fs.openSync(sandboxPath, fs.OpenMode.READ_ONLY);
    const stat: fs.Stat = fs.statSync(src.fd);
    const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
    fs.readSync(src.fd, buffer);
    fs.closeSync(src);
    const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(this.context());
    const saveOptions: picker.DocumentSaveOptions = { newFileNames: [fileName] };
    const uris: string[] = await documentPicker.save(saveOptions);
    if (uris === undefined || uris === null || uris.length === 0) {
      return '';
    }
    const out: fs.File = fs.openSync(uris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    fs.writeSync(out.fd, buffer);
    fs.closeSync(out);
    return uris[0];
  }

  async doImportChat(): Promise<void> {
    if (this.selectedCharacter === '') {
      this.errorText = '先选一个角色';
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      const uri: string = await this.pickFile(['.jsonl', '.json']);
      if (uri === '') {
        this.busy = false;
        return;
      }
      const sandboxPath: string = this.copyToSandbox(uri, 'imports');
      const lower: string = uri.toLowerCase();
      const format: string = this.importFormat === 'sillytavern' && lower.endsWith('.json')
        ? 'json' : this.importFormat;
      const chat: ChatDto = await Backend.importChat(this.selectedCharacter, sandboxPath, format);
      this.statusText = `已导入 ${chat.file_name}（${chat.message_count} 条消息）`;
    } catch (err) {
      const message: string = err instanceof BackendError ? `${err.message}` : `${(err as BusinessError).message}`;
      this.errorText = `导入聊天失败：${message}`;
      hilog.error(DOMAIN, TAG, 'import chat failed: %{public}s', message);
    } finally {
      this.busy = false;
    }
  }

  async doImportCharacterChats(): Promise<void> {
    if (this.selectedCharacter === '') {
      this.errorText = '先选一个角色';
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      const uri: string = await this.pickFile(['.jsonl', '.json']);
      if (uri === '') {
        this.busy = false;
        return;
      }
      const sandboxPath: string = this.copyToSandbox(uri, 'imports');
      const fileType: string = uri.toLowerCase().endsWith('.jsonl') ? 'jsonl' : 'json';
      const files: string[] = await Backend.importCharacterChats(this.selectedCharacter, sandboxPath, fileType);
      this.statusText = `已导入 ${files.length} 个会话：${files.join(', ')}`;
    } catch (err) {
      const message: string = err instanceof BackendError ? `${err.message}` : `${(err as BusinessError).message}`;
      this.errorText = `批量导入失败：${message}`;
    } finally {
      this.busy = false;
    }
  }

  async doExportCharacter(): Promise<void> {
    if (this.selectedCharacter === '') {
      this.errorText = '先选一个角色';
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      const content: ExportedCharacterContent = await Backend.exportCharacterContent(
        this.selectedCharacter, this.exportFormat);
      const ext: string = this.exportFormat === 'png' ? 'png' : 'json';
      const fileName: string = `${this.selectedCharacter}.${ext}`;
      const saved: string = await this.saveBase64(fileName, content.dataBase64);
      this.statusText = saved === ''
        ? `已生成 ${fileName}（${content.byteLength} 字节），但没选保存位置`
        : `已导出到 ${saved}`;
    } catch (err) {
      const message: string = err instanceof BackendError ? `${err.message}` : `${(err as BusinessError).message}`;
      this.errorText = `导出角色失败：${message}`;
    } finally {
      this.busy = false;
    }
  }

  async doExportArchive(): Promise<void> {
    this.busy = true;
    this.errorText = '';
    this.jobText = '启动导出…';
    try {
      const jobId: string = await Backend.startExportDataArchive();
      let status: DataArchiveJobStatus | undefined = undefined;
      for (let i = 0; i < 120; i++) {
        status = await Backend.getDataArchiveJobStatus(jobId);
        this.jobText = `导出 ${status.progress_percent}% · ${status.stage}`;
        if (status.state === 'completed' || status.state === 'failed' || status.state === 'cancelled') {
          break;
        }
        await new Promise<void>((resolve: () => void) => {
          setTimeout(() => {
            resolve();
          }, 500);
        });
      }
      if (status === undefined || status.state !== 'completed') {
        this.errorText = `导出未完成：${status === undefined ? '无状态' : status.state}`;
        return;
      }
      const delivery: DeliveryResult = await Backend.saveExportDataArchive(jobId);
      if (!delivery.delivered || delivery.path === undefined) {
        this.errorText = '后端没有产出归档文件';
        return;
      }
      const name: string = delivery.fileName !== undefined ? delivery.fileName : 'harmonytavern-export.zip';
      const saved: string = await this.saveSandboxFile(delivery.path, name);
      this.statusText = saved === '' ? `归档已生成：${delivery.path}` : `已导出到 ${saved}`;
    } catch (err) {
      const message: string = err instanceof BackendError ? `${err.message}` : `${(err as BusinessError).message}`;
      this.errorText = `导出归档失败：${message}`;
    } finally {
      this.jobText = '';
      this.busy = false;
    }
  }

  async doImportArchive(): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      const uri: string = await this.pickFile(['.zip', '.hrt', '.tar', '.gz']);
      if (uri === '') {
        this.busy = false;
        return;
      }
      const sandboxPath: string = this.copyToSandbox(uri, 'archives');
      const result = await Backend.importDataArchiveFromPicker(sandboxPath);
      this.statusText = result.cancelled
        ? '已取消导入'
        : `已开始导入（job ${result.job_id !== undefined ? result.job_id : '?'}）`;
    } catch (err) {
      const message: string = err instanceof BackendError ? `${err.message}` : `${(err as BusinessError).message}`;
      this.errorText = `导入归档失败：${message}`;
    } finally {
      this.busy = false;
    }
  }

  async doExportUserBackup(): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      const delivery: DeliveryResult = await Backend.exportUserBackupArchive('default-user', this.includeSecrets);
      if (!delivery.delivered || delivery.path === undefined) {
        this.errorText = '后端没有产出备份文件';
        return;
      }
      const name: string = delivery.fileName !== undefined ? delivery.fileName : 'default-user-backup.zip';
      const saved: string = await this.saveSandboxFile(delivery.path, name);
      this.statusText = saved === '' ? `备份已生成：${delivery.path}` : `已导出到 ${saved}`;
    } catch (err) {
      const message: string = err instanceof BackendError ? `${err.message}` : `${(err as BusinessError).message}`;
      this.errorText = `导出用户备份失败：${message}`;
    } finally {
      this.busy = false;
    }
  }

  @Builder
  pageTopBar() {
    PageHeader({
        title: '数据',
        subtitle: '内容整理与数据维护',
        onBack: () => {
            ROOT_PATH_STACK.pop();
        }
      }) {
        HeaderAction({ label: '刷新', marker: 'datapage-refresh-1', available: !this.busy,
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
            .padding({ left: Spacing.md, right: Spacing.md })
            .maxLines(3)
        }
        if (this.jobText !== '') {
          Text(this.jobText)
            .fontSize(Typography.micro)
            .fontColor(this.uiColors.accent)
            .width('100%')
            .padding({ left: Spacing.md })
        }
        ErrorBannerView({ text: this.errorText })
  
        Column() {
          Column({ space: Spacing.md }) {
            if (this.loading) {
              Text('读取中…').fontSize(Typography.caption).fontColor(this.uiColors.textTertiary)
            } else {
              this.characterCard()
              if (this.characters.length === 0) {
                EmptyHint('还没有角色', '先在「角色」页创建一个，再回来导入导出', this.uiColors)
              }
              this.importCard()
              this.exportCard()
              this.archiveCard()
              this.backupCard()
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
  characterCard() {
    Column({ space: Spacing.sm }) {
      SectionTitle('目标角色', this.uiColors)
      Text(this.selectedCharacter === '' ? '未选择' : this.selectedCharacter)
        .fontSize(Typography.caption)
        .fontColor(this.uiColors.textPrimary)
        .width('100%')
      Scroll() {
        Row({ space: 6 }) {
          ForEach(this.characters, (character: CharacterDto) => {
            Button(character.name, { type: ButtonType.Normal })
              .fontSize(UIType.micro)
              .constraintSize({ minHeight: 44 })
              .backgroundColor(this.selectedCharacter === character.name
                ? this.uiColors.accent : this.uiColors.bgSurfaceHigh)
              .fontColor(this.selectedCharacter === character.name
                ? this.uiColors.textInverse : this.uiColors.textSecondary)
              .onClick(() => {
                this.selectedCharacter = character.name;
              })
          .attributeModifier(new ActionButtonStyle(this.uiColors, (this.selectedCharacter === character.name) ? ActionTone.Selected : ActionTone.Normal))
      }, (character: CharacterDto) => character.name)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .edgeEffect(EdgeEffect.Spring, SCROLL_EDGE_OPTIONS)
      .nestedScroll(SCROLL_NESTED_OPTIONS)
      .scrollBar(BarState.Off)
      .width('100%')
      .constraintSize({ minHeight: 44 })
    }
    .width('100%')
    .padding(Spacing.md)
    .borderRadius(GLASS_CARD.radius)
    .backgroundColor(this.uiColors.bgSurface)
    .border({ width: 1, color: this.uiColors.borderSubtle })
  }

  @Builder
  importCard() {
    Column({ space: Spacing.sm }) {
      SectionTitle('导入聊天', this.uiColors)
      Text('格式')
        .fontSize(Typography.micro)
        .fontColor(this.uiColors.textTertiary)
        .width('100%')
      Scroll() {
        Row({ space: 6 }) {
          ForEach(IMPORT_FORMATS, (format: ImportFormat) => {
            Button(format.label, { type: ButtonType.Normal })
              .fontSize(UIType.micro)
              .constraintSize({ minHeight: 44 })
              .backgroundColor(this.importFormat === format.id
                ? this.uiColors.accent : this.uiColors.bgSurfaceHigh)
              .fontColor(this.importFormat === format.id
                ? this.uiColors.textInverse : this.uiColors.textSecondary)
              .onClick(() => {
                this.importFormat = format.id;
              })
          .attributeModifier(new ActionButtonStyle(this.uiColors, (this.importFormat === format.id) ? ActionTone.Selected : ActionTone.Normal))
      }, (format: ImportFormat) => format.id)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .edgeEffect(EdgeEffect.Spring, SCROLL_EDGE_OPTIONS)
      .nestedScroll(SCROLL_NESTED_OPTIONS)
      .scrollBar(BarState.Off)
      .width('100%')
      .constraintSize({ minHeight: 44 })
      Button('选择文件并导入到当前角色', { type: ButtonType.Normal })
        .fontSize(Typography.caption)
        .constraintSize({ minHeight: 44 })
        .width('100%')
        .enabled(!this.busy)
        .onClick(() => {
          this.doImportChat();
        })
      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      Button('导入为角色的一批会话', { type: ButtonType.Normal })
        .fontSize(Typography.caption)
        .constraintSize({ minHeight: 44 })
        .width('100%')
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .fontColor(this.uiColors.textSecondary)
        .enabled(!this.busy)
        .onClick(() => {
          this.doImportCharacterChats();
        })
      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      Text('文件会先拷贝到应用沙箱再交给后端解析；导入后回聊天页刷新即可看到。')
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

  @Builder
  exportCard() {
    Column({ space: Spacing.sm }) {
      SectionTitle('导出角色卡', this.uiColors)
      Row({ space: Spacing.sm }) {
        Button('JSON', { type: ButtonType.Normal })
          .fontSize(UIType.caption)
          .constraintSize({ minHeight: 44 })
          .layoutWeight(1)
          .backgroundColor(this.exportFormat === 'json' ? this.uiColors.accent : this.uiColors.bgSurfaceHigh)
          .fontColor(this.exportFormat === 'json' ? this.uiColors.textInverse : this.uiColors.textSecondary)
          .onClick(() => {
            this.exportFormat = 'json';
          })
        .attributeModifier(new ActionButtonStyle(this.uiColors, (this.exportFormat === 'json') ? ActionTone.Selected : ActionTone.Normal))
      Button('PNG 卡', { type: ButtonType.Normal })
          .fontSize(UIType.caption)
          .constraintSize({ minHeight: 44 })
          .layoutWeight(1)
          .backgroundColor(this.exportFormat === 'png' ? this.uiColors.accent : this.uiColors.bgSurfaceHigh)
          .fontColor(this.exportFormat === 'png' ? this.uiColors.textInverse : this.uiColors.textSecondary)
          .onClick(() => {
            this.exportFormat = 'png';
          })
      .attributeModifier(new ActionButtonStyle(this.uiColors, (this.exportFormat === 'png') ? ActionTone.Selected : ActionTone.Normal))
      }
      .width('100%')
      Button('导出并选择保存位置', { type: ButtonType.Normal })
        .fontSize(Typography.caption)
        .constraintSize({ minHeight: 44 })
        .width('100%')
        .enabled(!this.busy)
        .onClick(() => {
          this.doExportCharacter();
        })
    .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      }
    .width('100%')
    .padding(Spacing.md)
    .borderRadius(GLASS_CARD.radius)
    .backgroundColor(this.uiColors.bgSurface)
    .border({ width: 1, color: this.uiColors.borderSubtle })
  }

  @Builder
  archiveCard() {
    Column({ space: Spacing.sm }) {
      SectionTitle('全量数据归档', this.uiColors)
      Text('导出包含角色/聊天/设置/技能的 zip 归档，用于换机或备份。')
        .fontSize(Typography.micro)
        .fontColor(this.uiColors.textTertiary)
        .width('100%')
      Button('导出归档', { type: ButtonType.Normal })
        .fontSize(Typography.caption)
        .constraintSize({ minHeight: 44 })
        .width('100%')
        .enabled(!this.busy)
        .onClick(() => {
          this.doExportArchive();
        })
      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      Button('导入归档（覆盖同名数据）', { type: ButtonType.Normal })
        .fontSize(Typography.caption)
        .constraintSize({ minHeight: 44 })
        .width('100%')
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .fontColor(this.uiColors.textSecondary)
        .enabled(!this.busy)
        .onClick(() => {
          this.doImportArchive();
        })
    .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      }
    .width('100%')
    .padding(Spacing.md)
    .borderRadius(GLASS_CARD.radius)
    .backgroundColor(this.uiColors.bgSurface)
    .border({ width: 1, color: this.uiColors.borderSubtle })
  }

  @Builder
  backupCard() {
    Column({ space: Spacing.sm }) {
      SectionTitle('用户数据备份', this.uiColors)
      Row({ space: Spacing.sm }) {
        Text('包含密钥')
          .fontSize(Typography.caption)
          .fontColor(this.uiColors.textSecondary)
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.includeSecrets })
          .selectedColor(this.uiColors.accent)
          .onChange((on: boolean) => {
            this.includeSecrets = on;
          })
      }
      .width('100%')
      Button('导出 default-user 备份', { type: ButtonType.Normal })
        .fontSize(Typography.caption)
        .constraintSize({ minHeight: 44 })
        .width('100%')
        .enabled(!this.busy)
        .onClick(() => {
          this.doExportUserBackup();
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
