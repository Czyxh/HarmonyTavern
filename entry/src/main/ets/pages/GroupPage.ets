import { SurfaceStyle } from '../theme/SurfaceStyles';
import { ActionButtonStyle, ActionTone, InputFieldStyle } from '../theme/ControlStyles';
import { HeaderAction } from '../components/HeaderAction';
import { OriginMotion } from '../theme/OriginMotion';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { PageSurface } from '../components/PageSurface';
import { SettingsPicker } from '../components/SettingsPicker';
import { Radius as UIRadius, Typography as UIType } from '../theme/Tokens';
import { PageHeader } from '../components/PageHeader';
// 群聊（P8-23）：群组列表 + 成员 + 群聊会话。
//
// 对应 DevEco 工程路径：entry/src/main/ets/pages/GroupPage.ets
//
// 和世界书同源的问题：`GroupService` / `GroupChatService` 在 Rust 里齐全，
// host 层一条命令都没有。这轮补了 12 条：
//   get_all_groups / get_group / create_group / update_group / delete_group
//   list_group_chat_summaries / search_group_chats / get_group_chat_metadata
//   get_group_chat_payload_path / rename_group_chat / delete_group_chat / clear_group_chat_cache
//
// 说明：「谁下一个说话」是 SillyTavern 前端逻辑，Rust 只存 activationStrategy / generationMode。
// 所以这里的群聊面板做的是「群配置 + 成员 + 会话管理」，生成仍走普通 chat completion。
import { Backend, BackendError } from '../backend/Backend';
import { CharacterDto } from '../backend/Types';
import { GroupIntent, ROOT_PATH_STACK } from '../nav/RootNav';
import { GroupSession, GroupConversationIntent } from '../backend/GroupSession';
import { Radius, Spacing, Touch, Typography } from '../theme/Tokens';
import { GLASS_HEADER, glassEffect } from '../theme/Glass';
import { EmptyHint, ErrorBannerView } from '../components/Builders';

interface ChatSummaryView {
  chatId: string;
  fileName: string;
  preview: string;
  messageCount: number;
}

@Component
export struct GroupPage {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @State loading: boolean = true;
  @State busy: boolean = false;
  @State errorText: string = '';
  @State statusText: string = '';

  @State groups: ESObject[] = [];
  @State selected: string = '';
  @State groupName: string = '';
  @State members: string[] = [];
  @State disabledMembers: string[] = [];
  @State characters: CharacterDto[] = [];
  @State chats: ChatSummaryView[] = [];
  @State newGroupName: string = '';
  @State strategy: number = 1;
  @State renameId: string = '';
  @State renameText: string = '';

  aboutToAppear(): void {
    if (!Backend.isReady()) {
      this.errorText = '后端未就绪，请从首页进入';
      this.loading = false;
      return;
    }
    const id: string = GroupIntent.groupId;
    GroupIntent.groupId = ''; GroupIntent.creating = false;
    this.reload().then((): void => { if (id !== '') { this.openGroupById(id); } });
  }

  async reload(): Promise<void> {
    this.loading = true;
    this.errorText = '';
    try {
      this.groups = await Backend.getAllGroups();
      this.characters = await Backend.getAllCharacters();
      this.statusText = `${this.groups.length} 个群组`;
      if (this.selected !== '') {
        const still: boolean = this.groups.some((item: ESObject) => (item.id as string) === this.selected);
        if (!still) {
          this.selected = '';
          this.chats = [];
        }
      }
    } catch (err) {
      this.errorText = `读取失败：${(err as BackendError).message}`;
    } finally {
      this.loading = false;
    }
  }

  groupTitle(group: ESObject): string {
    const name: string = group.name as string;
    const count: number = (group.members as string[]).length;
    return `${name} · ${count} 位成员`;
  }

