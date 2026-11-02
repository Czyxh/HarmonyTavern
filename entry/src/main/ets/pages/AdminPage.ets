import { PageSurface } from '../components/PageSurface';
import { ROOT_PATH_STACK } from '../nav/RootNav';
import { SwingContent } from '../components/SwingContent';
import { PageHeader } from '../components/PageHeader';
import { JellyTabBar, JellyTabItem } from '../components/JellyTabBar';
import { ImportPage } from './ImportPage';
import { WorldInfoPage } from './WorldInfoPage';
import { ChatImportPage } from './ChatImportPage';

@Component
export struct AdminPage {
  @State active: number = 0;
  @State displayedSection: number = 0;
  @Prop showHeader: boolean = true;
  @Prop embedded: boolean = false;
  @Prop contentBottom: number = 24;
  private readonly libraryTabs: JellyTabItem[] = [
    { label: '角色卡', glyph: '' },
    { label: '世界书', glyph: '' },
    { label: '聊天记录', glyph: '' }
  ];

  @Builder
  pageTopBar() {
    PageHeader({ title: '资料库', subtitle: '把喜欢的角色与世界带进酒馆',
      showBack: this.showHeader && !this.embedded, onBack: () => ROOT_PATH_STACK.pop() })
  }

  @Builder
  selectedContent() {
    if (this.displayedSection === 0) {
      ImportPage({ embedded: true, contentBottom: this.contentBottom })
    } else if (this.displayedSection === 1) {
      WorldInfoPage({ embedded: true, contentBottom: this.contentBottom })
    } else {
      ChatImportPage({ embedded: true, contentBottom: this.contentBottom })
    }
  }

  @Builder
  buildSurfaceContent() {
      Column({ space: 16 }) {
      Row() {
        JellyTabBar({
          items: this.libraryTabs,
          currentIndex: this.active,
          textOnly: true,
          onSelect: (index: number): void => { this.active = index; }
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
      SwingContent({ activeIndex: this.active,
        onDisplay: (index: number): void => { this.displayedSection = index; },
        content: (): void => { this.selectedContent(); } })
    }
    .width('100%')
      }

  build() {
    PageSurface({ topBar: () => { this.pageTopBar(); }, horizontalInset: 0, bottomInset: 0, content: () => { this.buildSurfaceContent(); } })
  }
}
