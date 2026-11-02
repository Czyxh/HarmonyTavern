import { COLORS, ColorTokens } from '../theme/Tokens';
import { SurfaceStyle } from '../theme/SurfaceStyles';
import { ActionButtonStyle, ActionTone, InputFieldStyle } from '../theme/ControlStyles';
import { iconTint } from '../theme/IconTint';
import { BrandIcon } from './BrandIcon';

export interface SettingsChoice { id: string; label: string; detail?: string; model?: string; }

@Builder
function noFooter() {}

@Component
export struct SettingsPicker {
  @StorageProp('uiColors') colors: ColorTokens = COLORS;
  @StorageProp('reduceMotion') reduceMotion: boolean = false;
  @Prop title: string = '';
  @Prop selectedId: string = '';
  @Prop options: SettingsChoice[] = [];
  @Prop placeholder: string = '请选择';
  @Prop emptyText: string = '暂无可选项';
  @Prop marker: string = '';
  @Prop available: boolean = true;
  @BuilderParam footer: () => void = noFooter;
  onSelect: (id: string) => void = (_id: string): void => {};
  @State expanded: boolean = false;
  @State query: string = '';
  @State limit: number = 60;

  private selectedLabel(): string {
    return this.options.find((item: SettingsChoice): boolean => item.id === this.selectedId)?.label ?? this.placeholder;
  }
  private selectedModel(): string {
    return this.options.find((item: SettingsChoice): boolean => item.id === this.selectedId)?.model ?? '';
  }
  private filtered(): SettingsChoice[] {
    const query: string = this.query.trim().toLowerCase();
    return this.options.filter((item: SettingsChoice): boolean =>
      (item.label + ' ' + (item.detail ?? '')).toLowerCase().includes(query));
  }
  private toggle(): void {
    this.getUIContext().animateTo({ duration: this.reduceMotion ? 0 : 180, curve: Curve.EaseInOut }, (): void => {
      this.expanded = !this.expanded;
    });
    if (!this.expanded) { this.query = ''; this.limit = 60; }
  }
  build() {
    Column({ space: 10 }) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 12 }) {
          if (this.selectedModel() !== '') { BrandIcon({ model: this.selectedModel(), diameter: 24 }) }
          Column({ space: 5 }) {
            if (this.title !== '') { Text(this.title).fontSize(13).fontColor(this.colors.textSecondary).width('100%') }
            Text(this.selectedLabel()).fontSize(15).fontColor(this.colors.textPrimary)
              .width('100%').maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Image($r('app.media.icon_chevron')).width(16).height(16).colorFilter(iconTint(this.colors.textSecondary))
            .rotate({ angle: this.expanded ? 90 : 0 })
        }.width('100%')
      }.attributeModifier(new ActionButtonStyle(this.colors)).width('100%').height('auto').padding(14)
        .id(this.marker).accessibilityText(this.title + '，' + this.selectedLabel() + (this.expanded ? '，收起选项' : '，展开选项'))
        .onClick((): void => { this.toggle(); })
      if (this.expanded) {
        Column({ space: 8 }) {
          if (this.options.length > 8) {
            TextInput({ text: this.query, placeholder: '搜索选项' }).attributeModifier(new InputFieldStyle(this.colors))
              .id(this.marker + '-search').onChange((value: string): void => { this.query = value; this.limit = 60; })
          }
          ForEach(this.filtered().slice(0, this.limit), (item: SettingsChoice) => {
            Button({ type: ButtonType.Normal }) {
              Row({ space: 12 }) {
                if (item.model !== undefined && item.model !== '') { BrandIcon({ model: item.model, diameter: 24 }) }
                Column({ space: 5 }) {
                  Text(item.label).fontSize(15).fontColor(this.selectedId === item.id ? this.colors.accent : this.colors.textPrimary)
                    .width('100%').wordBreak(WordBreak.BREAK_ALL)
                  if (item.detail !== undefined && item.detail !== '') {
                    Text(item.detail).fontSize(12).fontColor(this.colors.textSecondary).width('100%').wordBreak(WordBreak.BREAK_ALL)
                  }
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Text(this.selectedId === item.id ? '✓' : '').fontSize(16).fontColor(this.colors.accent)
              }.width('100%')
            }.attributeModifier(new ActionButtonStyle(this.colors, this.selectedId === item.id ? ActionTone.Selected : ActionTone.Normal))
              .width('100%').height('auto').constraintSize({ minHeight: 48 }).padding(12)
              .id(this.marker + '-option-' + item.id).accessibilitySelected(this.selectedId === item.id)
              .onClick((): void => { this.onSelect(item.id); this.toggle(); })
          }, (item: SettingsChoice): string => item.id)
          if (this.filtered().length === 0) {
            Text(this.query === '' ? this.emptyText : '没有匹配的选项').fontSize(13).fontColor(this.colors.textSecondary).width('100%')
          }
          if (this.filtered().length > this.limit) {
            Button('显示更多').attributeModifier(new ActionButtonStyle(this.colors)).width('100%')
              .onClick((): void => { this.limit += 60; })
          }
          this.footer()
        }.width('100%').padding(12).borderRadius(20).attributeModifier(new SurfaceStyle(this.colors, 20))
          .id(this.marker + '-expanded').transition(this.reduceMotion ? TransitionEffect.IDENTITY : TransitionEffect.OPACITY)
      }
    }.width('100%').enabled(this.available)
  }
}