  async openGroup(group: ESObject): Promise<void> {
    this.selected = group.id as string;
    this.groupName = group.name as string;
    this.members = group.members as string[];
    this.disabledMembers = (group.disabled_members as string[]) ?? [];
    this.strategy = (group.activation_strategy as number) ?? 1;
    this.busy = true;
    this.errorText = '';
    try {
      const chatIds: string[] = (group.chats as string[]) ?? [];
      const summaries: ESObject[] = await Backend.listGroupChatSummaries(chatIds, false);
      const views: ChatSummaryView[] = [];
      for (let i = 0; i < summaries.length; i++) {
        const row: ESObject = summaries[i];
        views.push({
          chatId: (row.file_name as string) ?? '',
          fileName: (row.file_name as string) ?? '',
          preview: (row.preview as string) ?? (row.preview_message as string) ?? '',
          messageCount: (row.message_count as number) ?? 0
        });
      }
      this.chats = views;
      this.statusText = `${this.groupName} · ${views.length} 个群聊`;
    } catch (err) {
      this.errorText = `读取群聊失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  /** 建群：成员先空，建完再逐个加。 */
  async createGroup(): Promise<void> {
    const name: string = this.newGroupName.trim();
    if (name === '') {
      this.errorText = '先输入群名';
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      const members: string[] = [];
      const dto: ESObject = { name: name, members: members, activation_strategy: 1 };
      const created: ESObject = await Backend.createGroup(dto);
      this.newGroupName = '';
      this.getUIContext().getFocusController().clearFocus();
      this.statusText = `已创建群组 ${(created.id as string) ?? ''}`;
      await this.reload();
      await this.openGroup(created);
    } catch (err) {
      this.errorText = `建群失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  /** 改群：把整个 group 对象读回来改 members，再整包写回（上游 groups/edit 语义）。 */
  async toggleMember(character: CharacterDto, join: boolean): Promise<void> {
    if (this.selected === '') {
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      const group: ESObject = await Backend.getGroup(this.selected);
      const avatar: string = character.avatar ?? ``;
      const current: string[] = (group.members as string[]) ?? [];
      const next: string[] = [];
      for (let i = 0; i < current.length; i++) {
        if (current[i] !== avatar) {
          next.push(current[i]);
        }
      }
      if (join) {
        next.push(avatar);
      }
      group.members = next;
      group.disabled_members = ((group.disabled_members as string[]) || []).filter((key: string) => next.includes(key));
      await Backend.updateGroup(group);
      this.statusText = join ? `已把 ${character.name} 加入群` : `已把 ${character.name} 移出群`;
      await this.reload();
      await this.openGroup(group);
    } catch (err) {
      this.errorText = `改成员失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  isMember(character: CharacterDto): boolean {
    for (let i = 0; i < this.members.length; i++) {
      if (this.members[i] === (character.avatar ?? ``)) {
        return true;
      }
    }
    return false;
  }

  confirmDeleteGroup(group: ESObject): void {
    const name: string = group.name as string;
    const id: string = group.id as string;
    this.getUIContext().showAlertDialog({
      title: '删除群组',
      alignment: DialogAlignment.Center,
      transition: OriginMotion.dialog(this.getUIContext(), 'group-delete-' + id),
      message: `确定删除「${name}」及其关联聊天记录？此操作无法撤销。`,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        action: () => {
          this.deleteGroup(id);
        }
      }
    });
  }

  async deleteGroup(id: string): Promise<void> {
    this.busy = true;
    try {
      await Backend.deleteGroup(id);
      if (this.selected === id) {
        this.selected = '';
        this.chats = [];
      }
      this.statusText = '群组已删除';
      await this.reload();
    } catch (err) {
      this.errorText = `删除失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  confirmDeleteChat(chat: ChatSummaryView): void {
    this.getUIContext().showAlertDialog({
      title: '删除群聊',
      alignment: DialogAlignment.Center,
      transition: OriginMotion.dialog(this.getUIContext(), 'group-chat-delete-' + chat.chatId),
      message: `${chat.fileName}（${chat.messageCount} 条消息）`,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        action: () => {
          this.deleteChat(chat.chatId);
        }
      }
    });
  }

  async deleteChat(chatId: string): Promise<void> {
    this.busy = true;
    try {
      await Backend.deleteGroupChat(chatId);
      const current: ESObject = await Backend.getGroup(this.selected);
      current.chats = ((current.chats as string[]) || []).filter((id: string) => id.replace(/\.jsonl$/, '') !== chatId.replace(/\.jsonl$/, ''));
      if ((current.chat_id as string).replace(/\.jsonl$/, '') === chatId.replace(/\.jsonl$/, '')) {
        current.chat_id = ((current.chats as string[]) || [])[0] || '';
      }
      await Backend.updateGroup(current);
      await Backend.clearGroupChatCache();
      this.statusText = `已删除群聊 ${chatId}`;
      await this.reload();
      const group: ESObject = await Backend.getGroup(this.selected);
      await this.openGroup(group);
    } catch (err) {
      this.errorText = `删除群聊失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async renameChat(chat: ChatSummaryView): Promise<void> {
    this.renameId = chat.fileName;
    this.renameText = chat.fileName.replace(/\.jsonl$/, '');
  }

  async openGroupById(id: string): Promise<void> {
    try { await this.openGroup(await Backend.getGroup(id)); }
    catch (error) { this.errorText = (error as Error).message; }
  }
  async saveGroup(): Promise<void> {
    if (this.busy || !this.selected || !this.groupName.trim()) { return; }
    this.busy = true; this.errorText = '';
    try {
      const group: ESObject = await Backend.getGroup(this.selected);
      group.name = this.groupName.trim(); group.activation_strategy = this.strategy;
      group.disabled_members = this.disabledMembers;
      await Backend.updateGroup(group); await this.reload();
      this.statusText = '群聊设置已保存';
    } catch (error) { this.errorText = (error as Error).message; }
    finally { this.busy = false; }
  }
  enterChat(chatId: string): void {
    GroupConversationIntent.request(this.selected, chatId);
    ROOT_PATH_STACK.pushPathByName('pages/GroupChatPage', null);
  }
  async newConversation(): Promise<void> {
    if (this.busy || !this.selected) { return; }
    if (this.members.filter((key: string) => !this.disabledMembers.includes(key)).length === 0) {
      this.errorText = '请先添加并启用至少一位成员'; return;
    }
    await this.saveGroup(); if (this.errorText) { return; }
    this.busy = true;
    try { const session = await GroupSession.create(this.selected); this.enterChat(session.chatId); }
    catch (error) { this.errorText = (error as Error).message; }
    finally { this.busy = false; }
  }
  async muteMember(character: CharacterDto): Promise<void> {
    if (this.busy) { return; }
    const key: string = character.avatar || '';
    this.disabledMembers = this.disabledMembers.includes(key) ? this.disabledMembers.filter((m: string) => m !== key)
      : this.disabledMembers.concat([key]);
    await this.saveGroup();
  }

  async applyRenameChat(oldName: string, newName: string): Promise<void> {
    if (newName === '' || newName === oldName) {
      return;
    }
    this.busy = true;
    try {
      const committed: string = await Backend.renameGroupChat(oldName, newName);
      const current: ESObject = await Backend.getGroup(this.selected);
      const oldId: string = oldName.replace(/\.jsonl$/, '');
      const nextId: string = committed.replace(/\.jsonl$/, '');
      current.chats = ((current.chats as string[]) || []).map((id: string) => id.replace(/\.jsonl$/, '') === oldId ? nextId : id);
      if ((current.chat_id as string).replace(/\.jsonl$/, '') === oldId) { current.chat_id = nextId; }
      await Backend.updateGroup(current);
      await Backend.clearGroupChatCache();
      this.statusText = `已重命名为 ${committed}`;
      const group: ESObject = await Backend.getGroup(this.selected);
      await this.openGroup(group);
    } catch (err) {
      this.errorText = `重命名失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async showChatPath(chat: ChatSummaryView): Promise<void> {
    try {
      const path: string = await Backend.getGroupChatPayloadPath(chat.chatId);
      this.statusText = path;
    } catch (err) {
      this.errorText = `取路径失败：${(err as BackendError).message}`;
    }
  }

  @Builder
  pageTopBar() {
    PageHeader({
        title: '群聊',
        subtitle: '让不同角色相遇',
        onBack: () => {
            ROOT_PATH_STACK.pop();
        }
      }) {
        HeaderAction({ label: '刷新', marker: 'grouppage-refresh-1', available: !this.busy,
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
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        ErrorBannerView({ text: this.errorText })
  
        Column() {
          Column({ space: Spacing.md }) {
            if (this.loading) {
              Text('读取中…').fontSize(Typography.caption).fontColor(this.uiColors.textTertiary)
            } else {
              Row({ space: Spacing.sm }) {
                TextInput({ placeholder: '新群名', text: this.newGroupName })
                  .fontColor(this.uiColors.textPrimary)
                  .placeholderColor(this.uiColors.textTertiary)
                  .backgroundColor(this.uiColors.bgSurfaceHigh)
                  .borderRadius(UIRadius.sm)
                  .fontSize(Typography.caption)
                  .height(Touch.minTarget)
                  .layoutWeight(1)
                  .backgroundColor(this.uiColors.bgSurfaceHigh)
                  .onChange((value: string) => {
                    this.newGroupName = value;
                  })
                .attributeModifier(new InputFieldStyle(this.uiColors))
      Button('建群', { type: ButtonType.Normal })
                  .fontSize(UIType.caption)
                  .height(Touch.minTarget)
                  .enabled(!this.busy)
                  .onClick(() => {
                    this.createGroup();
                  })
              .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
              .width('100%')
  
              if (this.groups.length === 0) {
                EmptyHint('还没有群组', '群聊让多个角色同场对话；先建一个群，再加成员', this.uiColors)
              } else {
                ForEach(this.groups, (group: ESObject) => {
                  Row({ space: Spacing.sm }) {
                    Text(this.groupTitle(group))
                      .fontSize(Typography.caption)
                      .fontColor(this.selected === (group.id as string) ? this.uiColors.accent : this.uiColors.textPrimary)
                      .layoutWeight(1)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Button('打开', { type: ButtonType.Normal })
                      .fontSize(UIType.micro)
                      .constraintSize({ minHeight: 44 })
                      .backgroundColor(this.uiColors.bgSurfaceHigh)
                      .fontColor(this.uiColors.textSecondary)
                      .onClick(() => {
                        this.openGroup(group);
                      })
                    .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button('删除', { type: ButtonType.Normal })
                      .fontSize(UIType.micro)
                      .constraintSize({ minHeight: 44 })
                      .backgroundColor(this.uiColors.danger)
                      .id('group-delete-' + (group.id as string))
                      .onClick(() => {
                        this.confirmDeleteGroup(group);
                      })
                  .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Danger))
      }
                  .width('100%')
                  .padding(Spacing.sm)
                  .backgroundColor(this.uiColors.bgSurface)
                  .borderRadius(Radius.sm)
                  .attributeModifier(new SurfaceStyle(this.uiColors, Radius.sm))
                }, (group: ESObject) => `${group.id}-${(group.members as string[]).length}`)
              }
  
              if (this.selected !== '') {
                Divider().color(this.uiColors.borderSubtle).margin({ top: Spacing.sm, bottom: Spacing.sm })
                TextInput({ text: this.groupName, placeholder: '群聊名称' }).id('group-name')
                  .attributeModifier(new InputFieldStyle(this.uiColors))
                  .onChange((value: string): void => { this.groupName = value; })
                SettingsPicker({ title: '回复方式', marker: 'group-strategy', selectedId: this.strategy === 2 ? '2' : '1',
                  options: [{ id: '1', label: '按成员顺序轮流回复' }, { id: '2', label: '手动选择成员回复' }],
                  onSelect: (id: string): void => { this.strategy = Number(id); } })
                Button('保存群聊设置').enabled(!this.busy).id('group-save')
                  .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
                  .onClick((): void => { this.saveGroup(); })
                Button('开始新对话').enabled(!this.busy).id('group-new-conversation')
                  .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
                  .onClick((): void => { this.newConversation(); })
  
                Text('成员（点头像姓名加入/移出）')
                  .fontSize(Typography.caption)
                  .fontColor(this.uiColors.textSecondary)
                  .width('100%')
                if (this.characters.length === 0) {
                  EmptyHint('还没有角色', '先去角色页建一个角色，才能拉进群', this.uiColors)
                } else {
                  ForEach(this.characters, (character: CharacterDto) => {
                    Row({ space: Spacing.sm }) {
                      Text(`${this.isMember(character) ? '✅' : '➕'} ${character.name}`)
                        .fontSize(Typography.caption)
                        .fontColor(this.isMember(character) ? this.uiColors.textPrimary : this.uiColors.textSecondary)
                        .layoutWeight(1)
                      if (this.isMember(character)) {
                        Button(this.disabledMembers.includes(character.avatar || '') ? '取消静音' : '静音')
                          .enabled(!this.busy).attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
                          .onClick((): void => { this.muteMember(character); })
                      }
                      Button(this.isMember(character) ? '移出' : '加入', { type: ButtonType.Normal })
                        .fontSize(UIType.micro)
                        .constraintSize({ minHeight: 44 })
                        .backgroundColor(this.uiColors.bgSurfaceHigh)
                        .fontColor(this.uiColors.textSecondary)
                        .enabled(!this.busy)
                        .onClick(() => {
                          this.toggleMember(character, !this.isMember(character));
                        })
                    .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
                    .width('100%')
                    .padding(Spacing.sm)
                    .backgroundColor(this.uiColors.bgSurface)
                    .borderRadius(Radius.sm)
                    .attributeModifier(new SurfaceStyle(this.uiColors, Radius.sm))
                  }, (character: CharacterDto) => `${character.avatar ?? character.name}-${this.isMember(character)}`)
                }
  
                Text('群聊会话')
                  .fontSize(Typography.caption)
                  .fontColor(this.uiColors.textSecondary)
                  .width('100%')
                if (this.chats.length === 0) {
                  EmptyHint('这个群还没有聊天记录', '添加成员后，点上方开始新对话', this.uiColors)
                } else {
                  ForEach(this.chats, (chat: ChatSummaryView) => {
                    Column({ space: 4 }) {
                      Text(chat.fileName)
                        .fontSize(Typography.caption)
                        .fontColor(this.uiColors.textPrimary)
                        .width('100%')
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text(`${chat.messageCount} 条消息 ${chat.preview}`)
                        .fontSize(Typography.micro)
                        .fontColor(this.uiColors.textTertiary)
                        .width('100%')
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      Row({ space: 6 }) {
                        Button('打开').attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
                          .onClick((): void => { this.enterChat(chat.chatId); })
                        Button('改名', { type: ButtonType.Normal })
                          .fontSize(UIType.micro)
                          .constraintSize({ minHeight: 44 })
                          .layoutWeight(1)
                          .backgroundColor(this.uiColors.bgSurfaceHigh)
                          .fontColor(this.uiColors.textSecondary)
                          .onClick(() => {
                            this.renameChat(chat);
                          })
                        .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button('路径', { type: ButtonType.Normal })
                          .fontSize(UIType.micro)
                          .constraintSize({ minHeight: 44 })
                          .layoutWeight(1)
                          .backgroundColor(this.uiColors.bgSurfaceHigh)
                          .fontColor(this.uiColors.textSecondary)
                          .onClick(() => {
                            this.showChatPath(chat);
                          })
                        .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button('删除', { type: ButtonType.Normal })
                          .fontSize(UIType.micro)
                          .constraintSize({ minHeight: 44 })
                          .layoutWeight(1)
                          .backgroundColor(this.uiColors.danger)
                          .id('group-chat-delete-' + chat.chatId)
                          .onClick(() => {
                            this.confirmDeleteChat(chat);
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
                  }, (chat: ChatSummaryView) => `${chat.fileName}-${chat.messageCount}`)
                }
                if (this.renameId !== '') {
                  TextInput({ text: this.renameText, placeholder: '新的聊天名称' })
                    .attributeModifier(new InputFieldStyle(this.uiColors))
                    .onChange((value: string): void => { this.renameText = value; })
                  Button('确认改名').enabled(!this.busy && this.renameText.trim() !== '')
                    .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
                    .onClick((): void => {
                      this.applyRenameChat(this.renameId, this.renameText.trim().replace(/\.jsonl$/, '') + '.jsonl');
                      this.renameId = '';
                    })
                }
              }
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

  build() {
    PageSurface({ topBar: () => { this.pageTopBar(); }, content: () => { this.buildSurfaceContent(); } })
  }
}
