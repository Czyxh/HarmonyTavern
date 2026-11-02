import { RpgThemes } from '../theme/RpgThemes';
import { COLORS, ColorTokens } from '../theme/Tokens';
import { iconTint } from '../theme/IconTint';
import { MOTION_REDUCE_KEY } from '../theme/Motion';
import { WorldState, WorldMeter, WorldCondition, WorldItem, WorldQuest, WorldRelationship, worldMeterLabel, worldMeterPercent, worldLocationLabel } from '../backend/NativeWorld';

export function emptyWorldState(): WorldState {
  return { version: 1, title: '', subject: '', layout: 'compact', location: { region: '', place: '', detail: '' },
    meters: [], conditions: [], inventory: [], quests: [], relationships: [], note: '' };
}

@Component
export struct WorldStatusHud {
  @StorageProp('uiColors') colors: ColorTokens = COLORS;
  @StorageProp(MOTION_REDUCE_KEY) reduceMotion: boolean = false;
  @Prop state: WorldState = emptyWorldState();
  @Prop ready: boolean = false;
  @Prop busy: boolean = false;
  onDetails: () => void = (): void => {};
  onInventory: () => void = (): void => {};

  private primaryMeter(): WorldMeter {
    return this.state.meters.find((meter: WorldMeter): boolean => meter.kind === 'health') ??
      { label: this.ready ? '未定义指标' : '血量', unit: '', kind: 'health' };
  }

  private meterColor(): ResourceColor {
    return '#D64545';
  }

  private healthPercent(): number | undefined {
    const meter: WorldMeter = this.primaryMeter();
    if (!this.ready || meter.value === undefined || meter.value === null || meter.max === undefined ||
      meter.max === null || !Number.isFinite(meter.value) || !Number.isFinite(meter.max) || meter.max <= 0) { return undefined; }
    return worldMeterPercent(meter);
  }

  private percentLabel(): string {
    const percent: number | undefined = this.healthPercent();
    return percent === undefined ? '—' : (this.primaryMeter().estimated === true ? '约 ' : '') + Math.round(percent) + '%';
  }

  build() {
    Row({ space: 4 }) {
      Row({ space: 6 }) {
        Progress({ value: this.healthPercent() ?? 0, total: 100, type: ProgressType.Linear })
          .color(this.meterColor()).backgroundColor('#2ED64545').direction(Direction.Ltr)
          .style({ strokeWidth: 6, enableSmoothEffect: !this.reduceMotion }).height(6).layoutWeight(1)
          .accessibilityText(this.healthPercent() === undefined ? '血量未确认' : (this.primaryMeter().estimated === true ? '血量估算 ' : '血量 ') + this.percentLabel())
          .id('world-hud-health')
        Text(this.percentLabel()).fontSize(12).fontWeight(FontWeight.Medium)
          .fontColor(this.colors.textPrimary).width(64).textAlign(TextAlign.End).maxLines(1)
          .id('world-health-percent')
      }.direction(Direction.Ltr).layoutWeight(1.3).id('world-health-left')
      if (this.ready && this.state.conditions.length > 0) {
        Scroll() {
          Row({ space: 6 }) {
            ForEach(this.state.conditions, (condition: WorldCondition) => {
              Text(condition.name).fontSize(11).maxLines(1)
                .fontColor(condition.kind === 'negative' ? this.meterColor() : this.colors.textSecondary)
            })
          }
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
          .layoutWeight(1).height(24).id('world-status-right')
      }
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.icon_world_inventory')).width(22).height(22).colorFilter(iconTint(this.colors.textPrimary))
          .accessibilityLevel('no')
      }.width(48).height(48).backgroundColor(Color.Transparent).id('chat-world-inventory')
        .accessibilityText('打开人物背包物品栏').onClick((): void => { this.onInventory(); })
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.icon_world_status')).width(22).height(22).colorFilter(iconTint(this.colors.textPrimary))
          .accessibilityLevel('no')
      }.width(48).height(48).backgroundColor(Color.Transparent).id('chat-world-details')
        .accessibilityText('查看人物状态、负面效果与具体位置').onClick((): void => { this.onDetails(); })
    }.width('100%').height(48).id('world-status-hud')
  }
}

@Component
export struct WorldStatusDetails {
  @StorageProp('uiColors') colors: ColorTokens = COLORS;
  @Prop state: WorldState = emptyWorldState();
  @Prop section: string = 'all';
  @Prop actionsAvailable: boolean = false;
  onItemAction: (index: number, action: string) => void = (): void => {};

