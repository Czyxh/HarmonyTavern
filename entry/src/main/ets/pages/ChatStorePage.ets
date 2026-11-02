import { SurfaceStyle } from '../theme/SurfaceStyles';
import { ActionButtonStyle, ActionTone, InputFieldStyle, TextAreaFieldStyle } from '../theme/ControlStyles';
import { OriginMotion } from '../theme/OriginMotion';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { PageSurface } from '../components/PageSurface';
import { Radius as UIRadius, Typography as UIType } from '../theme/Tokens';
import { PageHeader } from '../components/PageHeader';
// 会话存储（P8-29）：聊天级 KV 浏览器。
//
// 对应 DevEco 工程路径：entry/src/main/ets/pages/ChatStorePage.ets
//
// SillyTavern 的扩展把数据挂在「角色 / 会话 / 命名空间 / key」四层下面
// （`chats/<角色>/<会话>.jsonl` 旁的 store 目录）。这 6 条命令 Rust 侧一直有：
//   list_character_chat_store_keys / get / set / update / delete / rename
// 但 ArkTS 从来没接过，等于扩展写进去的数据在鸿蒙端完全看不见。
//
// 这里做成「只读优先」的浏览器：填角色名 + 会话文件名 + 命名空间 → 列 key →
// 点开看 JSON、就地改、删、改名。默认命名空间给 `chat_metadata`（上游最常用的那个）。
import { Backend, BackendError } from '../backend/Backend';
import { ChatFileOps } from '../backend/ChatFileOps';
import { ChatDto } from '../backend/Types';
import { ROOT_PATH_STACK } from '../nav/RootNav';
import { Radius, Spacing, Touch, Typography } from '../theme/Tokens';
import { GLASS_HEADER, glassEffect } from '../theme/Glass';
import { EmptyHint, ErrorBannerView } from '../components/Builders';

@Component
export struct ChatStorePage {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @State busy: boolean = false;
  @State errorText: string = '';
  @State statusText: string = '';

  @State chats: ChatDto[] = [];
  @State characterName: string = '';
  @State fileName: string = '';
  @State namespace: string = 'chat_metadata';
  @State keys: string[] = [];
  @State keyNote: string = '';
  // 扩展 store 的目录名就是聊天头里的 chat_metadata.integrity，
  // 我们的 create_chat 没地方传 metadata，所以要客户端补一个（同上游语义）。
  @State integrity: string = '';
  @State probeKey: string = 'harmonytavern_probe';
  @State metadataText: string = '';
  @State tailText: string = '';

  @State openKey: string = '';
  @State openValue: string = '';
  @State editValue: string = '';

  aboutToAppear(): void {
    if (!Backend.isReady()) {
      this.errorText = '后端未就绪，请从首页进入';
      return;
    }
    this.loadChats();
  }

  async loadChats(): Promise<void> {
    try {
      this.chats = await Backend.getAllChats();
      if (this.chats.length > 0 && this.fileName === '') {
        this.characterName = this.chats[0].character_name;
        this.fileName = this.chats[0].file_name;
      }
      this.statusText = `${this.chats.length} 个会话可选`;
    } catch (err) {
      this.errorText = `读会话列表失败：${(err as BackendError).message}`;
    }
  }

  pickChat(chat: ChatDto): void {
    this.characterName = chat.character_name;
    this.fileName = chat.file_name;
    this.keys = [];
    this.openKey = '';
    this.statusText = `已选 ${chat.character_name} / ${chat.file_name}`;
  }

