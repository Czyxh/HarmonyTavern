import { common } from '@kit.AbilityKit';
import { picker, fileIo } from '@kit.CoreFileKit';
import { Backend } from '../backend/Backend';
import { copyToSandbox } from '../utils/ImportFiles';
import { IdentityAvatar } from './IdentityAvatar';
import { SurfaceStyle } from '../theme/SurfaceStyles';
import { ActionButtonStyle, ActionTone, InputFieldStyle, TextAreaFieldStyle } from '../theme/ControlStyles';
import { COLORS, ColorTokens } from '../theme/Tokens';
import { NativePreferences, NativePreferencesSnapshot, NativeSettings, defaultNativePreferences } from '../backend/NativePreferences';
import { ROOT_PATH_STACK } from '../nav/RootNav';
import { HeaderAction } from './HeaderAction';
import { SettingsChoice, SettingsPicker } from './SettingsPicker';

interface IdentityImage {
  name: string;
  path: string;
}

@Component
export struct NativePreferencesPanel {
  @StorageProp('uiColors') colors: ColorTokens = COLORS;
  @Prop identity: boolean = false;
  @Prop generationOnly: boolean = false;
  @Prop @Watch('reloadRequested') reloadToken: number = 0;
  onActivityChange: (active: boolean) => void = (_active: boolean): void => {};
  private readRevision: number = 0;
  private alive: boolean = false;
  @State preferences: NativePreferences = defaultNativePreferences();
  @State loading: boolean = true;
  @State busy: boolean = false;
  @State note: string = '';
  @State error: string = '';
  @State temperature: string = '1';
  @State topP: string = '1';
  @State maxTokens: string = '8192';
  @State personaDepth: string = '4';
  @State avatarPath: string = '';
  private positionKeys: string[] = ['before_character', 'after_character', 'before_history', 'in_history', 'after_history'];
  private positionLabels: string[] = ['角色描述之前', '角色描述之后', '聊天记录之前', '聊天记录中（指定深度）', '聊天记录之后'];
  private roleKeys: string[] = ['system', 'user', 'assistant'];
  private roleLabels: string[] = ['系统', '用户', '助手'];
  private snapshot: NativePreferencesSnapshot | undefined = undefined;

  aboutToAppear(): void { this.alive = true; this.load(); }
  aboutToDisappear(): void { this.alive = false; this.readRevision++; this.onActivityChange(false); }
  private reloadRequested(): void { if (this.alive) { this.load(true); } }
  private fill(snapshot: NativePreferencesSnapshot): void {
    this.snapshot = snapshot;
    this.preferences = snapshot.preferences;
    this.temperature = String(snapshot.preferences.temperature);
    this.topP = String(snapshot.preferences.top_p);
    this.maxTokens = String(snapshot.preferences.max_tokens);
    this.personaDepth = String(snapshot.preferences.persona_depth);
    this.avatarPath = snapshot.avatar_path === '' ? '' : 'file://' + snapshot.avatar_path;
  }
  private async load(feedback: boolean = false): Promise<void> {
    if (this.busy) { return; }
    const revision: number = ++this.readRevision;
    this.loading = true;
    this.onActivityChange(true);
    this.error = '';
    try {
      const snapshot: NativePreferencesSnapshot = await NativeSettings.get();
      if (!this.alive || revision !== this.readRevision) { return; }
      this.fill(snapshot);
      if (feedback) { this.note = '已刷新'; }
    }
    catch (error) { if (this.alive && revision === this.readRevision) { this.error = '读取失败：' + (error as Error).message; } }
    finally { if (this.alive && revision === this.readRevision) { this.loading = false; this.onActivityChange(false); } }
  }
  private async save(): Promise<void> {
    if (this.busy || this.loading || this.snapshot === undefined) { return; }
    this.busy = true;
    this.onActivityChange(true);
    this.note = ''; this.error = '';
    try {
      const temperature: number = Number(this.temperature);
      const topP: number = Number(this.topP);
      const tokens: number = Number(this.maxTokens);
      if (this.temperature.trim() === '' || this.topP.trim() === '' || this.maxTokens.trim() === '' ||
        !Number.isFinite(temperature) || temperature < 0 || temperature > 2 ||
        !Number.isFinite(topP) || topP < 0 || topP > 1 || !Number.isInteger(tokens) || tokens < 1 || tokens > 131072) {
        throw new Error('温度范围 0–2，Top P 范围 0–1，回复长度为 1–131072 的整数');
      }
      const depth: number = Number(this.personaDepth);
      if (this.personaDepth.trim() === '' || !Number.isInteger(depth) || depth < 0 || depth > 100) {
        throw new Error('人设插入深度必须为 0–100 的整数');
      }
      this.preferences.persona_depth = depth;
      this.preferences.temperature = temperature;
      this.preferences.top_p = topP;
      this.preferences.max_tokens = tokens;
      const snapshot: NativePreferencesSnapshot = await NativeSettings.save(this.preferences, this.snapshot.revision);
      if (!this.alive) { return; }
      this.fill(snapshot);
      this.note = '已保存，下次进入聊天或生成回复时生效';
    } catch (error) { if (this.alive) { this.error = '保存失败：' + (error as Error).message; } }
    finally { if (this.alive) { this.busy = false; this.onActivityChange(false); } }
  }

