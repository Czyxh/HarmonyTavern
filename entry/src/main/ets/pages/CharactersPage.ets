import { ActionButtonStyle, ActionTone, TextAreaFieldStyle } from '../theme/ControlStyles';
import { ImportPage } from './ImportPage';
import { SettingsPicker } from '../components/SettingsPicker';
import { CharacterEditing, CharacterForm } from '../backend/CharacterEditing';
import { saveBytes } from '../utils/ExportFiles';
import { common } from '@kit.AbilityKit';
import { HeaderAction } from '../components/HeaderAction';
import { iconTint } from '../theme/IconTint';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { PageSurface } from '../components/PageSurface';
import { OriginMotion, OriginPanelState } from '../theme/OriginMotion';
import { OriginPanel } from '../components/OriginPanel';
import { LiquidMenuItem } from '../components/LiquidMenuItem';
import { Radius as UIRadius, Typography as UIType } from '../theme/Tokens';
import { PageHeader } from '../components/PageHeader';
// 角色管理页（P8-3）：补齐原项目里 27 条角色命令中最常用的写操作。
//
// 覆盖：create_character / update_character / delete_character / rename_character /
//       duplicate_character / export_character_content / get_all_characters
// 未覆盖（记录在案）：create_character_with_avatar、update_avatar（需先接图片选择流程）、
//       import_character / replace_character（已在首页诊断区验证过，未做正式入口）、
//       set_character_chat_store_json 系列（底层存储级命令，UI 不需要）。
//
// 交互：列表 → 点行进入编辑；右下角「新建」；每行「⋯」出操作菜单（重命名/复制/导出/删除）。
//
// 对应 DevEco 工程路径：entry/src/main/ets/pages/CharactersPage.ets
import { hilog } from '@kit.PerformanceAnalysisKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { Backend, BackendError } from '../backend/Backend';
import { CharacterDto } from '../backend/Types';
import {
  CreateCharacterDto,
  DeleteCharacterDto,
  DuplicateCharacterDto,
  RenameCharacterDto,
  UpdateCharacterDto
} from '../backend/AdminTypes';
import { LibraryEditIntent, ROOT_PATH_STACK } from '../nav/RootNav';
import { Radius, Spacing, Typography } from '../theme/Tokens';
import { Glass, GLASS_CARD } from '../theme/Glass';
import { LS_BLUR_DEFAULT, LS_BLUR_KEY } from '../theme/LightSense';
import { IMMERSIVE_DEFAULT, IMMERSIVE_KEY } from '../theme/Immersive';
import { EmptyHint, ErrorBannerView, SectionTitle } from '../components/Builders';

const DOMAIN: number = 0x0003;
const TAG: string = 'HarmonyTavern';

/** 编辑表单状态（null 表示新建）。 */

// Immediate touch-down feedback; opacity also works with reduced motion.
@Styles
function touchFeedbackNormal() {
  .opacity(1)
}

@Styles
function touchFeedbackPressed() {
  .opacity(0.68)
}

@Component
export struct CharactersPage {
  @StorageProp(LS_BLUR_KEY) blurRadius: number = LS_BLUR_DEFAULT;
  @StorageProp(IMMERSIVE_KEY) immersiveLevel: number = IMMERSIVE_DEFAULT;
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @State characters: CharacterDto[] = [];
  @State menuOrigin: OriginPanelState = new OriginPanelState();
  @State loading: boolean = true;
  @State busy: boolean = false;
  @State errorText: string = '';
  @State statusText: string = '';
  /** 正在编辑的表单；undefined 表示列表模式。 */
  @State form: CharacterForm | undefined = undefined;
  @State mode: string = 'list';
  @State editorSection: string = 'basic';
  @State query: string = '';
  @State addMenu: OriginPanelState = new OriginPanelState();

  aboutToAppear(): void {
    if (!Backend.isReady()) {
      this.errorText = '后端未就绪，请从首页进入';
      this.loading = false;
      return;
    }
    const key: string = LibraryEditIntent.takeCharacter();
    this.reload().then((): void => {
      if (key !== '') { this.openEdit({ name: key, first_mes: '' }); }
    });
  }

  async reload(): Promise<void> {
    this.loading = true;
    this.errorText = '';
    try {
      this.characters = await Backend.getAllCharacters();
      this.statusText = `共 ${this.characters.length} 个角色`;
    } catch (err) {
      this.errorText = `读取角色失败：${(err as BackendError).message}`;
      hilog.error(DOMAIN, TAG, 'load characters failed: %{public}s', this.errorText);
    } finally {
      this.loading = false;
    }
  }

