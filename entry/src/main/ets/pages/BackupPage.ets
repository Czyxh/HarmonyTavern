import { ActionButtonStyle, ActionTone } from '../theme/ControlStyles';
import { HeaderAction } from '../components/HeaderAction';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { PageSurface } from '../components/PageSurface';
import { SCROLL_EDGE_OPTIONS, SCROLL_NESTED_OPTIONS } from '../theme/ScrollFeedback';
import { Radius as UIRadius, Typography as UIType } from '../theme/Tokens';
import { PageHeader } from '../components/PageHeader';
// 备份中心（P8-15）：对应原项目 Settings 应用里的「聊天备份管理」。
//
// 数据形状：
//   list_chat_backup_catalog → [{ file_name, stored_size, backup_date, message_count? }]
//   get_chat_backup_storage_stats → { original_bytes, stored_bytes } | null
//   backup_chat(characterName, fileName) → void
//   restore_character_chat_backup({ backup_name, character_name, character_display_name }) → string
//   delete_chat_backup(name) → void
//
// 流程：选角色 → 选该角色某个会话 → 备份；或从备份目录里选一条 → 恢复 / 删除。
//
// 对应 DevEco 工程路径：entry/src/main/ets/pages/BackupPage.ets
import { Backend, BackendError } from '../backend/Backend';
import { CharacterDto, ChatDto } from '../backend/Types';
import { ChatBackupCatalogEntry } from '../backend/AdminTypes';
import { ROOT_PATH_STACK } from '../nav/RootNav';
import { Radius, Spacing, Typography } from '../theme/Tokens';
import { GLASS_CARD, GLASS_HEADER, glassEffect } from '../theme/Glass';
import { EmptyHint, ErrorBannerView, SectionTitle } from '../components/Builders';

@Component
export struct BackupPage {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @State loading: boolean = true;
  @State busy: boolean = false;
  @State errorText: string = '';
  @State statusText: string = '';

  @State originalBytes: number = 0;
  @State storedBytes: number = 0;
  @State catalog: ChatBackupCatalogEntry[] = [];

