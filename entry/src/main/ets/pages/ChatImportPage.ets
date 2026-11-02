import { ActionButtonStyle, ActionTone } from '../theme/ControlStyles';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { PageSurface } from '../components/PageSurface';
import { SCROLL_EDGE_OPTIONS, SCROLL_NESTED_OPTIONS } from '../theme/ScrollFeedback';
import { PageHeader } from '../components/PageHeader';
import { Radius as UIRadius, Typography as UIType } from '../theme/Tokens';
// 导入聊天记录（独立页面）。
//
// 对应 DevEco 工程路径：entry/src/main/ets/pages/ChatImportPage.ets
//
// 为什么单独一页：聊天记录导入必须先选"导入到哪个角色"，还要选 .jsonl/.json，
// 和角色卡导入（一张 PNG）、世界书导入（一个 worlds/*.json）是三种不同的东西。
// 混在一个页面里，用户点错按钮的概率远高于省下的那一次点击。
//
// 命令：import_character_chats { characterName, filePath, fileType }
//
// 对应 DevEco 工程路径：entry/src/main/ets/pages/ChatImportPage.ets
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Backend, BackendError } from '../backend/Backend';
import { CharacterDto } from '../backend/Types';
import { ROOT_PATH_STACK } from '../nav/RootNav';
import { Radius, Spacing, Touch, Typography } from '../theme/Tokens';
import { copyToSandbox, fileNameOf, pickDocument } from '../utils/ImportFiles';

const DOMAIN: number = 0x0009;
const TAG: string = 'HarmonyTavern';

@Component
export struct ChatImportPage {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  /** 嵌入「管理」页时置 true：隐藏本页的返回头部，由外层统一承载 */
  @Prop embedded: boolean = false;
  @Prop contentBottom: number = 24;
  @State characters: CharacterDto[] = [];
  @State selected: string = '';
  @State statusText: string = '';
  @State errorText: string = '';
  @State busy: boolean = false;

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  aboutToAppear(): void {
    this.reload();
  }

  async reload(): Promise<void> {
    try {
      this.characters = await Backend.getAllCharacters();
      if (this.selected === '' && this.characters.length > 0) {
        this.selected = this.characters[0].name;
      }
    } catch (err) {
      this.errorText = `读取角色失败：${(err as BackendError).message}`;
    }
  }

  async importFromFile(): Promise<void> {
    if (this.busy || this.selected === '') {
      return;
    }
    this.busy = true;
    this.errorText = '';
    this.statusText = '';
    try {
      const uri: string = await pickDocument(this.context(), ['聊天记录|.jsonl,.json', '全部|.*']);
      if (uri === '') {
        return;
      }
      const name: string = fileNameOf(uri, `chat_${Date.now()}.jsonl`);
      const path: string = copyToSandbox(this.context(), uri, name);
      const type: string = name.toLowerCase().endsWith('.json') ? 'json' : 'jsonl';
      const imported: string[] = await Backend.importCharacterChats(this.selected, path, type);
      this.statusText = `已导入 ${imported.length} 个会话到「${this.selected}」`;
    } catch (err) {
      const message: string = (err as BackendError).message;
      this.errorText = `导入聊天记录失败：${message}`;
      hilog.error(DOMAIN, TAG, 'import chats failed: %{public}s', message);
    } finally {
      this.busy = false;
    }
  }

  @Builder
  header() {
    PageHeader({ title: '导入聊天', subtitle: '把收藏带进新的故事', onBack: () => ROOT_PATH_STACK.pop() })
  }

  @Builder
  pageBody() {
    Column() {
      

      Column() {
        Column({ space: Spacing.md }) {
          Text('先把聊天记录导入到某个角色名下，再选择文件。'
            + '支持 SillyTavern 的 .jsonl 聊天记录，也支持 .json。')
            .fontSize(Typography.caption)
            .fontColor(this.uiColors.textTertiary)
            .width('100%')

          Text(this.selected === '' ? '还没有角色，先去「角色」页创建' : `目标角色：${this.selected}`)
            .fontSize(Typography.body)
            .fontColor(this.selected === '' ? this.uiColors.warning : this.uiColors.textPrimary)
            .width('100%')

          Scroll() {
            Row({ space: Spacing.sm }) {
              ForEach(this.characters, (character: CharacterDto) => {
                Text(character.name)
                  .fontSize(Typography.caption)
                  .fontColor(character.name === this.selected ? this.uiColors.textInverse : this.uiColors.textSecondary)
                  .padding({ left: Spacing.md, right: Spacing.md, top: Spacing.sm, bottom: Spacing.sm })
                  .backgroundColor(character.name === this.selected ? this.uiColors.accent : this.uiColors.bgSurfaceHigh)
                  .borderRadius(Radius.pill)
                  .onClick(() => {
                    this.selected = character.name;
                  })
              }, (character: CharacterDto) => character.name)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .edgeEffect(EdgeEffect.Spring, SCROLL_EDGE_OPTIONS)
          .nestedScroll(SCROLL_NESTED_OPTIONS)
          .scrollBar(BarState.Off)
          .width('100%')

          Button('从文件选 .jsonl / .json', { type: ButtonType.Normal })
            .fontSize(Typography.body)
            .height(Touch.minTarget)
            .width('100%')
            .backgroundColor(this.uiColors.accent)
            .fontColor(this.uiColors.textInverse)
            .enabled(!this.busy && this.selected !== '')
            .onClick(() => {
              this.importFromFile();
            })

          .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      if (this.statusText !== '') {
            Text(this.statusText)
              .fontSize(Typography.caption)
              .fontColor(this.uiColors.success)
              .width('100%')
          }
          if (this.errorText !== '') {
            Text(this.errorText)
              .fontSize(Typography.caption)
              .fontColor(this.uiColors.danger)
              .width('100%')
          }
        }
        .width('100%')
        .padding({ left: Spacing.lg, right: Spacing.lg, bottom: this.embedded ? this.contentBottom : Spacing.xl })
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
