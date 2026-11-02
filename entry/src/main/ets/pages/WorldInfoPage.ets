import { SurfaceStyle } from '../theme/SurfaceStyles';
import { WorldImportPage } from './WorldImportPage';
import { SettingsPicker } from '../components/SettingsPicker';
import { saveBytes } from '../utils/ExportFiles';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { ActionButtonStyle, ActionTone, InputFieldStyle, TextAreaFieldStyle } from '../theme/ControlStyles';
import { HeaderAction } from '../components/HeaderAction';
import { OriginMotion } from '../theme/OriginMotion';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { PageSurface } from '../components/PageSurface';
import { Radius as UIRadius, Typography as UIType } from '../theme/Tokens';
import { PageHeader } from '../components/PageHeader';
// 世界书（P8-22）：world info / lorebook 的浏览与编辑。
//
// 对应 DevEco 工程路径：entry/src/main/ets/pages/WorldInfoPage.ets
//
// 这是本轮唯一「补 Rust」的功能：原生层原本一条 world_info 命令都没有
// （领域模型、仓库、服务全都在，就是没接出来）。新加 9 条命令：
// list_world_infos / get_world_info / world_info_begin_commit / _append_commit_chunk /
// _finish_commit / _abort_commit / delete_world_info / normalize_world_info_name / import_world_info
//
// SillyTavern 的世界书文件长这样：
//   { "entries": { "0": { "uid": 0, "key": ["龙","dragon"], "content": "...", "constant": false,
//                          "selective": true, "order": 100, "disable": false, ... } } }
// 所以这里做两件事：书名列表 + 单本编辑（条目列表按 uid 排序，能改 keys/content/启用状态）。
import { Backend, BackendError } from '../backend/Backend';
import { LibraryEditIntent, ROOT_PATH_STACK } from '../nav/RootNav';
import { Radius, Spacing, Touch, Typography } from '../theme/Tokens';
import { GLASS_HEADER, glassEffect } from '../theme/Glass';
import { EmptyHint, ErrorBannerView } from '../components/Builders';

interface WorldEntryView {
  uid: number;
  keys: string;
  content: string;
  constant: boolean;
  disabled: boolean;
  comment: string;
  secondary: string;
  order: number;
  probability: number;
  useProbability: boolean;
  selective: boolean;
}

@Component
export struct WorldInfoPage {
  @Prop embedded: boolean = false;
  @Prop contentBottom: number = 24;
  @State importing: boolean = false;
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @State loading: boolean = true;
  @State busy: boolean = false;
  @State errorText: string = '';
  @State statusText: string = '';

  @State books: string[] = [];
  @State selected: string = '';
  @State entries: WorldEntryView[] = [];
  @State newName: string = '';
  @State editingUid: number = -1;
  @State editingContent: string = '';
  @State editingKeys: string = '';
  @State entryQuery: string = '';
  @State bookQuery: string = '';
  @State editingComment: string = '';
  @State editingSecondary: string = '';
  @State editingOrder: string = '100';
  @State editingProbability: string = '100';
  @State editingUseProbability: boolean = false;
  @State editingSelective: boolean = true;

  aboutToAppear(): void {
    if (!Backend.isReady()) {
      this.errorText = '后端未就绪，请从首页进入';
      this.loading = false;
      return;
    }
    const name: string = LibraryEditIntent.takeWorld();
    this.reload().then((): void => { if (name !== '') { this.openBook(name); } });
  }

  async reload(): Promise<void> {
    this.loading = true;
    this.errorText = '';
    try {
      this.books = await Backend.listWorldInfos();
      this.statusText = `${this.books.length} 本世界书`;
      if (this.selected !== '' && !this.books.includes(this.selected)) {
        this.selected = '';
        this.entries = [];
      }
    } catch (err) {
      this.errorText = `读取失败：${(err as BackendError).message}`;
    } finally {
      this.loading = false;
    }
  }

