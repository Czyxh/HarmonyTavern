import { COLORS, ColorTokens } from '../theme/Tokens';
import { PageSurface } from '../components/PageSurface';
import { PageHeader } from '../components/PageHeader';
import { HeaderAction } from '../components/HeaderAction';
import { JellyTabBar, JellyTabItem } from '../components/JellyTabBar';
import { ActionButtonStyle } from '../theme/ControlStyles';
import { glassLightColor } from '../theme/Glass';
import { iconTint } from '../theme/IconTint';
import { BrandIcon } from '../components/BrandIcon';
import { NativeUsage, UsageStatistics, UsageDay, UsageRank } from '../backend/NativeUsage';
import { ROOT_PATH_STACK } from '../nav/RootNav';

interface HeatWeek { key: string; month: string; days: UsageDay[]; }
interface UsageMetric { label: string; value: string; icon: Resource; unit: string; }
const RANGES: JellyTabItem[] = [{ label: '全部', glyph: '' }, { label: '近30天', glyph: '' }, { label: '近12个月', glyph: '' }];
const RANGE_KEYS: string[] = ['all', '30d', '12m'];

@Component
export struct UsageStatisticsPage {
  @StorageProp('uiColors') colors: ColorTokens = COLORS;
  @StorageProp('reduceMotion') reduceMotion: boolean = false;
  @StorageProp('systemBottomInset') safeBottom: number = 0;
  @State selectedRange: number = 2;
  @State displayedRange: number = 2;
  @State contentOpacity: number = 1;
  @State report: UsageStatistics | null = null;
  @State weeks: HeatWeek[] = [];
  @State heatMaximum: number = 1;
  @State selectedDay: UsageDay = { date: '', count: 0 };
  @State busy: boolean = false;
  @State error: string = '';
  @State contentWidth: number = 360;
  private revision: number = 0;
  private alive: boolean = false;
  private heatScroller: Scroller = new Scroller();