  private async chooseAvatar(): Promise<void> {
    if (this.busy || this.loading) { return; }
    this.busy = true;
    this.onActivityChange(true);
    this.error = ''; this.note = '';
    let path: string = '';
    try {
      const options: picker.PhotoSelectOptions = new picker.PhotoSelectOptions();
      options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const result: picker.PhotoSelectResult = await new picker.PhotoViewPicker().select(options);
      if (!this.alive || result.photoUris.length === 0) { return; }
      const source: fileIo.File = fileIo.openSync(result.photoUris[0], fileIo.OpenMode.READ_ONLY);
      try {
        if (fileIo.statSync(source.fd).size > 20 * 1024 * 1024) { throw new Error('请选择 20 MB 以内的图片'); }
      } finally { fileIo.closeSync(source); }
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      path = copyToSandbox(context, result.photoUris[0], 'identity-' + Date.now() + '.png');
      const avatar: IdentityImage = await Backend.call<IdentityImage>('upload_native_identity_avatar', { filePath: path });
      if (!this.alive) { return; }
      this.preferences.user_avatar = avatar.name;
      this.avatarPath = 'file://' + avatar.path;
      this.note = '头像已选择，点击保存后生效';
    } catch (error) { if (this.alive) { this.error = '选择头像失败：' + (error as Error).message; } }
    finally {
      if (path !== '') { try { fileIo.unlinkSync(path); } catch (error) {} }
      if (this.alive) { this.busy = false; this.onActivityChange(false); }
    }
  }