  @Builder
  itemAction(item: WorldItem, index: number) {
    Row({ space: 12 }) {
      Button(item.equipment === true ? (item.equipped === true ? '卸下' : '装备') : '使用')
        .height(44).padding({ left: 16, right: 16 }).fontSize(14)
        .fontColor(this.colors.accent).backgroundColor(this.colors.headerButtonTint)
        .enabled(this.actionsAvailable && (item.equipment === true ? item.quantity !== 0 :
          item.quantity !== undefined && item.quantity !== null && item.quantity >= 1))
        .id('world-item-primary-' + index)
        .onClick((): void => { this.onItemAction(index, item.equipment === true ? (item.equipped === true ? 'unequip' : 'equip') : 'use'); })
      Button('丢弃').height(44).padding({ left: 16, right: 16 }).fontSize(14)
        .fontColor(this.colors.danger).backgroundColor(Color.Transparent).enabled(this.actionsAvailable)
        .id('world-item-discard-' + index).onClick((): void => { this.onItemAction(index, 'discard'); })
    }.width('100%')
  }

  private questStatus(status: string): string {
    if (status === 'active') { return '进行中'; }
    if (status === 'completed') { return '已完成'; }
    if (status === 'failed') { return '未达成'; }
    if (status === 'on_hold') { return '暂缓'; }
    return '进展未确认';
  }

  private relationshipValue(relation: WorldRelationship): string {
    if (relation.value === undefined || relation.value === null) { return '好感度未确认'; }
    return '好感度 ' + relation.value + (relation.max === undefined || relation.max === null ? '' : ' / ' + relation.max);
  }

