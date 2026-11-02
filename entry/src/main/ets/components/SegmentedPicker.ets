import { JellyTabBar, JellyTabItem } from './JellyTabBar';
import { SCROLL_EDGE_OPTIONS, SCROLL_NESTED_OPTIONS } from '../theme/ScrollFeedback';

/** Shared section switcher; longer sets scroll instead of squeezing their labels. */
@Component
export struct SegmentedPicker {
  @Prop items: JellyTabItem[] = [];
  @Prop selectedIndex: number = 0;
  @Prop available: boolean = true;
  @State viewport: number = 340;
  onSelect: (index: number) => void = (_index: number): void => {};
  build() {
    Scroll() {
      JellyTabBar({ items: this.items, currentIndex: this.selectedIndex, textOnly: true,
        onSelect: (index: number): void => { this.onSelect(index); } })
        .width(Math.max(this.viewport, this.items.length * 88))
    }
    .width('100%').height(48).scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, SCROLL_EDGE_OPTIONS).nestedScroll(SCROLL_NESTED_OPTIONS)
    .enabled(this.available)
    .onAreaChange((_old: Area, area: Area): void => { this.viewport = Number(area.width); })
  }
}