  @Builder
  switchRow(label: string, value: boolean, changed: (value: boolean) => void) {
    Row({ space: 12 }) {
      Text(label).fontSize(15).fontColor(this.colors.textPrimary).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: value }).selectedColor(this.colors.accent)
        .onChange(changed).accessibilityText(label)
    }.width('100%').constraintSize({ minHeight: 48 })
  }
  @Builder
  field(label: string, value: string, changed: (value: string) => void) {
    Column({ space: 6 }) {
      Text(label).fontSize(13).fontColor(this.colors.textSecondary).width('100%')
      TextInput({ text: value }).backgroundColor(this.colors.bgSurfaceHigh).fontColor(this.colors.textPrimary)
        .onChange(changed).accessibilityText(label)
    .attributeModifier(new InputFieldStyle(this.colors))
      }.width('100%')
  }
  build() {
    Column({ space: 14 }) {
      Text(this.identity ? '身份与人设' : (this.generationOnly ? '默认生成参数' : '聊天与生成')).fontSize(19).fontWeight(FontWeight.Bold)
        .fontColor(this.colors.textPrimary).width('100%')
      if (this.loading) {
        Text('读取中…').fontColor(this.colors.textSecondary)
      } else if (this.snapshot !== undefined) {
        Column({ space: 14 }) {
          if (this.identity) {
            Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
              IdentityAvatar({ name: this.preferences.user_name, source: this.avatarPath, diameter: 64 })
              Button('选择头像', { type: ButtonType.Normal }).onClick((): void => { this.chooseAvatar(); })
                .attributeModifier(new ActionButtonStyle(this.colors, ActionTone.Normal))
              Button('恢复默认', { type: ButtonType.Normal }).onClick((): void => {
                this.preferences.user_avatar = ''; this.avatarPath = '';
              }).attributeModifier(new ActionButtonStyle(this.colors, ActionTone.Normal))
            }.width('100%')
            this.field('聊天中使用的名字', this.preferences.user_name, (value: string): void => { this.preferences.user_name = value; })
            Text('用户人设').fontSize(14).fontColor(this.colors.textSecondary).width('100%')
            TextArea({ text: this.preferences.persona_description, placeholder: '你的身份、性格，以及希望角色了解的背景' })
              .height(180).fontColor(this.colors.textPrimary).backgroundColor(this.colors.bgSurfaceHigh)
              .onChange((value: string): void => { this.preferences.persona_description = value; })
              .accessibilityText('用户人设')
            .attributeModifier(new TextAreaFieldStyle(this.colors))
            SettingsPicker({ title: '描述插入位置', marker: 'persona-position-picker', selectedId: this.preferences.persona_position,
              options: this.positionKeys.map((id: string, index: number): SettingsChoice => { return { id: id, label: this.positionLabels[index] }; }),
              onSelect: (id: string): void => { this.preferences.persona_position = id; } })
            if (this.preferences.persona_position === 'in_history') {
              this.field('距离最新消息的深度（0–100）', this.personaDepth,
                (value: string): void => { this.personaDepth = value; })
            }
            if (this.preferences.persona_position === 'before_history' || this.preferences.persona_position === 'in_history' ||
              this.preferences.persona_position === 'after_history') {
              SettingsPicker({ title: '插入消息角色', marker: 'persona-role-picker', selectedId: this.preferences.persona_role,
                options: this.roleKeys.map((id: string, index: number): SettingsChoice => { return { id: id, label: this.roleLabels[index] }; }),
                onSelect: (id: string): void => { this.preferences.persona_role = id; } })
            }
            Text('描述由后端按选定位置插入提示词；历史消息不会被改写。').fontSize(12).fontColor(this.colors.textSecondary)
            Button('高级设置 JSON', { type: ButtonType.Normal }).onClick((): void => { ROOT_PATH_STACK.pushPathByName('pages/SettingsJsonPage', null); })
          .attributeModifier(new ActionButtonStyle(this.colors, ActionTone.Normal))
      } else {
            if (!this.generationOnly) {
            this.switchRow('新回复自动滚动到底部', this.preferences.auto_scroll_chat_to_bottom,
              (value: boolean): void => { this.preferences.auto_scroll_chat_to_bottom = value; })
            this.switchRow('删除消息前确认', this.preferences.confirm_message_delete,
              (value: boolean): void => { this.preferences.confirm_message_delete = value; })
            this.switchRow('发送时去除首尾空白', this.preferences.trim_spaces,
              (value: boolean): void => { this.preferences.trim_spaces = value; })
            }
            Text('生成参数与系统提示词在所有服务商之间共用。').fontSize(12).fontColor(this.colors.textSecondary)
            this.switchRow('启用系统提示词', this.preferences.system_prompt_enabled,
              (value: boolean): void => { this.preferences.system_prompt_enabled = value; })
            TextArea({ text: this.preferences.system_prompt, placeholder: '系统提示词，支持 {{char}} 和 {{user}}' })
              .height(150).fontColor(this.colors.textPrimary).backgroundColor(this.colors.bgSurfaceHigh)
              .onChange((value: string): void => { this.preferences.system_prompt = value; })
              .accessibilityText('系统提示词')
            .attributeModifier(new TextAreaFieldStyle(this.colors))
      this.switchRow('优先使用角色卡系统提示词', this.preferences.prefer_character_prompt,
              (value: boolean): void => { this.preferences.prefer_character_prompt = value; })
            this.switchRow('使用角色卡后置指令', this.preferences.prefer_character_jailbreak,
              (value: boolean): void => { this.preferences.prefer_character_jailbreak = value; })
            this.field('温度（0–2）', this.temperature, (value: string): void => { this.temperature = value; })
            this.field('Top P（0–1）', this.topP, (value: string): void => { this.topP = value; })
            this.field('回复长度上限（Token）', this.maxTokens, (value: string): void => { this.maxTokens = value; })
          }
        }.enabled(!this.busy).width('100%')
      }
      if (this.error !== '') { Text(this.error).fontColor(this.colors.danger).width('100%') }
      if (this.note !== '') { Text(this.note).fontColor(this.colors.textSecondary).width('100%') }
      Row({ space: 12 }) {
        Button(this.busy ? '保存中…' : '保存', { type: ButtonType.Normal }).enabled(!this.busy && !this.loading && this.snapshot !== undefined)
          .onClick((): void => { this.save(); })
        .attributeModifier(new ActionButtonStyle(this.colors, ActionTone.Primary))
      HeaderAction({ label: '刷新设置', available: !this.busy && !this.loading,
          onAction: async (): Promise<void> => { await this.load(true); } })
      }
    }.width('100%').padding(16).backgroundColor(this.colors.bgSurface).borderRadius(20).attributeModifier(new SurfaceStyle(this.colors, 20))
  }
}