  @State characters: CharacterDto[] = [];
  @State selectedCharacter: string = '';
  @State chats: ChatDto[] = [];

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
      const stats = await Backend.getChatBackupStorageStats();
      this.originalBytes = stats === null ? 0 : stats.original_bytes;
      this.storedBytes = stats === null ? 0 : stats.stored_bytes;
      this.catalog = await Backend.listChatBackupCatalog();
      this.characters = await Backend.getAllCharacters();
      if (this.selectedCharacter === '' && this.characters.length > 0) {
        this.selectedCharacter = this.characters[0].name;
        await this.loadChats(this.selectedCharacter);
      } else if (this.selectedCharacter !== '') {
        await this.loadChats(this.selectedCharacter);
      }
    } catch (err) {
      this.errorText = `读取备份失败：${(err as BackendError).message}`;
    } finally {
      this.loading = false;
    }
  }

  async loadChats(character: string): Promise<void> {
    try {
      this.chats = await Backend.getCharacterChats(character);
    } catch (err) {
      this.chats = [];
    }
    if (this.chats.length === 0) {
      // 有些会话在别名存储里，get_character_chats 拿不到——退回全量列表按角色名过滤。
      try {
        const all: ChatDto[] = await Backend.getAllChats();
        const filtered: ChatDto[] = [];
        for (let i = 0; i < all.length; i++) {
          if (all[i].character_name === character) {
            filtered.push(all[i]);
          }
        }
        this.chats = filtered;
      } catch (err) {
        // 保持空
      }
    }
  }

  async pickCharacter(name: string): Promise<void> {
    this.selectedCharacter = name;
    this.chats = [];
    await this.loadChats(name);
  }

  async createBackup(chat: ChatDto): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      await Backend.backupChat(chat.character_name, chat.file_name);
      this.statusText = `已备份 ${chat.file_name}`;
      await this.reload();
    } catch (err) {
      this.errorText = `备份失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async restore(entry: ChatBackupCatalogEntry): Promise<void> {
    if (this.selectedCharacter === '') {
      this.errorText = '恢复前先在下面选一个角色（备份文件本身不带角色信息）';
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      const display: string = this.selectedCharacter;
      const result: string = await Backend.restoreCharacterChatBackup({
        backup_name: entry.file_name,
        character_name: this.selectedCharacter,
        character_display_name: display
      });
      this.statusText = `已恢复到 ${result}`;
      await this.reload();
    } catch (err) {
      this.errorText = `恢复失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async remove(entry: ChatBackupCatalogEntry): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      await Backend.deleteChatBackup(entry.file_name);
      this.statusText = `已删除备份 ${entry.file_name}`;
      await this.reload();
    } catch (err) {
      this.errorText = `删除失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  @Builder
  pageTopBar() {
    PageHeader({
        title: '备份',
        subtitle: '为每一段故事保留副本',
        onBack: () => {
            ROOT_PATH_STACK.pop();
        }
      }) {
        HeaderAction({ label: '刷新', marker: 'backuppage-refresh-1', available: !this.busy,
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
            .padding({ left: Spacing.md })
        }
        ErrorBannerView({ text: this.errorText })
  
        Column() {
          Column({ space: Spacing.md }) {
            if (this.loading) {
              Text('读取中…').fontSize(Typography.caption).fontColor(this.uiColors.textTertiary)
            } else {
              this.statsCard()
              this.catalogCard()
              this.createCard()
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
  statsCard() {
    Column({ space: 4 }) {
      SectionTitle('存储占用', this.uiColors)
      Text(`原始 ${this.fmtBytes(this.originalBytes)} · 实际 ${this.fmtBytes(this.storedBytes)}`)
        .fontSize(Typography.caption)
        .fontColor(this.uiColors.textSecondary)
        .width('100%')
      Text(this.originalBytes > 0
        ? `压缩比 ${(this.storedBytes * 100 / this.originalBytes).toFixed(1)}%`
        : '还没有备份数据')
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
  catalogCard() {
    Column({ space: Spacing.sm }) {
      SectionTitle(`备份文件（${this.catalog.length}）`, this.uiColors)
      if (this.catalog.length === 0) {
        EmptyHint('没有备份文件', '在下面「新建备份」里挑一个会话备份', this.uiColors)
      } else {
        ForEach(this.catalog, (entry: ChatBackupCatalogEntry) => {
          Column({ space: 4 }) {
            Text(entry.file_name)
              .fontSize(Typography.micro)
              .fontColor(this.uiColors.textPrimary)
              .width('100%')
              .maxLines(2)
            Text(`${this.fmtBytes(entry.stored_size)} · ${this.fmtDate(entry.backup_date)}`
              + `${entry.message_count !== undefined ? ' · ' + entry.message_count + ' 条消息' : ''}`)
              .fontSize(Typography.micro)
              .fontColor(this.uiColors.textTertiary)
              .width('100%')
            Row({ space: Spacing.sm }) {
              Button(`恢复到「${this.selectedCharacter === '' ? '未选角色' : this.selectedCharacter}」`, { type: ButtonType.Normal })
                .fontSize(UIType.micro)
                .constraintSize({ minHeight: 44 })
                .layoutWeight(1)
                .enabled(!this.busy && this.selectedCharacter !== '')
                .onClick(() => {
                  this.restore(entry);
                })
              .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      Button('删除', { type: ButtonType.Normal })
                .fontSize(UIType.micro)
                .constraintSize({ minHeight: 44 })
                .backgroundColor(this.uiColors.danger)
                .enabled(!this.busy)
                .onClick(() => {
                  this.remove(entry);
                })
            .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Danger))
      }
            .width('100%')
          }
          .width('100%')
          .padding({ top: 6, bottom: 6 })
        }, (entry: ChatBackupCatalogEntry) => `${entry.file_name}|${entry.backup_date}`)
      }
    }
    .width('100%')
    .padding(Spacing.md)
    .borderRadius(GLASS_CARD.radius)
    .backgroundColor(this.uiColors.bgSurface)
    .border({ width: 1, color: this.uiColors.borderSubtle })
  }

  @Builder
  createCard() {
    Column({ space: Spacing.sm }) {
      SectionTitle('新建备份', this.uiColors)
      Text('角色')
        .fontSize(Typography.micro)
        .fontColor(this.uiColors.textTertiary)
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
                this.pickCharacter(character.name);
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

      if (this.chats.length === 0) {
        Text('这个角色还没有会话')
          .fontSize(Typography.micro)
          .fontColor(this.uiColors.textTertiary)
          .width('100%')
      } else {
        ForEach(this.chats, (chat: ChatDto) => {
          Row({ space: Spacing.sm }) {
            Text(chat.file_name)
              .fontSize(Typography.micro)
              .fontColor(this.uiColors.textSecondary)
              .layoutWeight(1)
              .maxLines(1)
            Button('备份', { type: ButtonType.Normal })
              .fontSize(UIType.micro)
              .constraintSize({ minHeight: 44 })
              .enabled(!this.busy)
              .onClick(() => {
                this.createBackup(chat);
              })
          .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
          .width('100%')
        }, (chat: ChatDto) => `${chat.character_name}|${chat.file_name}`)
      }
    }
    .width('100%')
    .padding(Spacing.md)
    .borderRadius(GLASS_CARD.radius)
    .backgroundColor(this.uiColors.bgSurface)
    .border({ width: 1, color: this.uiColors.borderSubtle })
  }

  fmtBytes(bytes: number): string {
    if (bytes < 1024) {
      return `${bytes} B`;
    }
    if (bytes < 1024 * 1024) {
      return `${(bytes / 1024).toFixed(1)} KB`;
    }
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  }

  fmtDate(ms: number): string {
    if (ms === 0) {
      return '未知时间';
    }
    const date: Date = new Date(ms);
    return `${date.getFullYear()}-${this.pad(date.getMonth() + 1)}-${this.pad(date.getDate())} `
      + `${this.pad(date.getHours())}:${this.pad(date.getMinutes())}`;
  }

  pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }
}
