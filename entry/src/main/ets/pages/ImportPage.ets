import { SurfaceStyle } from '../theme/SurfaceStyles';
import { ActionButtonStyle, ActionTone, TextAreaFieldStyle } from '../theme/ControlStyles';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { PageSurface } from '../components/PageSurface';
import { SCROLL_EDGE_OPTIONS, SCROLL_NESTED_OPTIONS } from '../theme/ScrollFeedback';
import { PageHeader } from '../components/PageHeader';
import { SettingsChoice, SettingsPicker } from '../components/SettingsPicker';
import { CharacterEditing } from '../backend/CharacterEditing';
import { Radius as UIRadius, Typography as UIType } from '../theme/Tokens';
// 角色卡导入（P9-2）：把「拖一张 PNG 进来」这条链路补成正式入口。
//
// 对应 DevEco 工程路径：entry/src/main/ets/pages/ImportPage.ets
//
// 背景：Rust 侧 `import_character` / `replace_character` / `import_character_chats`
// 早就实现了（PNG 卡里的 tEXt `chara` 块解析、lorebook 采用、.jsonl 会话导入都在核心层），
// 但 ArkTS 一直**没有入口**——只在首页诊断区手搓过一次。这个页面把它补齐。
//
// 鸿蒙端的关键约束（和 DataPage 同一套）：
//   1. 选择器给的是 `file://media/...` / `file://docs/...` URI，**Rust 打不开**；
//   2. 必须先把字节拷进沙箱（context.filesDir/imports/），再把沙箱绝对路径交给命令；
//   3. 相册用 photoAccessHelper（图片收不到后缀过滤器），文件用 DocumentViewPicker。
//
// 支持四种入口：
//   A. 相册选 PNG（最常见的"角色卡就是一张图"）
//   B. 文件选 PNG / JSON（从下载目录拿卡）
//   C. 粘贴 JSON（SillyTavern「导出角色」得到的那段文本，直接贴）
//   D. 替换现有角色卡 / 导入会话记录（.jsonl）
//
// 对应 DevEco 工程路径：entry/src/main/ets/pages/ImportPage.ets
import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Backend, BackendError } from '../backend/Backend';
import { CharacterDto, ImportCharacterResult } from '../backend/Types';
import { LibraryEditIntent, ROOT_PATH_STACK } from '../nav/RootNav';
import { Radius, Spacing, Touch, Typography } from '../theme/Tokens';
import { GLASS_CARD, GLASS_HEADER, glassEffect } from '../theme/Glass';
import { EmptyHint, ErrorBannerView, SectionTitle } from '../components/Builders';
import { staggeredEntrance } from '../theme/Motion';

const DOMAIN: number = 0x0009;
const TAG: string = 'HarmonyTavern';

/** 导入来源。 */
interface ImportSource {
  id: string;
  label: string;
  hint: string;
}

const SOURCES: ImportSource[] = [
  { id: 'album', label: '从相册选 PNG 卡', hint: '角色卡是一张图，里面写着角色数据' },
  { id: 'file', label: '从文件选 PNG / JSON', hint: '下载目录里的卡或导出的 JSON' }
];

@Component
export struct ImportPage {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  /** 嵌入「管理」页时置 true：隐藏本页的返回头部，由外层统一承载 */
  @Prop embedded: boolean = false;
  @Prop showManagement: boolean = true;
  onImported: (character: CharacterDto) => void = (): void => {};
  @Prop contentBottom: number = 24;
  @State characters: CharacterDto[] = [];
  @State selected: string = '';
  @State pastedJson: string = '';
  @State statusText: string = '';
  @State errorText: string = '';
  @State busy: boolean = false;
  @State loading: boolean = false;
  /** 最近一次导入结果（角色名 + lorebook 摘要） */
  @State lastImported: string = '';

  aboutToAppear(): void {
    if (!Backend.isReady()) {
      this.errorText = '后端未就绪，请从首页进入';
      return;
    }
    this.reload();
  }