  openCreate(): void {
    this.form = CharacterEditing.form();
    this.editorSection = 'basic';
    this.mode = 'edit';
    this.errorText = '';
  }

  async openEdit(character: CharacterDto): Promise<void> {
    if (this.busy) { return; }
    this.busy = true;
    this.errorText = '';
    try {
      // 列表是 deep 快照，但字段可能被裁剪；编辑前取完整对象。
      const full: CharacterDto = await Backend.getCharacter(CharacterEditing.key(character));
      this.form = CharacterEditing.form(full);
      this.editorSection = 'basic';
      this.mode = 'edit';
    } catch (err) {
      this.errorText = `读取角色详情失败：${(err as BackendError).message}`;
    } finally { this.busy = false; }
  }

  async save(): Promise<void> {
    if (this.busy) { return; }
    const form: CharacterForm | undefined = this.form;
    if (form === undefined) {
      return;
    }
    if (form.name.trim() === '') {
      this.errorText = '角色名不能为空';
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      if (form.originalName === '') {
        const dto: CreateCharacterDto = {
          name: form.name.trim(),
          description: form.description,
          personality: form.personality,
          scenario: form.scenario,
          first_mes: form.firstMes,
          mes_example: form.mesExample,
          creator: form.creator, creator_notes: form.creatorNotes, character_version: form.version,
          tags: CharacterEditing.update(form).tags, system_prompt: form.systemPrompt,
          post_history_instructions: form.postHistory, alternate_greetings: CharacterEditing.update(form).alternate_greetings
        };
        const created: CharacterDto = await Backend.createCharacter(dto);
        this.statusText = `已创建：${created.name}`;
      } else {
        const dto: UpdateCharacterDto = CharacterEditing.update(form);
        // 改名字要单独走 rename_character（update 的 name 字段语义不是重命名存储键）。
        if (form.name.trim() !== form.originalDisplayName) {
          const renameDto: RenameCharacterDto = {
            old_name: form.originalName,
            new_name: form.name.trim()
          };
          const renamed: CharacterDto = await Backend.renameCharacter(renameDto);
          form.originalName = CharacterEditing.key(renamed);
          form.originalDisplayName = renamed.name;
        }
        await Backend.updateCharacter(form.originalName, dto);
        this.statusText = `已保存：${form.name.trim()}`;
      }
      this.mode = 'list';
      this.form = undefined;
      await this.reload();
    } catch (err) {
      this.errorText = `保存失败：${(err as BackendError).message}`;
      hilog.error(DOMAIN, TAG, 'save character failed: %{public}s', this.errorText);
    } finally {
      this.busy = false;
    }
  }