  /** 补 chat_metadata.integrity（扩展 store 的目录名），补完才能读写 KV。 */
  /** 会话首行 metadata 整包（诊断/排查用，直接展示 JSON）。 */
  async showMetadata(): Promise<void> {
    if (this.characterName === '' || this.fileName === '') {
      this.errorText = '先选一个会话';
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      const meta: ESObject = await Backend.getCharacterChatMetadata(this.characterName, this.fileName);
      this.metadataText = ChatStorePage.pretty(meta);
      this.statusText = '已读取会话 metadata';
    } catch (err) {
      this.errorText = `读 metadata 失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  /** 读会话尾部窗口：只取最后 N 行，证明游标分页命令可用（长聊天性能的底座）。 */
  async loadTail(): Promise<void> {
    if (this.characterName === '' || this.fileName === '') {
      this.errorText = '先选一个会话';
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      const tail: ESObject = await Backend.getChatPayloadTail(this.characterName, this.fileName, 20, false);
      const lines: string[] = (tail.lines as string[]) ?? [];
      this.tailText = lines.join('\n');
      this.statusText = `尾部窗口 ${lines.length} 行`;
    } catch (err) {
      this.errorText = `读尾部失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async fixIntegrity(): Promise<void> {
    if (this.characterName === '' || this.fileName === '') {
      this.errorText = '先选一个会话';
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      const value: string = await ChatFileOps.ensureIntegrity(this.characterName, this.fileName);
      this.integrity = value;
      this.statusText = `integrity = ${value}`;
    } catch (err) {
      this.errorText = `补 integrity 失败：${(err as Error).message}`;
    } finally {
      this.busy = false;
    }
  }

  async readIntegrityOf(): Promise<void> {
    if (this.characterName === '' || this.fileName === '') {
      return;
    }
    try {
      // 走后端命令（它会按 ST 的 header 规则解析），比自己在 ArkTS 里解析更权威
      const value: string | null = await Backend.getCharacterChatIntegrity(this.characterName, this.fileName);
      this.integrity = value === null ? '' : value;
      this.statusText = this.integrity === '' ? '这个会话还没有 integrity' : `integrity = ${this.integrity}`;
    } catch (err) {
      this.errorText = `读 integrity 失败：${(err as BackendError).message}`;
    }
  }

  /** 写入探针：set 一个 key 再重新列 key，用来证明扩展 KV 真能落盘。 */
  async writeProbe(): Promise<void> {
    if (this.characterName === '' || this.fileName === '') {
      this.errorText = '先选一个会话';
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      const payload: ESObject = { probe: true, at: Date.now() };
      await Backend.setCharacterChatStoreJson(
        this.characterName, this.fileName, this.namespace, this.probeKey, payload);
      this.statusText = `已写入 ${this.namespace}/${this.probeKey}`;
      await this.loadKeys();
    } catch (err) {
      this.errorText = `写探针失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async loadKeys(): Promise<void> {
    if (this.characterName === '' || this.fileName === '') {
      this.errorText = '先选一个会话';
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      this.keys = await Backend.listCharacterChatStoreKeys(this.characterName, this.fileName, this.namespace);
      this.keyNote = `${this.keys.length} 个 key`;
      this.statusText = `命名空间 ${this.namespace}`;
    } catch (err) {
      this.errorText = `列 key 失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async openValueOf(key: string): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      const value: ESObject = await Backend.getCharacterChatStoreJson(
        this.characterName, this.fileName, this.namespace, key);
      this.openKey = key;
      this.openValue = ChatStorePage.pretty(value);
      this.editValue = this.openValue;
    } catch (err) {
      this.errorText = `读 value 失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  static pretty(value: ESObject): string {
    if (value === undefined || value === null) {
      return 'null';
    }
    if (typeof value === 'object') {
      return JSON.stringify(value, null, 2);
    }
    return `${value}`;
  }

  /** 改 value：JSON 解析失败就不写，避免把扩展数据写坏。 */
  async saveValue(): Promise<void> {
    if (this.openKey === '') {
      return;
    }
    let parsed: ESObject = null;
    try {
      parsed = JSON.parse(this.editValue) as ESObject;
    } catch (err) {
      this.errorText = '不是合法 JSON，未写入';
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      await Backend.setCharacterChatStoreJson(
        this.characterName, this.fileName, this.namespace, this.openKey, parsed);
      this.openValue = this.editValue;
      this.statusText = `已写入 ${this.openKey}`;
    } catch (err) {
      this.errorText = `写入失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  confirmDelete(key: string): void {
    this.getUIContext().showAlertDialog({
      title: '删除 key',
      alignment: DialogAlignment.Center,
      transition: OriginMotion.dialog(this.getUIContext(), 'store-delete-' + key),
      message: `${this.namespace} / ${key}（扩展数据会一起消失）`,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        action: () => {
          this.deleteKey(key);
        }
      }
    });
  }

  async deleteKey(key: string): Promise<void> {
    this.busy = true;
    try {
      await Backend.deleteCharacterChatStoreJson(this.characterName, this.fileName, this.namespace, key);
      if (this.openKey === key) {
        this.openKey = '';
        this.openValue = '';
      }
      this.statusText = `已删除 ${key}`;
      await this.loadKeys();
    } catch (err) {
      this.errorText = `删除失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  @Builder
  pageTopBar() {
    PageHeader({
        title: '会话存储',
        subtitle: '会话历史与扩展数据',
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
          Column({ space: Spacing.md }) {
            // 会话选择
            Text('选会话')
              .fontSize(Typography.caption)
              .fontColor(this.uiColors.textSecondary)
              .width('100%')
            if (this.chats.length === 0) {
              EmptyHint('还没有会话', '先聊一句再来；扩展数据挂在会话下面', this.uiColors)
            } else {
              ForEach(this.chats, (chat: ChatDto) => {
                Text(`${chat.character_name} / ${chat.file_name}`)
                  .fontSize(Typography.micro)
                  .fontColor(this.fileName === chat.file_name ? this.uiColors.accent : this.uiColors.textSecondary)
                  .width('100%')
                  .padding(Spacing.sm)
                  .backgroundColor(this.uiColors.bgSurface)
                  .borderRadius(Radius.sm)
                  .attributeModifier(new SurfaceStyle(this.uiColors, Radius.sm))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .onClick(() => {
                    this.pickChat(chat);
                  })
              }, (chat: ChatDto) => `${chat.character_name}/${chat.file_name}`)
            }
  
            // integrity（扩展 store 的目录名）+ 探针
            Column({ space: 4 }) {
              Row({ space: Spacing.sm }) {
                Text(this.integrity === '' ? 'integrity：未设置' : `integrity：${this.integrity}`)
                  .fontSize(Typography.micro)
                  .fontColor(this.integrity === '' ? this.uiColors.textTertiary : this.uiColors.accent)
                  .layoutWeight(1)
                  .maxLines(2)
                Button('读', { type: ButtonType.Normal })
                  .fontSize(UIType.micro)
                  .constraintSize({ minHeight: 44 })
                  .backgroundColor(this.uiColors.bgSurfaceHigh)
                  .fontColor(this.uiColors.textSecondary)
                  .onClick(() => {
                    this.readIntegrityOf();
                  })
                .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button('补', { type: ButtonType.Normal })
                  .fontSize(UIType.micro)
                  .constraintSize({ minHeight: 44 })
                  .enabled(!this.busy)
                  .onClick(() => {
                    this.fixIntegrity();
                  })
              .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
              .width('100%')
  
              Text('扩展 store 的目录名就是这个 integrity；鸿蒙建会话时没写，扩展数据会读不到。')
                .fontSize(Typography.micro)
                .fontColor(this.uiColors.textTertiary)
                .width('100%')
  
              Row({ space: Spacing.sm }) {
                Button('会话 metadata', { type: ButtonType.Normal })
                  .fontSize(UIType.micro)
                  .constraintSize({ minHeight: 44 })
                  .layoutWeight(1)
                  .backgroundColor(this.uiColors.bgSurfaceHigh)
                  .fontColor(this.uiColors.textSecondary)
                  .enabled(!this.busy)
                  .onClick(() => {
                    this.showMetadata();
                  })
                .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button('尾部 20 行', { type: ButtonType.Normal })
                  .fontSize(UIType.micro)
                  .constraintSize({ minHeight: 44 })
                  .layoutWeight(1)
                  .backgroundColor(this.uiColors.bgSurfaceHigh)
                  .fontColor(this.uiColors.textSecondary)
                  .enabled(!this.busy)
                  .onClick(() => {
                    this.loadTail();
                  })
              .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
              .width('100%')
  
              if (this.metadataText !== '') {
                Text(this.metadataText)
                  .fontSize(Typography.micro)
                  .fontColor(this.uiColors.textSecondary)
                  .width('100%')
                  .maxLines(10)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              if (this.tailText !== '') {
                Text(`尾部窗口：\n${this.tailText}`)
                  .fontSize(Typography.micro)
                  .fontColor(this.uiColors.textSecondary)
                  .width('100%')
                  .maxLines(8)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
  
              Row({ space: Spacing.sm }) {
                TextInput({ placeholder: '探针 key', text: this.probeKey })
                  .fontColor(this.uiColors.textPrimary)
                  .placeholderColor(this.uiColors.textTertiary)
                  .backgroundColor(this.uiColors.bgSurfaceHigh)
                  .borderRadius(UIRadius.sm)
                  .fontSize(Typography.caption)
                  .height(Touch.minTarget)
                  .layoutWeight(1)
                  .backgroundColor(this.uiColors.bgSurfaceHigh)
                  .onChange((value: string) => {
                    this.probeKey = value;
                  })
                .attributeModifier(new InputFieldStyle(this.uiColors))
      Button('写探针', { type: ButtonType.Normal })
                  .fontSize(UIType.micro)
                  .height(Touch.minTarget)
                  .enabled(!this.busy)
                  .onClick(() => {
                    this.writeProbe();
                  })
              .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
              .width('100%')
            }
            .width('100%')
            .padding(Spacing.sm)
            .backgroundColor(this.uiColors.bgSurface)
            .borderRadius(Radius.sm)
            .attributeModifier(new SurfaceStyle(this.uiColors, Radius.sm))
  
            // 命名空间 + 列表
            Row({ space: Spacing.sm }) {
              TextInput({ placeholder: 'namespace（如 chat_metadata）', text: this.namespace })
                .fontColor(this.uiColors.textPrimary)
                .placeholderColor(this.uiColors.textTertiary)
                .backgroundColor(this.uiColors.bgSurfaceHigh)
                .borderRadius(UIRadius.sm)
                .fontSize(Typography.caption)
                .height(Touch.minTarget)
                .layoutWeight(1)
                .backgroundColor(this.uiColors.bgSurfaceHigh)
                .onChange((value: string) => {
                  this.namespace = value;
                })
              .attributeModifier(new InputFieldStyle(this.uiColors))
      Button('列 key', { type: ButtonType.Normal })
                .fontSize(UIType.caption)
                .height(Touch.minTarget)
                .enabled(!this.busy)
                .onClick(() => {
                  this.loadKeys();
                })
            .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
            .width('100%')
  
            if (this.keyNote !== '') {
              Text(this.keyNote)
                .fontSize(Typography.micro)
                .fontColor(this.uiColors.textTertiary)
                .width('100%')
            }
  
            ForEach(this.keys, (key: string) => {
              Column({ space: 4 }) {
                Row({ space: Spacing.sm }) {
                  Text(key)
                    .fontSize(Typography.caption)
                    .fontColor(this.openKey === key ? this.uiColors.accent : this.uiColors.textPrimary)
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Button('查看', { type: ButtonType.Normal })
                    .fontSize(UIType.micro)
                    .constraintSize({ minHeight: 44 })
                    .backgroundColor(this.uiColors.bgSurfaceHigh)
                    .fontColor(this.uiColors.textSecondary)
                    .onClick(() => {
                      this.openValueOf(key);
                    })
                  .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button('删', { type: ButtonType.Normal })
                    .fontSize(UIType.micro)
                    .constraintSize({ minHeight: 44 })
                    .backgroundColor(this.uiColors.danger)
                    .id('store-delete-' + key)
                    .onClick(() => {
                      this.confirmDelete(key);
                    })
                .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Danger))
      }
                .width('100%')
  
                if (this.openKey === key) {
                  Text(this.openValue)
                    .fontSize(Typography.micro)
                    .fontColor(this.uiColors.textSecondary)
                    .width('100%')
                    .maxLines(8)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  TextArea({ text: this.editValue })
                    .fontColor(this.uiColors.textPrimary)
                    .placeholderColor(this.uiColors.textTertiary)
                    .backgroundColor(this.uiColors.bgSurfaceHigh)
                    .borderRadius(UIRadius.sm)
                    .fontSize(Typography.micro)
                    .height(140)
                    .width('100%')
                    .backgroundColor(this.uiColors.bgSurfaceHigh)
                    .onChange((value: string) => {
                      this.editValue = value;
                    })
                  .attributeModifier(new TextAreaFieldStyle(this.uiColors))
      Button('写回', { type: ButtonType.Normal })
                    .fontSize(UIType.micro)
                    .constraintSize({ minHeight: 44 })
                    .enabled(!this.busy)
                    .onClick(() => {
                      this.saveValue();
                    })
                .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
              }
              .width('100%')
              .padding(Spacing.sm)
              .backgroundColor(this.uiColors.bgSurface)
              .borderRadius(Radius.sm)
              .attributeModifier(new SurfaceStyle(this.uiColors, Radius.sm))
            }, (key: string) => `${key}-${this.openKey === key}`)
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