  async reload(): Promise<void> {
    this.loading = true;
    try {
      this.characters = await Backend.getAllCharacters();
      if (this.selected === '' && this.characters.length > 0) {
        this.selected = CharacterEditing.key(this.characters[0]);
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

  /** 把 URI 里的字节拷进沙箱，返回沙箱绝对路径。 */
  copyToSandbox(uri: string, fallbackName: string): string {
    const dir: string = `${this.context().filesDir}/imports`;
    if (!fs.accessSync(dir)) {
      fs.mkdirSync(dir, true);
    }
    const fromUri: string = uri.substring(uri.lastIndexOf('/') + 1);
    // URI 末尾可能带查询串，去掉再拼
    const clean: string = fromUri.split('?')[0];
    const name: string = clean === '' ? fallbackName : clean;
    const dest: string = `${dir}/${name}`;
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

  /** 把粘贴的 JSON 写进沙箱，返回路径。 */
  writePasted(text: string): string {
    const dir: string = `${this.context().filesDir}/imports`;
    if (!fs.accessSync(dir)) {
      fs.mkdirSync(dir, true);
    }
    const dest: string = `${dir}/pasted_${Date.now()}.json`;
    const file: fs.File = fs.openSync(dest, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    fs.writeSync(file.fd, text);
    fs.closeSync(file);
    return dest;
  }

  /** A：相册选 PNG。 */
  async importFromAlbum(): Promise<void> {
    this.errorText = '';
    this.busy = true;
    try {
      const pickerOptions: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      pickerOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      pickerOptions.maxSelectNumber = 1;
      const photoPicker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await photoPicker.select(pickerOptions);
      if (result.photoUris === undefined || result.photoUris.length === 0) {
        this.busy = false;
        return;
      }
      const path: string = this.copyToSandbox(result.photoUris[0], `card_${Date.now()}.png`);
      await this.runImport(path);
    } catch (err) {
      this.errorText = `相册导入失败：${(err as BackendError).message}`;
      hilog.error(DOMAIN, TAG, 'import from album failed: %{public}s', this.errorText);
    } finally {
      this.busy = false;
    }
  }

  /** B：文件选 PNG / JSON。 */
  async importFromFile(): Promise<void> {
    this.errorText = '';
    this.busy = true;
    try {
      const options: picker.DocumentSelectOptions = {
        maxSelectNumber: 1,
        fileSuffixFilters: ['角色卡|.png,.json', '全部|.*']
      };
      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(this.context());
      const uris: string[] = await documentPicker.select(options);
      if (uris === undefined || uris.length === 0) {
        this.busy = false;
        return;
      }
      const path: string = this.copyToSandbox(uris[0], `card_${Date.now()}.json`);
      await this.runImport(path);
    } catch (err) {
      this.errorText = `文件导入失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  /** C：粘贴 JSON。 */
  async importPasted(): Promise<void> {
    if (this.pastedJson.trim() === '') {
      this.errorText = '先粘贴角色卡 JSON';
      return;
    }
    // 先在客户端校验一次 JSON，避免把垃圾写进沙箱再让 Rust 报一句莫名其妙的错
    try {
      JSON.parse(this.pastedJson);
    } catch (err) {
      this.errorText = `不是合法 JSON：${(err as Error).message}`;
      return;
    }
    this.errorText = '';
    this.busy = true;
    try {
      const path: string = this.writePasted(this.pastedJson);
      await this.runImport(path);
      this.pastedJson = '';
    } catch (err) {
      this.errorText = `粘贴导入失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  /** 真正的导入：交给 Rust 解析 PNG 的 tEXt/chara 或 JSON。 */
  async runImport(path: string): Promise<void> {
    const result: ImportCharacterResult = await Backend.importCharacter(path);
    const lunr: string = result.lorebook === undefined || result.lorebook === null
      ? '无内嵌世界书'
      : '已处理内嵌世界书';
    this.statusText = `已导入：${result.character.name}（${lunr}）`;
    this.lastImported = `路径：${path}`;
    await this.reload();
    const key: string = (result.character.avatar ?? '').replace(/\.png$/i, '') || result.character.name;
    const imported: CharacterDto = await Backend.getCharacter(key);
    this.selected = CharacterEditing.key(imported);
    this.onImported(imported);
  }

  /** D1：把卡覆盖到已有角色。 */
  async replaceExisting(): Promise<void> {
    if (this.selected === '') {
      this.errorText = '先选一个要替换的角色';
      return;
    }
    this.errorText = '';
    this.busy = true;
    try {
      const options: picker.DocumentSelectOptions = {
        maxSelectNumber: 1,
        fileSuffixFilters: ['角色卡|.png,.json', '全部|.*']
      };
      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(this.context());
      const uris: string[] = await documentPicker.select(options);
      if (uris === undefined || uris.length === 0) {
        this.busy = false;
        return;
      }
      const path: string = this.copyToSandbox(uris[0], `replace_${Date.now()}.png`);
      const result: ImportCharacterResult = await Backend.replaceCharacter(this.selected, path);
      this.statusText = `已替换：${this.selected} ← ${result.character.name}`;
      await this.reload();
    } catch (err) {
      this.errorText = `替换失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  /** D2：导入该角色的会话记录（.jsonl）。 */
  async importChats(): Promise<void> {
    if (this.selected === '') {
      this.errorText = '先选一个角色';
      return;
    }
    this.errorText = '';
    this.busy = true;
    try {
      const options: picker.DocumentSelectOptions = {
        maxSelectNumber: 1,
        fileSuffixFilters: ['会话记录|.jsonl,.json', '全部|.*']
      };
      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(this.context());
      const uris: string[] = await documentPicker.select(options);
      if (uris === undefined || uris.length === 0) {
        this.busy = false;
        return;
      }
      const path: string = this.copyToSandbox(uris[0], `chats_${Date.now()}.jsonl`);
      const imported: string[] = await Backend.importCharacterChats(this.selected, path, 'jsonl');
      this.statusText = `已导入 ${imported.length} 个会话到 ${this.selected}`;
    } catch (err) {
      this.errorText = `导入会话失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  @Builder
  header() {
    PageHeader({ title: '导入角色', subtitle: '把收藏带进新的故事', onBack: () => ROOT_PATH_STACK.pop() })
  }

  @Builder
  pageBody() {
    Column() {
      

      Column() {
        Column({ space: Spacing.md }) {
          if (this.showManagement) {
            Button('管理与编辑角色卡').attributeModifier(new ActionButtonStyle(this.uiColors)).width('100%')
              .id('import-open-characters').onClick((): void => { ROOT_PATH_STACK.pushPathByName('pages/CharactersPage', null); })
          }
          SectionTitle('导入角色卡', this.uiColors)

          Text('带上你喜欢的角色，开启新的故事。支持 PNG 角色卡和 JSON 文件，也可以直接粘贴内容。')
            .fontSize(Typography.caption)
            .fontColor(this.uiColors.textTertiary)
            .width('100%')

          ForEach(SOURCES, (source: ImportSource, index: number) => {
            Column({ space: 2 }) {
              Text(source.label)
                .fontSize(Typography.body)
                .fontColor(this.uiColors.textPrimary)
              Text(source.hint)
                .fontSize(Typography.micro)
                .fontColor(this.uiColors.textTertiary)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(Spacing.md)
            .backgroundColor(this.uiColors.bgSurface)
            .borderRadius(Radius.md)
            .attributeModifier(new SurfaceStyle(this.uiColors, Radius.md))
            .opacity(this.busy ? 0.5 : 1)
            .onClick(() => {
              if (this.busy) {
                return;
              }
              if (source.id === 'album') {
                this.importFromAlbum();
              } else if (source.id === 'file') {
                this.importFromFile();
              }
            })
            .transition(staggeredEntrance(12, index))
          }, (source: ImportSource) => source.id)

          // 粘贴 JSON：单独一块，带输入框
          Column({ space: Spacing.sm }) {
            Text('粘贴 JSON')
              .fontSize(Typography.body)
              .fontColor(this.uiColors.textPrimary)
              .width('100%')
            TextArea({ text: this.pastedJson, placeholder: '{"name":"…","first_mes":"…"}' })
              .fontColor(this.uiColors.textPrimary)
              .placeholderColor(this.uiColors.textTertiary)
              .backgroundColor(this.uiColors.bgSurfaceHigh)
              .borderRadius(UIRadius.sm)
              .height(120)
              .fontSize(Typography.caption)
              .backgroundColor(this.uiColors.bgSurfaceHigh)
              .borderRadius(Radius.sm)
              .onChange((value: string) => {
                this.pastedJson = value;
              })
            .attributeModifier(new TextAreaFieldStyle(this.uiColors))
      Button('导入这段 JSON', { type: ButtonType.Normal })
              .fontSize(Typography.caption)
              .height(Touch.minTarget)
              .width('100%')
              .backgroundColor(this.uiColors.accent)
              .fontColor(this.uiColors.textInverse)
              .enabled(!this.busy)
              .onClick(() => {
                this.importPasted();
              })
          .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(Spacing.md)
          .backgroundColor(this.uiColors.bgSurface)
          .borderRadius(Radius.md)
          .attributeModifier(new SurfaceStyle(this.uiColors, Radius.md))

          if (this.showManagement) {
          SectionTitle('已有角色卡', this.uiColors)

          Text(this.selected === '' ? '未选择角色' : `目标角色：${this.selected}`)
            .fontSize(Typography.caption)
            .fontColor(this.uiColors.textSecondary)
            .width('100%')

          SettingsPicker({ title: '选择角色卡', marker: 'import-character-picker', selectedId: this.selected,
            options: this.characters.map((character: CharacterDto): SettingsChoice => {
              return { id: CharacterEditing.key(character), label: character.name };
            }), onSelect: (id: string): void => { this.selected = id; } })
          Button('编辑所选角色卡').attributeModifier(new ActionButtonStyle(this.uiColors)).width('100%')
            .id('import-edit-character').enabled(this.selected !== '' && !this.busy)
            .onClick((): void => { LibraryEditIntent.editCharacter(this.selected); })

          // 聊天记录导入已经拆到独立页面（pages/ChatImportPage），这页只负责角色卡
          Button('替换这张卡的来源', { type: ButtonType.Normal })
            .fontSize(Typography.caption)
            .height(Touch.minTarget)
            .width('100%')
            .backgroundColor(this.uiColors.bgSurfaceHigh)
            .fontColor(this.uiColors.textSecondary)
            .enabled(!this.busy && this.selected !== '')
            .onClick(() => {
              this.replaceExisting();
            })

          .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
          }
      if (this.statusText !== '') {
            Text(this.statusText)
              .fontSize(Typography.caption)
              .fontColor(this.uiColors.success)
              .width('100%')
          }
          if (this.lastImported !== '') {
            Text(this.lastImported)
              .fontSize(Typography.micro)
              .fontColor(this.uiColors.textTertiary)
              .width('100%')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }

          ErrorBannerView({ text: this.errorText })

          if (this.loading) {
            Text('正在读取角色…')
              .fontSize(Typography.micro)
              .fontColor(this.uiColors.textTertiary)
          }
        }
        .width('100%')
        .padding({ left: Spacing.lg, right: Spacing.lg, bottom: this.embedded ? this.contentBottom : Spacing.xxl })
      }
      .width('100%')
    }
    .width('100%')
    .backgroundColor(this.embedded ? Color.Transparent : this.uiColors.bgBase)
  }

  @Builder
  buildSurfaceContent() {
        this.pageBody()
      }

  build() {
    if (this.embedded) {
      this.pageBody()
    } else {
      PageSurface({ topBar: () => { this.header(); }, horizontalInset: 0, content: () => { this.buildSurfaceContent(); } })
    }
  }
}