  async duplicate(character: CharacterDto): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      const dto: DuplicateCharacterDto = { name: CharacterEditing.key(character) };
      const copy: CharacterDto = await Backend.duplicateCharacter(dto);
      this.statusText = `已复制：${copy.name}`;
      await this.reload();
    } catch (err) {
      this.errorText = `复制失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async exportContent(character: CharacterDto): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      const data = await Backend.exportCharacterContent(CharacterEditing.key(character), 'json');
      const bytes: Uint8Array = new util.Base64Helper().decodeSync(data.dataBase64);
      const saved: boolean = await saveBytes(this.getUIContext().getHostContext() as common.UIAbilityContext,
        character.name.replace(/[\\/:*?"<>|]/g, '_') + '.json', bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer);
      this.statusText = saved ? `已导出 ${character.name}` : '已取消导出';
    } catch (err) {
      this.errorText = `导出失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  @Builder
  rowMenu(character: CharacterDto) {
    Scroll() {
      Column() {
        LiquidMenuItem({ label: '重命名', onSelect: (): void => {
          this.menuOrigin.select((): void => { this.promptRename(character); });
        } })
        LiquidMenuItem({ label: '复制一份', onSelect: (): void => {
          this.menuOrigin.select((): void => { this.duplicate(character); });
        } })
        LiquidMenuItem({ label: '导出 JSON', onSelect: (): void => {
          this.menuOrigin.select((): void => { this.exportContent(character); });
        } })
        LiquidMenuItem({ label: '更换头像', onSelect: (): void => {
          this.menuOrigin.select((): void => { this.changeAvatar(character); });
        } })
        LiquidMenuItem({ label: '删除', destructive: true, onSelect: (): void => {
          this.menuOrigin.select((): void => { this.confirmDelete(character); });
        } })
      }
      .width('100%').padding(8)
      .onAreaChange((_previous: Area, area: Area): void => { this.menuOrigin.fitMenuHeight(Number(area.height)); })
    }
    .width('100%').height('100%').scrollBar(BarState.Off)
  }

  @Builder
  rowMenuCover(character: CharacterDto) {
    Stack() {
      OriginPanel({ state: this.menuOrigin, content: (): void => { this.rowMenu(character); } })
    }
    .width('100%').height('100%')
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }

  /**
   * 换头像（P8-17）：相册选图 → base64 → upload_user_image 落到用户图片目录 →
   * update_avatar 把该路径写进角色卡。
   * △ 需在 DevEco 编译验证：update_avatar 是否接受 user images 目录下的相对路径。
   */
  private async changeAvatar(character: CharacterDto): Promise<void> {
    try {
      const photoPicker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const options: photoAccessHelper.PhotoSelectOptions = {
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      };
      const picked: photoAccessHelper.PhotoSelectResult = await photoPicker.select(options);
      if (picked.photoUris.length === 0) {
        return;
      }
      const uri: string = picked.photoUris[0];
      this.busy = true;
      this.errorText = '';
      const file: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const stat: fs.Stat = fs.statSync(file.fd);
      const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);
      fs.closeSync(file);
      const base64: string = new util.Base64Helper().encodeToStringSync(new Uint8Array(buffer));
      const dot: number = uri.lastIndexOf('.');
      const ext: string = dot >= 0 ? uri.substring(dot + 1).toLowerCase() : 'png';
      const upload = await Backend.uploadUserImage({
        imageBase64: base64,
        format: ext === 'jpeg' ? 'jpg' : ext,
        filename: `${character.name}.${ext === 'jpeg' ? 'jpg' : ext}`,
        chName: CharacterEditing.key(character)
      });
      await Backend.updateAvatar(CharacterEditing.key(character), upload.path);
      this.statusText = `已更换 ${character.name} 的头像：${upload.path}`;
      await this.reload();
    } catch (err) {
      this.errorText = `换头像失败：${(err as BackendError).message}`;
      hilog.error(0x0004, 'HarmonyTavern', 'changeAvatar failed: %{public}s', (err as Error).message);
    } finally {
      this.busy = false;
    }
  }

  promptRename(character: CharacterDto): void {
    this.openEdit(character);
  }

  confirmDelete(character: CharacterDto): void {
    this.getUIContext().showAlertDialog({
      title: '删除角色',
      alignment: DialogAlignment.Center,
      transition: OriginMotion.dialog(this.getUIContext(), 'character-options-' + character.name),
      message: `确定删除「${character.name}」？\n勾选「同时删除会话」会连带删掉它的所有聊天记录。`,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除（含会话）',
        action: () => {
          this.doDelete(character, true);
        }
      }
    });
  }

  async doDelete(character: CharacterDto, deleteChats: boolean): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      const dto: DeleteCharacterDto = { name: CharacterEditing.key(character), delete_chats: deleteChats };
      await Backend.deleteCharacter(dto);
      this.statusText = `已删除：${character.name}`;
      await this.reload();
    } catch (err) {
      this.errorText = `删除失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  // ---- UI ----

  @Builder
  pageTopBar() {
    PageHeader({
        title: this.mode === 'edit' ? '角色编辑' : this.mode === 'import' ? '导入角色卡' : '角色管理',
        subtitle: '每一个角色，都有自己的故事',
        onBack: () => {
            if (this.busy) { return; }
            if (this.mode !== 'list') {
              this.mode = 'list';
              this.form = undefined;
              return;
            }
            ROOT_PATH_STACK.pop();
        }
      }) {
        if (this.mode === 'list') {
        HeaderAction({ icon: $r('app.media.icon_add'), label: '添加角色', marker: 'characters-create-action', refresh: false,
          available: !this.busy, onAction: async (): Promise<void> => {
            this.addMenu.openMenu(this.getUIContext(), 'characters-create-action', 250, ['新建角色', '导入角色卡']);
          } })
        } else if (this.mode === 'edit') {
        Button('保存', { type: ButtonType.Normal })
        .fontSize(UIType.caption)
        .constraintSize({ minHeight: 44 })
        .enabled(!this.busy)
        .stateStyles({ normal: touchFeedbackNormal, pressed: touchFeedbackPressed })

        .onClick(() => {
        this.save();
        })
        .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      }
      }
  }

  @Builder
  buildSurfaceContent() {
      Column({ space: Spacing.sm }) {
        // 页头（玻璃）：返回 + 标题 + 右侧动作
        
  
        if (this.statusText !== '') {
          Text(this.statusText)
            .fontSize(Typography.caption)
            .fontColor(this.uiColors.textTertiary)
            .width('100%')
            .padding({ left: Spacing.md })
        }
  
        ErrorBannerView({ text: this.errorText })
  
        if (this.mode === 'import') {
          ImportPage({ embedded: true, showManagement: false,
            onImported: (character: CharacterDto): void => { this.openEdit(character); this.reload(); } })
        } else if (this.mode === 'edit') {
          this.editForm()
        } else {
          this.listView()
        }
      }
      .width('100%')
      .backgroundColor(this.uiColors.bgBase)
    }

  build() {
    Stack() {
    PageSurface({ topBar: () => { this.pageTopBar(); }, content: () => { this.buildSurfaceContent(); } })
    Column().width(0).height(0)
      .bindContentCover($$this.addMenu.presented, this.addMenuCover(), {
        modalTransition: ModalTransition.NONE, backgroundColor: Color.Transparent,
        onWillDismiss: (): void => { this.addMenu.close(); }, onDisappear: (): void => { this.addMenu.dismissed(); }
      })
    }.width('100%').height('100%')
  }

  @Builder
  addMenuCover() {
    OriginPanel({ state: this.addMenu, content: (): void => { this.addMenuContent(); } })
  }

  @Builder
  addMenuContent() {
    Scroll() {
    Column() {
      LiquidMenuItem({ label: '新建角色', onSelect: (): void => { this.addMenu.select((): void => { this.openCreate(); }); } })
      LiquidMenuItem({ label: '导入角色卡', onSelect: (): void => { this.addMenu.select((): void => { this.mode = 'import'; }); } })
    }.width('100%').padding(8).onAreaChange((_previous: Area, area: Area): void => { this.addMenu.fitMenuHeight(Number(area.height)); })
    }.width('100%').height('100%').scrollBar(BarState.Off)
  }

  @Builder
  listView() {
    TextInput({ text: this.query, placeholder: '搜索角色名称或描述' }).width('100%')
      .onChange((value: string): void => { this.query = value; }).id('character-search')
    if (this.loading) {
      EmptyHint('正在读取角色…', '', this.uiColors)
    } else if (this.characters.length === 0) {
      EmptyHint('还没有角色', '点右上角「新建」创建一个', this.uiColors)
    } else {
      Column({ space: Spacing.sm }) {
        ForEach(this.characters.filter((item: CharacterDto): boolean =>
          (item.name + ' ' + (item.description ?? '')).toLowerCase().includes(this.query.trim().toLowerCase())), (character: CharacterDto) => {
          Column() {
            Row({ space: Spacing.md }) {
              Column({ space: 2 }) {
                Text(character.name)
                  .fontSize(Typography.subtitle)
                  .fontColor(this.uiColors.textPrimary)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(character.description !== undefined && character.description !== ''
                  ? character.description
                  : (character.first_mes !== undefined ? character.first_mes : '（无描述）'))
                  .fontSize(Typography.micro)
                  .fontColor(this.uiColors.textTertiary)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Button() {
                Image($r('app.media.icon_more')).width(20).height(20).colorFilter(iconTint(this.uiColors.textSecondary))
              }
                .constraintSize({ minHeight: 44 })
                .width(44)
                .backgroundColor(Color.Transparent)
                .fontColor(this.uiColors.textSecondary)
                .id('character-options-' + character.name)
                .stateStyles({ normal: touchFeedbackNormal, pressed: touchFeedbackPressed })

                .onClick((): void => {
                  this.menuOrigin.openMenu(this.getUIContext(), 'character-options-' + character.name, 256, ['更换头像', '导出 JSON']);
                })
                .bindContentCover(this.menuOrigin.presented && this.menuOrigin.sourceId === 'character-options-' + character.name,
                  this.rowMenuCover(character), {
                  modalTransition: ModalTransition.NONE, backgroundColor: Color.Transparent,
                  onWillDismiss: (): void => { this.menuOrigin.close(); },
                  onDisappear: (): void => { this.menuOrigin.dismissed(); }
                })
            }
            .width('100%')
            .padding(Spacing.md)
            .borderRadius(GLASS_CARD.radius)
            .backgroundColor(this.uiColors.bgSurface)
            .border({ width: 1, color: this.uiColors.borderSubtle })
          }
          .stateStyles({ normal: touchFeedbackNormal, pressed: touchFeedbackPressed })

          .onClick(() => {
            this.openEdit(character);
          })
        }, (character: CharacterDto) => character.name)
      }
      .width('100%')
    }
  }

  @Builder
  editForm() {
    if (this.form !== undefined) {
      Column() {
        Column({ space: Spacing.md }) {
          SettingsPicker({ title: '编辑内容', marker: 'character-editor-section', selectedId: this.editorSection,
            options: [{ id: 'basic', label: '名称与描述' }, { id: 'story', label: '人格与场景' },
              { id: 'greetings', label: '开场白与对话示例' }, { id: 'prompts', label: '提示词' },
              { id: 'metadata', label: '作者、标签与版本' }],
            onSelect: (id: string): void => { this.editorSection = id; } })
          if (this.editorSection === 'basic') {
          SectionTitle('基本信息', this.uiColors)
          this.field('角色名', this.form!.name, (value: string) => {
            this.form!.name = value;
          })
          this.field('描述', this.form!.description, (value: string) => {
            this.form!.description = value;
          })
          }
          if (this.editorSection === 'story') {
          SectionTitle('人格与场景', this.uiColors)
          this.field('人格（personality）', this.form!.personality, (value: string) => {
            this.form!.personality = value;
          })
          this.field('场景（scenario）', this.form!.scenario, (value: string) => {
            this.form!.scenario = value;
          })
          }
          if (this.editorSection === 'greetings') {
          SectionTitle('开场白与示例', this.uiColors)
          this.field('开场白（first_mes）', this.form!.firstMes, (value: string) => {
            this.form!.firstMes = value;
          })
          this.field('对话示例（mes_example）', this.form!.mesExample, (value: string) => {
            this.form!.mesExample = value;
          })
          SectionTitle('备选开场白', this.uiColors)
          ForEach(this.form!.alternateGreetings, (greeting: string, index: number) => {
            Column({ space: 8 }) {
              TextArea({ text: greeting, placeholder: '备选开场白 ' + (index + 1) }).height(140)
                .attributeModifier(new TextAreaFieldStyle(this.uiColors)).id('character-alt-' + index)
                .onChange((value: string): void => { this.form!.alternateGreetings[index] = value; })
              Button('移除这段开场白').attributeModifier(new ActionButtonStyle(this.uiColors)).width('100%')
                .onClick((): void => { this.form!.alternateGreetings = this.form!.alternateGreetings.filter((_value: string, position: number): boolean => position !== index); })
            }.width('100%')
          }, (_greeting: string, index: number): string => String(index))
          Button('添加备选开场白').attributeModifier(new ActionButtonStyle(this.uiColors)).width('100%')
            .onClick((): void => { this.form!.alternateGreetings = [...this.form!.alternateGreetings, '']; })
          }
          if (this.editorSection === 'prompts') {
            this.field('系统提示词', this.form!.systemPrompt, (value: string): void => { this.form!.systemPrompt = value; })
            this.field('历史后指令', this.form!.postHistory, (value: string): void => { this.form!.postHistory = value; })
          }
          if (this.editorSection === 'metadata') {
            this.field('作者', this.form!.creator, (value: string): void => { this.form!.creator = value; })
            this.field('作者备注', this.form!.creatorNotes, (value: string): void => { this.form!.creatorNotes = value; })
            this.field('角色卡版本', this.form!.version, (value: string): void => { this.form!.version = value; })
            this.field('标签（逗号分隔）', this.form!.tags, (value: string): void => { this.form!.tags = value; })
          }
          Text('提示：角色名修改后会同步重命名角色文件；描述/人格/场景/开场白保存后立即生效。')
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
  }

  /** 多行输入字段（表单复用）。 */
  @Builder
  field(label: string, value: string, onChange: (value: string) => void) {
    Column({ space: Spacing.xs }) {
      Text(label)
        .fontSize(Typography.caption)
        .fontColor(this.uiColors.textSecondary)
        .width('100%')
      TextArea({ text: value, placeholder: label })
        .fontColor(this.uiColors.textPrimary)
        .placeholderColor(this.uiColors.textTertiary)
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(UIRadius.sm)
        .fontSize(Typography.body)
        .fontColor(this.uiColors.textPrimary)
        .height(value.length > 40 ? 180 : 80)
        .width('100%')
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(Radius.sm)
        .onChange((next: string) => {
          onChange(next);
        })
    .attributeModifier(new TextAreaFieldStyle(this.uiColors))
      }
    .width('100%')
  }
}