  aboutToAppear(): void { this.alive = true; this.load(); }
  aboutToDisappear(): void { this.alive = false; this.revision++; }
  private async load(): Promise<void> {
    const revision: number = ++this.revision;
    const range: number = this.selectedRange;
    this.busy = true; this.error = '';
    if (this.report !== null) {
      this.getUIContext().animateTo({ duration: this.reduceMotion ? 0 : 100, curve: Curve.EaseOut }, (): void => { this.contentOpacity = 0.84; });
    }
    try {
      const report: UsageStatistics = await NativeUsage.get(RANGE_KEYS[range]);
      if (!this.alive || revision !== this.revision) { return; }
      const weeks: HeatWeek[] = this.makeWeeks(report.heat);
      this.getUIContext().animateTo({ duration: this.reduceMotion ? 0 : 220, curve: Curve.EaseOut }, (): void => {
        this.displayedRange = range;
        this.report = report;
        this.selectedDay = report.heat.length > 0 ? report.heat[report.heat.length - 1] : { date: '', count: 0 };
        this.heatMaximum = Math.max(1, ...report.heat.map((day: UsageDay): number => day.count));
        this.weeks = weeks;
        this.contentOpacity = 1;
      });
    } catch (error) {
      if (this.alive && revision === this.revision) {
        this.error = (error as Error).message;
        this.getUIContext().animateTo({ duration: this.reduceMotion ? 0 : 160, curve: Curve.EaseOut }, (): void => { this.contentOpacity = 1; });
      }
    } finally { if (this.alive && revision === this.revision) { this.busy = false; } }
  }
  private weekWidth(): number {
    return this.displayedRange === 1 ? Math.max(13, (this.contentWidth - Math.max(0, this.weeks.length - 1) * 3) / Math.max(1, this.weeks.length)) : 13;
  }
  private rangeStatus(): string {
    if (this.report === null) { return this.busy ? '正在汇总本地记录…' : '读取本地统计'; }
    if (this.busy) { return '正在读取' + RANGES[this.selectedRange].label + ' · 当前显示' + RANGES[this.displayedRange].label; }
    return '当前范围 · ' + RANGES[this.displayedRange].label;
  }
  private makeWeeks(days: UsageDay[]): HeatWeek[] {
    if (days.length === 0) { return []; }
    const start: Date = new Date(days[0].date + 'T12:00:00');
    const padded: UsageDay[] = [];
    for (let i: number = 0; i < start.getDay(); i++) { padded.push({ date: '', count: 0 }); }
    days.forEach((day: UsageDay): void => { padded.push(day); });
    while (padded.length % 7 !== 0) { padded.push({ date: '', count: 0 }); }
    const result: HeatWeek[] = [];
    let previousMonth: string = '';
    for (let i: number = 0; i < padded.length; i += 7) {
      const week: UsageDay[] = padded.slice(i, i + 7);
      const first: UsageDay | undefined = week.find((day: UsageDay): boolean => day.date !== '');
      const month: string = first === undefined ? '' : String(Number(first.date.substring(5, 7))) + '月';
      result.push({ key: week.map((day: UsageDay): string => day.date + ':' + day.count).join('|'), month: month !== previousMonth ? month : '', days: week });
      previousMonth = month;
    }
    return result;
  }
  private format(value: number | undefined): string {
    if (typeof value !== 'number' || !Number.isFinite(value)) { return '—'; }
    if (value >= 1000000) { return (value / 1000000).toFixed(1).replace(/\.0$/, '') + 'M'; }
    if (value >= 1000) { return (value / 1000).toFixed(1).replace(/\.0$/, '') + 'K'; }
    return Math.round(value).toLocaleString();
  }
  private heatColor(count: number): ResourceColor {
    if (count === 0) { return this.colors.headerButtonTint; }
    const max: number = this.heatMaximum;
    return glassLightColor(this.colors.accent, 0.2 + Math.min(1, count / max) * 0.8);
  }
  private stepDay(delta: number): void {
    const days: UsageDay[] = this.report?.heat ?? [];
    const index: number = days.findIndex((day: UsageDay): boolean => day.date === this.selectedDay.date);
    if (index + delta >= 0 && index + delta < days.length) { this.selectedDay = days[index + delta]; }
  }
  private sourceName(name: string): string {
    if (name === 'chat') { return '聊天'; }
    if (name === 'group') { return '群聊'; }
    if (name === 'choices') { return '剧情选项'; }
    if (name === 'compaction') { return '上下文精简'; }
    if (name === 'world') { return '状态生成'; }
    if (name === 'agent') { return 'Agent'; }
    if (name === 'historical') { return '历史聊天用量'; }
    return '其他后台请求';
  }
  private overview(): UsageMetric[] {
    const r: UsageStatistics | null = this.report;
    return [
      { label: '活跃会话', value: this.format(r?.conversations), icon: $r('app.media.nav_chat'), unit: '段' },
      { label: '消息总数', value: this.format(r?.messages), icon: $r('app.media.icon_messages'), unit: '条' },
      { label: '已记录的模型', value: this.format(r?.models), icon: $r('app.media.icon_model'), unit: '个' },
      { label: '活跃天数', value: this.format(r?.active_days), icon: $r('app.media.icon_calendar'), unit: '天' }
    ];
  }
  private tokenMetrics(): UsageMetric[] {
    return [
      { label: '总 Token', value: this.format(this.report?.total), icon: $r('app.media.icon_tokens'), unit: '' },
      { label: '输入', value: this.format(this.report?.input), icon: $r('app.media.icon_input'), unit: '' },
      { label: '输出', value: this.format(this.report?.output), icon: $r('app.media.icon_output'), unit: '' },
      { label: '平均每次聊天请求', value: this.format(this.report?.average), icon: $r('app.media.icon_average'), unit: '' },
      { label: '缓存命中', value: this.format(this.report?.cached), icon: $r('app.media.icon_cache'), unit: '' },
      { label: '缓存命中率', value: typeof this.report?.cache_rate === 'number' ? ((this.report?.cache_rate ?? 0) * 100).toFixed(1) + '%' : '—', icon: $r('app.media.icon_target'), unit: '' }
    ];
  }
  @Builder
  section(title: string, detail: string = '') {
    Column({ space: 5 }) {
      Text(title).fontSize(17).fontWeight(FontWeight.Bold).fontColor(this.colors.textPrimary)
      if (detail !== '') { Text(detail).fontSize(12).lineHeight(19).fontColor(this.colors.textSecondary) }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder
  metricGrid(metrics: UsageMetric[]) {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
      ForEach(metrics, (metric: UsageMetric) => {
        Column({ space: 20 }) {
          Row({ space: 9 }) {
            Stack() { Image(metric.icon).width(18).height(18).colorFilter(iconTint(this.colors.accent)) }
              .width(30).height(30).borderRadius(11).backgroundColor(this.colors.accentContainer)
            Text(metric.label).fontSize(13).fontColor(this.colors.textSecondary).layoutWeight(1)
          }.width('100%')
          Row({ space: 4 }) {
            Text(metric.value).fontSize(29).fontWeight(FontWeight.Bold).fontColor(this.colors.textPrimary)
              .maxLines(1).minFontSize(20).maxFontSize(29).heightAdaptivePolicy(TextHeightAdaptivePolicy.MIN_FONT_SIZE_FIRST).layoutWeight(1)
            Text(metric.unit).fontSize(12).fontColor(this.colors.textTertiary)
          }.width('100%')
        }.width(this.contentWidth < 330 ? '100%' : '48.5%').padding(16).margin({ bottom: 10 })
          .backgroundColor(this.colors.bgSurface).borderRadius(24).border({ radius: 24, width: 0.65, color: this.colors.borderSubtle })
          .accessibilityText(metric.label + '，' + metric.value + metric.unit)
      }, (metric: UsageMetric) => metric.label + ':' + metric.value + ':' + metric.unit)
    }.width('100%')
  }
  @Builder
  ranking(rows: UsageRank[], sources: boolean = false) {
    Column({ space: 0 }) {
      if (rows.length === 0) {
        Text('所选时间内暂无可统计记录').fontSize(13).fontColor(this.colors.textSecondary).padding(20).width('100%')
      }
      ForEach(rows, (row: UsageRank, index: number) => {
        Column({ space: 12 }) {
          Row({ space: 10 }) {
            Text(String(index + 1)).fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.colors.accent).width(20)
            if (!sources) { BrandIcon({ model: row.name, diameter: 20 }) }
            Text(sources ? this.sourceName(row.name) : row.name).fontSize(15).fontWeight(FontWeight.Medium)
              .fontColor(this.colors.textPrimary).layoutWeight(1).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.format(row.value)).fontSize(15).fontColor(this.colors.textSecondary)
          }.width('100%')
          Progress({ value: row.value, total: Math.max(1, rows[0].value), type: ProgressType.Linear })
            .color(this.colors.accent).backgroundColor(this.colors.headerButtonTint).style({ strokeWidth: 5 }).width('100%')
        }.width('100%').padding(16).accessibilityText((sources ? this.sourceName(row.name) : row.name) + '，' + row.value)
      }, (row: UsageRank) => row.name + ':' + row.value + ':' + (rows[0]?.value ?? 0))
    }.width('100%').backgroundColor(this.colors.bgSurface).borderRadius(24)
      .border({ radius: 24, width: 0.65, color: this.colors.borderSubtle })
  }
  @Builder
  heatmap() {
    Column({ space: 12 }) {
      Column({ space: 5 }) {
        Text('活动热力图').fontSize(17).fontWeight(FontWeight.Bold).fontColor(this.colors.textPrimary)
        Text(this.displayedRange === 1 ? '近30天每天的聊天消息数' : '过去12个月每天的聊天消息数 · 可左右滑动查看')
          .fontSize(12).lineHeight(19).fontColor(this.colors.textSecondary).id('usage-heat-window')
      }.width('100%').alignItems(HorizontalAlign.Start)
      Text(String(this.report?.heat_active_days ?? 0) + ' 天活跃 · 最长连续 ' + String(this.report?.heat_longest_streak ?? 0) + ' 天')
        .fontSize(13).fontWeight(FontWeight.Medium).fontColor(this.colors.accent).width('100%').textAlign(TextAlign.End)
      Scroll(this.heatScroller) {
        Row({ space: 3 }) {
          ForEach(this.weeks, (week: HeatWeek) => {
            Column({ space: 3 }) {
              Text(week.month).fontSize(10).fontColor(this.colors.textSecondary).height(24).width(this.weekWidth()).maxLines(2)
              ForEach(week.days, (day: UsageDay, index: number) => {
                Column().width(Math.max(11, this.weekWidth() - 2)).height(this.displayedRange === 1 ? 14 : 11).backgroundColor(day.date === '' ? Color.Transparent : this.heatColor(day.count))
                  .borderRadius(3).border({ radius: 3, width: day.date !== '' && day.date === this.selectedDay.date ? 1 : 0, color: this.colors.accent })
                  .accessibilityText(day.date === '' ? '' : day.date + '，' + day.count + ' 条消息')
                  .onClick((): void => { if (day.date !== '') { this.selectedDay = day; } })
              }, (day: UsageDay, index: number) => day.date || week.key + '-' + index)
            }.width(this.weekWidth())
          }, (week: HeatWeek) => week.key)
        }.padding({ top: 4, bottom: 8 })
          .onAreaChange((previous: Area, current: Area): void => {
            if (Number(previous.width) !== Number(current.width)) { this.heatScroller.scrollEdge(Edge.End); }
          })
      }.opacity(this.contentOpacity).width('100%').height(156).align(Alignment.TopStart).scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
        .onAppear((): void => { this.heatScroller.scrollEdge(Edge.End); })
      Row({ space: 4 }) {
        Blank()
        Text('少').fontSize(11).fontColor(this.colors.textSecondary)
        ForEach([0, 0.25, 0.5, 0.75, 1], (level: number) => {
          Column().width(11).height(11).borderRadius(3)
            .backgroundColor(level === 0 ? this.colors.headerButtonTint : glassLightColor(this.colors.accent, level))
        })
        Text('多').fontSize(11).fontColor(this.colors.textSecondary)
      }.width('100%')
      Row({ space: 8 }) {
        Button() {
          Image($r('app.media.icon_chevron')).width(18).height(18).rotate({ angle: 180 }).colorFilter(iconTint(this.colors.textPrimary))
        }.attributeModifier(new ActionButtonStyle(this.colors)).width(44).accessibilityText('前一天')
          .enabled(this.selectedDay.date !== this.report?.heat[0]?.date).onClick((): void => { if (!this.busy) { this.stepDay(-1); } })
        Text(this.selectedDay.date + ' · ' + this.selectedDay.count + ' 条消息').fontSize(12)
          .fontColor(this.colors.textSecondary).layoutWeight(1).textAlign(TextAlign.Center).id('usage-selected-day')
        Button() {
          Image($r('app.media.icon_chevron')).width(18).height(18).colorFilter(iconTint(this.colors.textPrimary))
        }.attributeModifier(new ActionButtonStyle(this.colors)).width(44).accessibilityText('后一天')
          .enabled(!this.busy && this.selectedDay.date !== this.report?.to).onClick((): void => { if (!this.busy) { this.stepDay(1); } })
      }.width('100%')
    }.width('100%')
  }
  @Builder
  contents() {
    Column({ space: 16 }) {
      Column({ space: 4 }) {
      JellyTabBar({ textOnly: true, items: RANGES, currentIndex: this.selectedRange, containerWidthVp: this.contentWidth,
        onSelect: (index: number): void => { if (index !== this.selectedRange) { this.selectedRange = index; this.load(); } } }).borderRadius(28).clip(true)
      Row({ space: 8 }) {
        if (this.busy) { LoadingProgress().width(16).height(16).color(this.colors.accent) }
        Text(this.rangeStatus()).fontSize(12).fontColor(this.colors.textSecondary).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
      }.width('100%').height(20).id('usage-range-status')
      }.width('100%')
      if (this.error !== '') {
        Text(this.error).fontSize(14).fontColor(this.colors.danger).width('100%')
        Button('重试读取').attributeModifier(new ActionButtonStyle(this.colors)).onClick((): void => { this.load(); })
      }
      if (this.report !== null) {
        Column({ space: 22 }) {
        this.heatmap()
        this.section('总览', '统计所选时间内仍保留的聊天与群聊消息')
        this.metricGrid(this.overview())
        this.section('模型调用排行', 'Top 10 · 按已保存且记录模型名称的 AI 回复条数')
        this.ranking(this.report.model_rank)
        if (this.report.unknown_models > 0) { Text(String(this.report.unknown_models) + ' 条回复未记录模型名称，不猜测归属。').fontSize(12).fontColor(this.colors.textSecondary) }
        this.section('Token 用量', '聊天与后台请求中，服务商实际返回的已记录用量')
        this.metricGrid(this.tokenMetrics())
        Text('缓存已包含在输入中，不重复累加。命中率仅使用同时返回缓存和输入计数的请求；— 表示未提供。平均值按 ' + this.report.average_samples + ' 次有总用量的聊天请求计算。')
          .fontSize(12).lineHeight(20).fontColor(this.colors.textSecondary).width('100%')
        this.section('用量来源', '按已记录总 Token 统计；历史漏记的后台请求无法补回')
        this.ranking(this.report.sources, true)
        this.section('Token 消耗排行', 'Top 10 · 按模型已记录的总 Token')
        this.ranking(this.report.token_rank)
        this.section('统计口径')
        Text('本次范围：' + (this.report.from || '全部历史') + ' — ' + this.report.to + '\n用量记录 ' + this.report.known_usage + ' 次；未提供 ' + this.report.missing_usage + ' 次；部分完成 ' + this.report.partial_usage + ' 次。\n聊天消息会随现有记录变更；请求用量独立保存，删除消息不会抹去已发生的用量。日期按设备本地时区归档。')
          .fontSize(12).lineHeight(21).fontColor(this.colors.textSecondary).width('100%')
        if (this.report.unknown_dates > 0 || this.report.invalid_rows > 0) {
          Text('日期缺失 ' + this.report.unknown_dates + ' 条；无法读取的记录 ' + this.report.invalid_rows + ' 条。缺失日期只纳入“全部”，不填入热力图。')
            .fontSize(12).lineHeight(20).fontColor(this.colors.warning)
        }
        }.width('100%').id('usage-statistics-content')
      }
    }.width('100%').padding({ top: 4, bottom: 20 }).onAreaChange((_old: Area, area: Area): void => { this.contentWidth = Number(area.width); })
  }
  @Builder
  header() {
    PageHeader({ title: '使用统计', onBack: (): void => { ROOT_PATH_STACK.pop(); }, actions: (): void => { this.refresh(); } })
  }
  @Builder
  refresh() { HeaderAction({ marker: 'usage-refresh', label: '刷新使用统计', onAction: async (): Promise<void> => { if (!this.busy) { await this.load(); } } }) }
  build() { PageSurface({ topBar: (): void => { this.header(); }, content: (): void => { this.contents(); }, bottomInset: this.safeBottom + 24, topContentInset: 84 }) }
}