  /** 读一本书并摊平成条目视图（entries 可能是有序对象或数组）。 */
  async openBook(name: string): Promise<void> {
    this.cancelEdit(); this.entryQuery = '';
    this.selected = name;
    this.busy = true;
    this.errorText = '';
    try {
      const book: ESObject = await Backend.getWorldInfo(name);
      this.entries = WorldInfoPage.toViews(book);
      this.statusText = `${name} · ${this.entries.length} 条条目`;
    } catch (err) {
      this.errorText = `读取世界书失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  static toViews(book: ESObject): WorldEntryView[] {
    const views: WorldEntryView[] = [];
    const rawEntries: ESObject = book.entries as ESObject;
    if (rawEntries === undefined || rawEntries === null) {
      return views;
    }
    const rawKeys: string[] = Object.keys(rawEntries);
    for (let i = 0; i < rawKeys.length; i++) {
      const key: string = rawKeys[i];
      const entry: ESObject = rawEntries[key] as ESObject;
      if (entry === undefined || entry === null) {
        continue;
      }
      const uidRaw: number = entry.uid as number;
      const uid: number = uidRaw === undefined || uidRaw === null ? i : uidRaw;
      views.push({
        uid: uid,
        keys: WorldInfoPage.joinKeys(entry.key),
        content: (entry.content as string) ?? '',
        constant: (entry.constant as boolean) === true,
        disabled: (entry.disable as boolean) === true || entry.enabled === false,
        comment: (entry.comment as string) ?? '', secondary: WorldInfoPage.joinKeys(entry.keysecondary),
        order: (entry.order as number) ?? 100, probability: (entry.probability as number) ?? 100,
        useProbability: entry.useProbability === true,
        selective: entry.selective !== false
      });
    }
    views.sort((a: WorldEntryView, b: WorldEntryView) => a.uid - b.uid);
    return views;
  }

  static joinKeys(value: ESObject): string {
    if (value === undefined || value === null) {
      return '';
    }
    const list: ESObject[] = value as ESObject[];
    if (list.length === undefined) {
      return `${value}`;
    }
    const parts: string[] = [];
    for (let i = 0; i < list.length; i++) {
      parts.push(`${list[i]}`);
    }
    return parts.join(', ');
  }

  /** 新建一本书：先规范化书名，再写一份空 entries 的文档。 */
  async createBook(): Promise<void> {
    const typed: string = this.newName.trim();
    if (typed === '') {
      this.errorText = '先输入书名';
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      const name: string = await Backend.normalizeWorldInfoName(typed, false);
      const entries: ESObject = {};
      const document: ESObject = { entries: entries };
      await Backend.saveWorldInfo(name, document);
      this.newName = '';
      this.getUIContext().getFocusController().clearFocus();
      this.statusText = `已创建 ${name}`;
      await this.reload();
      await this.openBook(name);
    } catch (err) {
      this.errorText = `创建失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  confirmDelete(name: string): void {
    this.getUIContext().showAlertDialog({
      title: '删除世界书',
      alignment: DialogAlignment.Center,
      transition: OriginMotion.dialog(this.getUIContext(), 'world-delete-' + name),
      message: `确定删除「${name}」？这个操作不可撤销。`,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        action: () => {
          this.deleteBook(name);
        }
      }
    });
  }

  async deleteBook(name: string): Promise<void> {
    this.busy = true;
    try {
      await Backend.deleteWorldInfo(name);
      if (this.selected === name) {
        this.selected = '';
        this.entries = [];
      }
      this.statusText = `已删除 ${name}`;
      await this.reload();
    } catch (err) {
      this.errorText = `删除失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  startEdit(entry: WorldEntryView): void {
    this.editingUid = entry.uid;
    this.editingContent = entry.content;
    this.editingKeys = entry.keys;
    this.editingComment = entry.comment; this.editingSecondary = entry.secondary;
    this.editingOrder = String(entry.order); this.editingProbability = String(entry.probability);
    this.editingUseProbability = entry.useProbability;
    this.editingSelective = entry.selective;
  }

  cancelEdit(): void {
    this.getUIContext().getFocusController().clearFocus();
    this.editingUid = -1;
    this.editingContent = '';
    this.editingKeys = '';
  }

  async addEntry(): Promise<void> {
    if (this.busy || this.selected === '') { return; }
    this.busy = true; this.errorText = '';
    try {
      const book: ESObject = await Backend.getWorldInfo(this.selected);
      const raw: ESObject = book.entries || {};
      const views: WorldEntryView[] = WorldInfoPage.toViews(book);
      let uid: number = 0;
      for (const entry of views) { uid = Math.max(uid, entry.uid + 1); }
      raw[uid.toString()] = { uid: uid, key: [], content: '', constant: false, disable: false, order: 100, selective: true };
      book.entries = raw;
      await Backend.saveWorldInfo(this.selected, book); await this.openBook(this.selected);
      const entry = this.entries.find((item: WorldEntryView) => item.uid === uid);
      if (entry) { this.startEdit(entry); }
    } catch (error) { this.errorText = (error as Error).message; }
    finally { this.busy = false; }
  }

  private entryKey(book: ESObject, uid: number): string {
    const raw: ESObject = book.entries || {};
    const keys: string[] = Object.keys(raw);
    return keys.find((key: string, index: number) => ((raw[key] as ESObject).uid ?? index) === uid) || '';
  }

  confirmRemoveEntry(entry: WorldEntryView): void {
    this.getUIContext().showAlertDialog({ title: '删除条目', message: '确定删除条目 #' + entry.uid + '？',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: { value: '删除', action: (): void => { this.removeEntry(entry.uid); } } });
  }
  async removeEntry(uid: number): Promise<void> {
    if (this.busy) { return; } this.busy = true;
    try {
      const book: ESObject = await Backend.getWorldInfo(this.selected);
      const key: string = this.entryKey(book, uid);
      const next: ESObject = {};
      for (const current of Object.keys(book.entries)) { if (current !== key) { next[current] = book.entries[current]; } }
      book.entries = next; await Backend.saveWorldInfo(this.selected, book); await this.openBook(this.selected);
    } catch (error) { this.errorText = (error as Error).message; }
    finally { this.busy = false; }
  }

  /**
   * 改一条条目：读整份文档 → 就地改这一条 → 整份写回。
   * 世界书是「整份 JSON 替换」语义（后端 finish 时按 {name, data} 落盘），所以必须读改写。
   */
  async saveEntry(entry: WorldEntryView): Promise<void> {
    if (this.busy) { return; }
    const order: number = Number(this.editingOrder);
    const probability: number = Number(this.editingProbability);
    if (this.editingOrder.trim() === '' || this.editingProbability.trim() === '' || !Number.isInteger(order) || order < 0 || order > 100000 ||
      !Number.isFinite(probability) || probability < 0 || probability > 100) {
      this.errorText = '插入顺序需为 0–100000 的整数，触发概率需为 0–100。'; return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      const book: ESObject = await Backend.getWorldInfo(this.selected);
      const rawEntries: ESObject = book.entries as ESObject;
      const key: string = this.entryKey(book, entry.uid);
      const target: ESObject = rawEntries[key] as ESObject;
      if (target === undefined || target === null) {
        this.errorText = '条目已不存在，刷新试试';
        return;
      }
      const keys: string[] = this.editingKeys.split(/[,，\n]/)
        .map((item: string) => item.trim())
        .filter((item: string) => item !== '');
      target.key = keys;
      target.content = this.editingContent;
      target.comment = this.editingComment;
      target.keysecondary = this.editingSecondary.split(/[,，\n]/).map((value: string): string => value.trim()).filter((value: string): boolean => value !== '');
      target.order = order; target.probability = probability; target.useProbability = this.editingUseProbability;
      target.selective = this.editingSelective;
      await Backend.saveWorldInfo(this.selected, book);
      this.statusText = `已保存条目 #${entry.uid}`;
      this.cancelEdit();
      await this.openBook(this.selected);
    } catch (err) {
      this.errorText = `保存条目失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  /** 切换「常驻/禁用」这类布尔开关，同样走读改写。 */
  async toggleEntryFlag(entry: WorldEntryView, flag: string): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      const book: ESObject = await Backend.getWorldInfo(this.selected);
      const rawEntries: ESObject = book.entries as ESObject;
      const target: ESObject = rawEntries[this.entryKey(book, entry.uid)] as ESObject;
      if (target === undefined || target === null) {
        return;
      }
      if (flag === 'constant') {
        target.constant = !entry.constant;
      } else {
        target.disable = !entry.disabled;
        if (target.enabled !== undefined) { target.enabled = !target.disable; }
      }
      await Backend.saveWorldInfo(this.selected, book);
      await this.openBook(this.selected);
    } catch (err) {
      this.errorText = `切换失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  entryTitle(entry: WorldEntryView): string {
    const keys: string = entry.keys === '' ? '（无关键字）' : entry.keys;
    let flags: string = '';
    if (entry.constant) {
      flags = '常驻';
    }
    if (entry.disabled) {
      flags = flags === '' ? '已禁用' : `${flags}·已禁用`;
    }
    const title: string = entry.comment || keys;
    return flags === '' ? `#${entry.uid} ${title}` : `#${entry.uid} ${title} [${flags}]`;
  }

  private async exportBook(): Promise<void> {
    if (this.busy || this.selected === '') { return; }
    this.busy = true; this.errorText = '';
    try {
      const book: ESObject = await Backend.getWorldInfo(this.selected);
      const bytes: Uint8Array = new util.TextEncoder().encodeInto(JSON.stringify(book, null, 2));
      const saved: boolean = await saveBytes(this.getUIContext().getHostContext() as common.UIAbilityContext,
        this.selected.replace(/[\\/:*?"<>|]/g, '_') + '.json', bytes.buffer as ArrayBuffer);
      this.statusText = saved ? '世界书已导出' : '已取消导出';
    } catch (error) { this.errorText = '导出失败：' + (error as Error).message; }
    finally { this.busy = false; }
  }

  @Builder
  pageTopBar() {
    PageHeader({
        title: '世界书',
        subtitle: '故事的背景与记忆',
        onBack: () => {
            ROOT_PATH_STACK.pop();
        }
      }) {
        HeaderAction({ label: '刷新', marker: 'worldinfopage-refresh-1', available: !this.busy,
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
        ErrorBannerView({ text: this.errorText })
  
        Column() {
          Column({ space: Spacing.md }) {
            if (this.loading) {
              Text('读取中…').fontSize(Typography.caption).fontColor(this.uiColors.textTertiary)
            } else {
              Row({ space: Spacing.sm }) {
                TextInput({ placeholder: '新世界书名字', text: this.newName })
                  .fontColor(this.uiColors.textPrimary)
                  .placeholderColor(this.uiColors.textTertiary)
                  .backgroundColor(this.uiColors.bgSurfaceHigh)
                  .borderRadius(UIRadius.sm)
                  .fontSize(Typography.caption)
                  .height(Touch.minTarget)
                  .layoutWeight(1)
                  .backgroundColor(this.uiColors.bgSurfaceHigh)
                  .onChange((value: string) => {
                    this.newName = value;
                  })
                .attributeModifier(new InputFieldStyle(this.uiColors))
      Button('新建', { type: ButtonType.Normal })
                  .fontSize(UIType.caption)
                  .height(Touch.minTarget)
                  .enabled(!this.busy)
                  .onClick(() => {
                    this.createBook();
                  })
              .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
              .width('100%')
  
              if (this.books.length === 0) {
                EmptyHint('还没有世界书', '新建一本，或点上方导入世界书', this.uiColors)
              } else {
                TextInput({ text: this.bookQuery, placeholder: '搜索世界书' }).attributeModifier(new InputFieldStyle(this.uiColors)).width('100%')
                  .onChange((value: string): void => { this.bookQuery = value; }).id('world-book-search')
                ForEach(this.books.filter((name: string): boolean => name.toLowerCase().includes(this.bookQuery.trim().toLowerCase())), (name: string) => {
                  Row({ space: Spacing.sm }) {
                    Text(name)
                      .fontSize(Typography.caption)
                      .fontColor(this.selected === name ? this.uiColors.accent : this.uiColors.textPrimary)
                      .layoutWeight(1)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Button(this.selected === name ? '已打开' : '编辑', { type: ButtonType.Normal })
                      .fontSize(UIType.micro)
                      .constraintSize({ minHeight: 44 })
                      .backgroundColor(this.uiColors.bgSurfaceHigh)
                      .fontColor(this.uiColors.textSecondary)
                      .onClick(() => {
                        this.openBook(name);
                      })
                    .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button('删除', { type: ButtonType.Normal })
                      .fontSize(UIType.micro)
                      .constraintSize({ minHeight: 44 })
                      .backgroundColor(this.uiColors.danger)
                      .id('world-delete-' + name)
                      .onClick(() => {
                        this.confirmDelete(name);
                      })
                  .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Danger))
      }
                  .width('100%')
                  .padding(Spacing.sm)
                  .backgroundColor(this.uiColors.bgSurface)
                  .borderRadius(Radius.sm)
                  .attributeModifier(new SurfaceStyle(this.uiColors, Radius.sm))
                }, (name: string) => name)
              }
  
              if (this.selected !== '') {
                Divider().color(this.uiColors.borderSubtle).margin({ top: Spacing.sm, bottom: Spacing.sm })
                Text(`${this.selected} 的条目`)
                  .fontSize(Typography.caption)
                  .fontColor(this.uiColors.textSecondary)
                  .width('100%')
                Button('添加条目').enabled(!this.busy).id('library-world-add-entry')
                  .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
                  .onClick((): void => { this.addEntry(); })
                Button('导出这本世界书').enabled(!this.busy).id('library-world-export')
                  .attributeModifier(new ActionButtonStyle(this.uiColors)).onClick((): void => { this.exportBook(); })
                TextInput({ text: this.entryQuery, placeholder: '搜索条目标题、关键词或内容' }).attributeModifier(new InputFieldStyle(this.uiColors)).width('100%')
                  .id('world-entry-search').onChange((value: string): void => { this.entryQuery = value; })
                if (this.entries.length === 0) {
                  EmptyHint('这本还没有条目', '点添加条目，或导入已有世界书', this.uiColors)
                } else {
                  ForEach(this.entries.filter((entry: WorldEntryView): boolean => entry.uid === this.editingUid ||
                    (entry.comment + ' ' + entry.keys + ' ' + entry.content).toLowerCase().includes(this.entryQuery.trim().toLowerCase())), (entry: WorldEntryView) => {
                    Column({ space: 6 }) {
                      Button('删除条目').enabled(!this.busy)
                        .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Danger))
                        .onClick((): void => { this.confirmRemoveEntry(entry); })
                      Text(this.entryTitle(entry))
                        .fontSize(Typography.micro)
                        .fontColor(this.uiColors.textTertiary)
                        .width('100%')
                        .maxLines(2)
                      if (this.editingUid === entry.uid) {
                        TextInput({ text: this.editingComment, placeholder: '条目标题 / 备注' }).width('100%')
                          .attributeModifier(new InputFieldStyle(this.uiColors)).id('world-entry-comment')
                          .onChange((value: string): void => { this.editingComment = value; })
                        TextInput({ placeholder: '关键字，逗号分隔', text: this.editingKeys })
                          .fontColor(this.uiColors.textPrimary)
                          .placeholderColor(this.uiColors.textTertiary)
                          .backgroundColor(this.uiColors.bgSurfaceHigh)
                          .borderRadius(UIRadius.sm)
                          .fontSize(Typography.caption)
                          .constraintSize({ minHeight: 44 })
                          .width('100%')
                          .backgroundColor(this.uiColors.bgSurfaceHigh)
                          .onChange((value: string) => {
                            this.editingKeys = value;
                          })
                        .attributeModifier(new InputFieldStyle(this.uiColors))
      TextArea({ text: this.editingContent, placeholder: '条目内容…' })
                          .fontColor(this.uiColors.textPrimary)
                          .placeholderColor(this.uiColors.textTertiary)
                          .backgroundColor(this.uiColors.bgSurfaceHigh)
                          .borderRadius(UIRadius.sm)
                          .fontSize(Typography.caption)
                          .height(220)
                          .width('100%')
                          .backgroundColor(this.uiColors.bgSurfaceHigh)
                          .borderRadius(Radius.sm)
                          .onChange((value: string) => {
                            this.editingContent = value;
                          })
                        .attributeModifier(new TextAreaFieldStyle(this.uiColors))
                        TextInput({ text: this.editingSecondary, placeholder: '次级关键词（逗号分隔）' }).width('100%')
                          .attributeModifier(new InputFieldStyle(this.uiColors)).id('world-entry-secondary')
                          .onChange((value: string): void => { this.editingSecondary = value; })
                        SettingsPicker({ title: '次级关键词匹配', marker: 'world-entry-selective', selectedId: this.editingSelective ? 'yes' : 'no',
                          options: [{ id: 'yes', label: '启用次级关键词匹配' }, { id: 'no', label: '仅使用主要关键词' }],
                          onSelect: (id: string): void => { this.editingSelective = id === 'yes'; } })
                        Text('插入顺序').fontSize(13).fontColor(this.uiColors.textSecondary).width('100%')
                        TextInput({ text: this.editingOrder, placeholder: '插入顺序，例如 100' }).type(InputType.Number).width('100%')
                          .attributeModifier(new InputFieldStyle(this.uiColors)).id('world-entry-order')
                          .onChange((value: string): void => { this.editingOrder = value; })
                        Text('触发概率（%）').fontSize(13).fontColor(this.uiColors.textSecondary).width('100%')
                        SettingsPicker({ title: '概率判断', marker: 'world-entry-use-probability', selectedId: this.editingUseProbability ? 'yes' : 'no',
                          options: [{ id: 'yes', label: '按概率触发' }, { id: 'no', label: '不使用概率判断' }],
                          onSelect: (id: string): void => { this.editingUseProbability = id === 'yes'; } })
                        TextInput({ text: this.editingProbability, placeholder: '触发概率 0–100' }).type(InputType.Number).width('100%')
                          .attributeModifier(new InputFieldStyle(this.uiColors)).id('world-entry-probability')
                          .onChange((value: string): void => { this.editingProbability = value; })
      Row({ space: 6 }) {
                          Button('保存', { type: ButtonType.Normal })
                            .fontSize(UIType.micro)
                            .constraintSize({ minHeight: 44 })
                            .layoutWeight(1)
                            .enabled(!this.busy)
                            .onClick(() => {
                              this.saveEntry(entry);
                            })
                          .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      Button('取消', { type: ButtonType.Normal })
                            .fontSize(UIType.micro)
                            .constraintSize({ minHeight: 44 })
                            .layoutWeight(1)
                            .backgroundColor(this.uiColors.bgSurfaceHigh)
                            .fontColor(this.uiColors.textSecondary)
                            .onClick(() => {
                              this.cancelEdit();
                            })
                        .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
                        .width('100%')
                      } else {
                        Text(entry.content)
                          .fontSize(Typography.caption)
                          .fontColor(this.uiColors.textPrimary)
                          .width('100%')
                          .maxLines(4)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                        Row({ space: 6 }) {
                          Button('编辑', { type: ButtonType.Normal })
                            .fontSize(UIType.micro)
                            .constraintSize({ minHeight: 44 })
                            .layoutWeight(1)
                            .onClick(() => {
                              this.startEdit(entry);
                            })
                          .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button(entry.constant ? '取消常驻' : '设为常驻', { type: ButtonType.Normal })
                            .fontSize(UIType.micro)
                            .constraintSize({ minHeight: 44 })
                            .layoutWeight(1)
                            .backgroundColor(this.uiColors.bgSurfaceHigh)
                            .fontColor(this.uiColors.textSecondary)
                            .onClick(() => {
                              this.toggleEntryFlag(entry, 'constant');
                            })
                          .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button(entry.disabled ? '启用' : '禁用', { type: ButtonType.Normal })
                            .fontSize(UIType.micro)
                            .constraintSize({ minHeight: 44 })
                            .layoutWeight(1)
                            .backgroundColor(this.uiColors.bgSurfaceHigh)
                            .fontColor(this.uiColors.textSecondary)
                            .onClick(() => {
                              this.toggleEntryFlag(entry, 'disable');
                            })
                        .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
                        .width('100%')
                      }
                    }
                    .width('100%')
                    .padding(Spacing.md)
                    .backgroundColor(this.uiColors.bgSurface)
                    .borderRadius(Radius.md)
                    .attributeModifier(new SurfaceStyle(this.uiColors, Radius.md))
                  }, (entry: WorldEntryView) => `${entry.uid}-${entry.constant}-${entry.disabled}`)
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
      .backgroundColor(this.embedded ? Color.Transparent : this.uiColors.bgBase)
    }

  build() {
    if (this.embedded) { this.libraryContent() }
    else { PageSurface({ topBar: () => { this.pageTopBar(); }, content: () => { this.libraryContent(); } }) }
  }

  @Builder
  libraryContent() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Button(this.importing ? '返回世界书' : '导入世界书')
          .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
          .onClick((): void => { this.importing = !this.importing; if (!this.importing) { this.reload(); } })
        Blank()
        HeaderAction({ label: '刷新世界书', marker: 'library-world-refresh', pending: this.loading,
          available: !this.busy, onAction: async (): Promise<void> => { await this.reload(); } })
      }.width('100%')
      if (this.importing) {
        WorldImportPage({ embedded: true, showLibraryList: false, contentBottom: this.contentBottom,
          onImported: (name: string): void => { this.importing = false; this.reload().then((): void => { this.openBook(name); }); } })
      } else { this.buildSurfaceContent() }
    }.width('100%').padding({ left: 16, right: 16, bottom: this.contentBottom })
  }
}
