import { ActionButtonStyle, ActionTone, InputFieldStyle } from '../theme/ControlStyles';
import { HeaderAction } from '../components/HeaderAction';
import { NativePreferencesPanel } from '../components/NativePreferencesPanel';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { PageSurface } from '../components/PageSurface';
import { Radius as UIRadius, Typography as UIType } from '../theme/Tokens';
import { PageHeader } from '../components/PageHeader';
// 用户设定管理：上方管理实际聊天使用的名字与人设；其他用户档案折叠收纳。
// 原用户档案 CRUD 保留，但不暗示切换档案会切换聊天数据目录。
import { Backend, BackendError } from '../backend/Backend';
import { ROOT_PATH_STACK } from '../nav/RootNav';
import { Radius, Spacing, Typography } from '../theme/Tokens';
import { GLASS_CARD, GLASS_HEADER, glassEffect } from '../theme/Glass';
import { EmptyHint, ErrorBannerView, SectionTitle } from '../components/Builders';

interface UserInterfaceSettings {
  avatar_style: string;
  chat_display: string;
  font_size: number;
  blur_strength: number;
  show_timestamps: boolean;
}

interface UserGenerationSettings {
  max_context_length: number;
  response_length: number;
  temperature: number;
  top_p: number;
  top_k: number;
  repetition_penalty: number;
}

interface UserSettings {
  theme: string;
  interface: UserInterfaceSettings;
  generation: UserGenerationSettings;
}

interface UserProfile {
  id: string;
  username: string;
  avatar: string;
  created_at: string;
  settings: UserSettings;
}

@Component
export struct UserPage {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @State loading: boolean = true;
  @State showProfiles: boolean = false;
  @State preferencesReload: number = 0;
  @State preferencesBusy: boolean = false;
  @State busy: boolean = false;
  @State errorText: string = '';
  @State statusText: string = '';

  @State users: UserProfile[] = [];
  @State selected: UserProfile | undefined = undefined;