  build() {
    Column({ space: 18 }) {
      Text(this.state.title + ' · ' + this.state.subject).fontSize(19).fontWeight(FontWeight.Medium)
        .fontColor(this.colors.textPrimary).width('100%')
      if (this.section === 'all' || this.section === 'status') {
        Column({ space: 8 }) {
          Text('具体位置').fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.colors.textPrimary).width('100%')
          Text(worldLocationLabel(this.state.location)).fontSize(15).fontColor(this.colors.textPrimary).width('100%')
          if (this.state.location.detail !== '') {
            Text(this.state.location.detail).fontSize(14).fontColor(this.colors.textSecondary).lineHeight(22).width('100%')
          }
        }.width('100%').id('world-location')
        Column({ space: 10 }) {
          Text('人物指标').fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.colors.textPrimary).width('100%')
          if (this.state.meters.length === 0) {
            Text('未确认').fontSize(14).fontColor(this.colors.textSecondary).width('100%')
          }
          ForEach(this.state.meters, (meter: WorldMeter, index: number) => {
            Row({ space: 10 }) {
              Text(meter.label).fontSize(14).fontColor(this.colors.textSecondary).layoutWeight(1)
              Text(worldMeterLabel(meter)).fontSize(14).fontColor(this.colors.textPrimary)
            }.width('100%').id('world-detail-meter-' + index)
          }, (meter: WorldMeter, index: number): string => String(index) + meter.label)
        }.width('100%')
        Column({ space: 10 }) {
          Text('状态与负面效果').fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.colors.textPrimary).width('100%')
          if (this.state.conditions.length === 0) {
            Text('暂无记录').fontSize(14).fontColor(this.colors.textSecondary).width('100%')
          }
          ForEach(this.state.conditions, (condition: WorldCondition) => {
            Column({ space: 4 }) {
              Text((condition.kind === 'negative' ? '负面 · ' : condition.kind === 'positive' ? '增益 · ' : '状态 · ') + condition.name)
                .fontSize(15).fontWeight(FontWeight.Medium).fontColor(condition.kind === 'negative' ? this.colors.danger : this.colors.textPrimary).width('100%')
              if (condition.detail !== '') { Text(condition.detail).fontSize(14).fontColor(this.colors.textSecondary).lineHeight(22).width('100%') }
            }.width('100%')
          })
        }.width('100%').id('world-conditions')
      }
      if (this.section === 'all' || this.section === 'journal' || this.section === 'quests') {
        Column({ space: 12 }) {
          Text('任务书').fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.colors.textPrimary).width('100%')
          if ((this.state.quests ?? []).length === 0) {
            Text('暂无任务记录').fontSize(14).fontColor(this.colors.textSecondary).width('100%')
          }
          ForEach(this.state.quests ?? [], (quest: WorldQuest, index: number) => {
            Column({ space: 6 }) {
              Text(quest.name).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.colors.textPrimary).width('100%')
              Text(this.questStatus(quest.status)).fontSize(12).fontColor(this.colors.accent).width('100%')
              if (quest.detail !== '') { Text(quest.detail).fontSize(14).fontColor(this.colors.textSecondary).lineHeight(22).width('100%') }
            }.width('100%').padding(12).backgroundColor(this.colors.headerButtonTint).borderRadius(RpgThemes.radius(14))
              .border({ width: RpgThemes.active() === undefined ? 0 : RpgThemes.borderWidth(0.65), color: this.colors.borderSubtle }).id('world-quest-' + index)
          })
        }.width('100%').id('world-quests')
      }
      if (this.section === 'all' || this.section === 'journal' || this.section === 'relationships') {
        Column({ space: 12 }) {
          Text('人物关系与好感度').fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.colors.textPrimary).width('100%')
          if ((this.state.relationships ?? []).length === 0) {
            Text('暂无关系记录').fontSize(14).fontColor(this.colors.textSecondary).width('100%')
          }
          ForEach(this.state.relationships ?? [], (relation: WorldRelationship, index: number) => {
            Column({ space: 6 }) {
              Text(relation.name).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.colors.textPrimary).width('100%')
              Text(this.relationshipValue(relation)).fontSize(13).fontColor(this.colors.accent).width('100%')
              if (relation.detail !== '') { Text(relation.detail).fontSize(14).fontColor(this.colors.textSecondary).lineHeight(22).width('100%') }
            }.width('100%').padding(12).backgroundColor(this.colors.headerButtonTint).borderRadius(RpgThemes.radius(14))
              .border({ width: RpgThemes.active() === undefined ? 0 : RpgThemes.borderWidth(0.65), color: this.colors.borderSubtle }).id('world-relationship-' + index)
          })
        }.width('100%').id('world-relationships')
      }
      if (this.section === 'all' || this.section === 'inventory') {
        Column({ space: 10 }) {
          Text('背包物品栏').fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.colors.textPrimary).width('100%')
          if (this.state.inventory.length === 0) {
            Text('暂无物品记录').fontSize(14).fontColor(this.colors.textSecondary).width('100%')
          }
          ForEach(this.state.inventory, (item: WorldItem, index: number) => {
            Column({ space: 4 }) {
              Row({ space: 8 }) {
                Text(item.name).fontSize(15).fontColor(this.colors.textPrimary).layoutWeight(1)
                Text(item.quantity === undefined || item.quantity === null ? '数量未确认' : '× ' + item.quantity)
                  .fontSize(13).fontColor(this.colors.textSecondary)
              }.width('100%')
              if (item.detail !== '') { Text(item.detail).fontSize(14).fontColor(this.colors.textSecondary).lineHeight(22).width('100%') }
              if (item.equipped === true) { Text('已装备' + (item.slot ? ' · ' + item.slot : '')).fontSize(12).fontColor(this.colors.accent) }
              this.itemAction(item, index)
            }.width('100%').padding(12).backgroundColor(this.colors.headerButtonTint).borderRadius(RpgThemes.radius(14))
              .border({ width: RpgThemes.active() === undefined ? 0 : RpgThemes.borderWidth(0.65), color: this.colors.borderSubtle }).id('world-inventory-' + index)
          })
        }.width('100%').id('world-inventory')
      }
      if (this.section === 'equipment') {
        Column({ space: 12 }) {
          if (!this.state.inventory.some((item: WorldItem): boolean => item.equipment === true)) {
            Text('暂无已确认的装备').fontSize(14).fontColor(this.colors.textSecondary).width('100%')
          }
          ForEach(this.state.inventory, (item: WorldItem, index: number) => {
            if (item.equipment === true) {
              Column({ space: 6 }) {
                Text(item.name).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.colors.textPrimary).width('100%')
                Text((item.equipped === true ? '已装备' : '未装备') + (item.slot ? ' · ' + item.slot : ''))
                  .fontSize(13).fontColor(item.equipped === true ? this.colors.accent : this.colors.textSecondary).width('100%')
                if (item.detail !== '') { Text(item.detail).fontSize(14).fontColor(this.colors.textSecondary).lineHeight(22).width('100%') }
                this.itemAction(item, index)
              }.width('100%').padding(12).backgroundColor(this.colors.headerButtonTint).borderRadius(RpgThemes.radius(14))
              .border({ width: RpgThemes.active() === undefined ? 0 : RpgThemes.borderWidth(0.65), color: this.colors.borderSubtle }).id('world-equipment-' + index)
            }
          })
        }.width('100%').id('world-equipment')
      }
    }.width('100%')
  }
}