  @State editName: string = '';
  @State editAvatar: string = '';
  @State editTheme: string = '';
  @State editAvatarStyle: string = '';
  @State editChatDisplay: string = '';
  @State editFontSize: string = '';
  @State editBlur: string = '';
  @State editTimestamps: boolean = false;
  @State editMaxContext: string = '';
  @State editRespLen: string = '';
  @State editTemp: string = '';
  @State editTopP: string = '';
  @State editTopK: string = '';
  @State editRepPen: string = '';
  @State newUserName: string = '';

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
      const raw: ESObject[] = await Backend.getAllUsers();
      const list: UserProfile[] = [];
      for (let i = 0; i < raw.length; i++) {
        const one: ESObject = raw[i];
        const settings: ESObject = one['settings'];
        const iface: ESObject = settings['interface'];
        const generation: ESObject = settings['generation'];
        const profile: UserProfile = {
          id: String(one['id']),
          username: String(one['username']),
          avatar: one['avatar'] === undefined || one['avatar'] === null ? '' : String(one['avatar']),
          created_at: String(one['created_at']),
          settings: {
            theme: String(settings['theme']),
            interface: {
              avatar_style: String(iface['avatar_style']),
              chat_display: String(iface['chat_display']),
              font_size: Number(iface['font_size']),
              blur_strength: Number(iface['blur_strength']),
              show_timestamps: Boolean(iface['show_timestamps'])
            },
            generation: {
              max_context_length: Number(generation['max_context_length']),
              response_length: Number(generation['response_length']),
              temperature: Number(generation['temperature']),
              top_p: Number(generation['top_p']),
              top_k: Number(generation['top_k']),
              repetition_penalty: Number(generation['repetition_penalty'])
            }
          }
        };
        list.push(profile);
      }
      this.users = list;
    } catch (err) {
      this.errorText = `读取用户失败：${(err as BackendError).message}`;
      this.users = [];
    } finally {
      this.loading = false;
    }
  }

  select(user: UserProfile): void {
    this.selected = user;
    this.editName = user.username;
    this.editAvatar = user.avatar;
    this.editTheme = user.settings.theme;
    this.editAvatarStyle = user.settings.interface.avatar_style;
    this.editChatDisplay = user.settings.interface.chat_display;
    this.editFontSize = String(user.settings.interface.font_size);
    this.editBlur = String(user.settings.interface.blur_strength);
    this.editTimestamps = user.settings.interface.show_timestamps;
    this.editMaxContext = String(user.settings.generation.max_context_length);
    this.editRespLen = String(user.settings.generation.response_length);
    this.editTemp = String(user.settings.generation.temperature);
    this.editTopP = String(user.settings.generation.top_p);
    this.editTopK = String(user.settings.generation.top_k);
    this.editRepPen = String(user.settings.generation.repetition_penalty);
    this.statusText = `已选中 ${user.username}`;
  }

  intOf(text: string, fallback: number): number {
    const value: number = Number.parseInt(text, 10);
    return Number.isNaN(value) ? fallback : value;
  }

  floatOf(text: string, fallback: number): number {
    const value: number = Number.parseFloat(text);
    return Number.isNaN(value) ? fallback : value;
  }

  /** UpdateUserDto.settings 是整体替换，所以必须把三块都带上。 */
  buildDto(): ESObject {
    const base: UserProfile = this.selected!;
    const iface: UserInterfaceSettings = {
      avatar_style: this.editAvatarStyle.trim() === '' ? base.settings.interface.avatar_style : this.editAvatarStyle.trim(),
      chat_display: this.editChatDisplay.trim() === '' ? base.settings.interface.chat_display : this.editChatDisplay.trim(),
      font_size: this.intOf(this.editFontSize, base.settings.interface.font_size),
      blur_strength: this.intOf(this.editBlur, base.settings.interface.blur_strength),
      show_timestamps: this.editTimestamps
    };
    const generation: UserGenerationSettings = {
      max_context_length: this.intOf(this.editMaxContext, base.settings.generation.max_context_length),
      response_length: this.intOf(this.editRespLen, base.settings.generation.response_length),
      temperature: this.floatOf(this.editTemp, base.settings.generation.temperature),
      top_p: this.floatOf(this.editTopP, base.settings.generation.top_p),
      top_k: this.intOf(this.editTopK, base.settings.generation.top_k),
      repetition_penalty: this.floatOf(this.editRepPen, base.settings.generation.repetition_penalty)
    };
    const settings: ESObject = {
      theme: this.editTheme.trim() === '' ? base.settings.theme : this.editTheme.trim(),
      interface: iface,
      generation: generation
    };
    const dto: ESObject = {
      id: base.id,
      username: this.editName.trim() === '' ? base.username : this.editName.trim(),
      avatar: this.editAvatar.trim() === '' ? null : this.editAvatar.trim(),
      settings: settings
    };
    return dto;
  }

  async save(): Promise<void> {
    if (this.selected === undefined) {
      this.errorText = '先选一个用户';
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      await Backend.updateUser(this.buildDto());
      this.statusText = `已保存 ${this.editName.trim()}`;
      await this.reload();
    } catch (err) {
      this.errorText = `保存失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async createUser(): Promise<void> {
    const name: string = this.newUserName.trim();
    if (name === '') {
      this.errorText = '新用户名不能为空';
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      await Backend.createUser({ username: name, name: name });
      this.statusText = `已创建用户 ${name}`;
      this.newUserName = '';
      await this.reload();
    } catch (err) {
      this.errorText = `创建失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async remove(user: UserProfile): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      await Backend.deleteUser(user.id);
      this.statusText = `已删除用户 ${user.username}`;
      if (this.selected !== undefined && this.selected!.id === user.id) {
        this.selected = undefined;
      }
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
        title: '用户设定管理',
        subtitle: '聊天身份、人设与用户档案',
        onBack: () => {
            ROOT_PATH_STACK.pop();
        }
      }) {
        HeaderAction({ label: '刷新', marker: 'userpage-refresh-1', available: !this.busy && !this.preferencesBusy,
          pending: this.preferencesBusy || this.loading,
          onAction: async (): Promise<void> => { await this.reload(); this.preferencesReload++; } })
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
  
        NativePreferencesPanel({ identity: true, reloadToken: this.preferencesReload,
          onActivityChange: (active: boolean): void => { this.preferencesBusy = active; } })
        Button(this.showProfiles ? '收起其他用户档案' : '管理其他用户档案', { type: ButtonType.Normal })
          .onClick((): void => { this.showProfiles = !this.showProfiles; })
        .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      if (this.showProfiles) {
        Column() {
          Column({ space: Spacing.md }) {
            if (this.loading) {
              Text('读取中…').fontSize(Typography.caption).fontColor(this.uiColors.textTertiary)
            } else {
              if (this.users.length === 0) {
                Column({ space: 6 }) {
                  EmptyHint('用户存储是空的', '这不是故障：应用默认使用 default-user 目录跑聊天', this.uiColors)
                  Text('当前聊天使用默认资料库。其他用户档案用于记录独立偏好，不会切换聊天数据；聊天名字和人设请在上方设置。')
                    .fontSize(Typography.micro)
                    .fontColor(this.uiColors.textTertiary)
                    .width('100%')
                }
                .width('100%')
                .padding(Spacing.md)
                .borderRadius(GLASS_CARD.radius)
                .backgroundColor(this.uiColors.bgSurface)
                .border({ width: 1, color: this.uiColors.borderSubtle })
  
                this.createCard()
              } else {
                Column({ space: 6 }) {
                  SectionTitle('用户列表', this.uiColors)
                  ForEach(this.users, (user: UserProfile) => {
                    Row({ space: Spacing.sm }) {
                      Text(user.username)
                        .fontSize(Typography.caption)
                        .fontColor(this.selected !== undefined && this.selected!.id === user.id
                          ? this.uiColors.accent : this.uiColors.textPrimary)
                        .layoutWeight(1)
                        .maxLines(1)
                      Text(user.id.substring(0, Math.min(10, user.id.length)))
                        .fontSize(Typography.micro)
                        .fontColor(this.uiColors.textTertiary)
                      Button('编辑', { type: ButtonType.Normal })
                        .fontSize(UIType.micro)
                        .constraintSize({ minHeight: 44 })
                        .onClick(() => {
                          this.select(user);
                        })
                      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button('删除', { type: ButtonType.Normal })
                        .fontSize(UIType.micro)
                        .constraintSize({ minHeight: 44 })
                        .backgroundColor(this.uiColors.danger)
                        .enabled(!this.busy)
                        .onClick(() => {
                          this.remove(user);
                        })
                    .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Danger))
      }
                    .width('100%')
                    .padding({ top: 4, bottom: 4 })
                  }, (user: UserProfile) => user.id)
                }
                .width('100%')
                .padding(Spacing.md)
                .borderRadius(GLASS_CARD.radius)
                .backgroundColor(this.uiColors.bgSurface)
                .border({ width: 1, color: this.uiColors.borderSubtle })
  
                this.createCard()
                if (this.selected !== undefined) {
                  this.editCard()
                }
              }
            }
          }
          .width('100%')
          .padding({ bottom: Spacing.xxl })
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
  createCard() {
    Column({ space: Spacing.sm }) {
      SectionTitle('新建用户', this.uiColors)
      Row({ space: Spacing.sm }) {
        TextInput({ text: this.newUserName, placeholder: '用户名' })
          .fontColor(this.uiColors.textPrimary)
          .placeholderColor(this.uiColors.textTertiary)
          .backgroundColor(this.uiColors.bgSurfaceHigh)
          .borderRadius(UIRadius.sm)
          .fontSize(Typography.caption)
          .constraintSize({ minHeight: 44 })
          .layoutWeight(1)
          .backgroundColor(this.uiColors.bgSurfaceHigh)
          .borderRadius(Radius.sm)
          .onChange((value: string) => {
            this.newUserName = value;
          })
        .attributeModifier(new InputFieldStyle(this.uiColors))
      Button('创建', { type: ButtonType.Normal })
          .fontSize(UIType.caption)
          .constraintSize({ minHeight: 44 })
          .enabled(!this.busy)
          .onClick(() => {
            this.createUser();
          })
      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      }
      .width('100%')
    }
    .width('100%')
    .padding(Spacing.md)
    .borderRadius(GLASS_CARD.radius)
    .backgroundColor(this.uiColors.bgSurface)
    .border({ width: 1, color: this.uiColors.borderSubtle })
  }

  @Builder
  editCard() {
    Column({ space: Spacing.sm }) {
      SectionTitle(`编辑：${this.selected !== undefined ? this.selected!.username : ''}`, this.uiColors)
      this.field('用户名', this.editName, (v: string) => {
        this.editName = v;
      })
      this.field('头像路径 / URL', this.editAvatar, (v: string) => {
        this.editAvatar = v;
      })
      this.field('主题 theme', this.editTheme, (v: string) => {
        this.editTheme = v;
      })

      Text('界面')
        .fontSize(Typography.micro)
        .fontColor(this.uiColors.textTertiary)
        .width('100%')
      this.field('头像形状 avatar_style', this.editAvatarStyle, (v: string) => {
        this.editAvatarStyle = v;
      })
      this.field('聊天显示 chat_display', this.editChatDisplay, (v: string) => {
        this.editChatDisplay = v;
      })
      this.field('字号 font_size', this.editFontSize, (v: string) => {
        this.editFontSize = v;
      })
      this.field('模糊强度 blur_strength', this.editBlur, (v: string) => {
        this.editBlur = v;
      })
      Row({ space: Spacing.sm }) {
        Text('显示时间戳')
          .fontSize(Typography.caption)
          .fontColor(this.uiColors.textSecondary)
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.editTimestamps })
          .selectedColor(this.uiColors.accent)
          .onChange((on: boolean) => {
            this.editTimestamps = on;
          })
      }
      .width('100%')

      Text('生成参数')
        .fontSize(Typography.micro)
        .fontColor(this.uiColors.textTertiary)
        .width('100%')
      this.field('上下文长度 max_context_length', this.editMaxContext, (v: string) => {
        this.editMaxContext = v;
      })
      this.field('回复长度 response_length', this.editRespLen, (v: string) => {
        this.editRespLen = v;
      })
      this.field('temperature', this.editTemp, (v: string) => {
        this.editTemp = v;
      })
      this.field('top_p', this.editTopP, (v: string) => {
        this.editTopP = v;
      })
      this.field('top_k', this.editTopK, (v: string) => {
        this.editTopK = v;
      })
      this.field('repetition_penalty', this.editRepPen, (v: string) => {
        this.editRepPen = v;
      })

      Button('保存用户设置', { type: ButtonType.Normal })
        .fontSize(Typography.caption)
        .constraintSize({ minHeight: 44 })
        .width('100%')
        .enabled(!this.busy)
        .onClick(() => {
          this.save();
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
  field(label: string, value: string, onChange: (v: string) => void) {
    Row({ space: Spacing.sm }) {
      Text(label)
        .fontSize(Typography.micro)
        .fontColor(this.uiColors.textTertiary)
        .width('42%')
        .maxLines(1)
      TextInput({ text: value })
        .fontColor(this.uiColors.textPrimary)
        .placeholderColor(this.uiColors.textTertiary)
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(UIRadius.sm)
        .fontSize(Typography.micro)
        .constraintSize({ minHeight: 44 })
        .layoutWeight(1)
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(Radius.sm)
        .onChange((v: string) => {
          onChange(v);
        })
    .attributeModifier(new InputFieldStyle(this.uiColors))
      }
    .width('100%')
  }
}
