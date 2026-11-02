import { ActionButtonStyle, ActionTone, InputFieldStyle } from '../theme/ControlStyles';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { PageSurface } from '../components/PageSurface';
import { Radius as UIRadius, Typography as UIType } from '../theme/Tokens';
import { PageHeader } from '../components/PageHeader';
// 日志页（P8-10）：对应原项目 src/scripts/tauri/setting/dev-logs-app 的 LiveLogPanel。
//
// 原项目有两块：实时日志（LiveLogPanel）和 LLM API 日志（LlmApiLogsPanel）。
// 鸿蒙端：
//   - 实时日志 → 用 CallLog 记录的真实命令调用（命令名/耗时/成功失败/错误码）实时刷新，
//     这是等价物，不是假数据。
//   - LLM API 日志 → **没有后端命令可读**（Rust 核心未暴露），此页明确说明并留位。
//     要补齐需要给 host crate 增加一条读日志文件命令（已记入 docs/功能对齐清单.md）。
//
// 对应 DevEco 工程路径：entry/src/main/ets/pages/LogsPage.ets
import { Backend } from '../backend/Backend';
import { CallLog, CallLogEntry } from '../backend/CallLog';
import { ROOT_PATH_STACK } from '../nav/RootNav';
import { Radius, Spacing, Typography } from '../theme/Tokens';
import { GLASS_CARD, GLASS_HEADER, glassEffect } from '../theme/Glass';
import { SectionTitle } from '../components/Builders';

@Component
export struct LogsPage {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @State entries: CallLogEntry[] = [];
  @State filter: string = '';
  @State onlyErrors: boolean = false;
  @State selectedSeq: number = 0;
  @State autoRefresh: boolean = true;
  @State total: number = 0;
  @State errors: number = 0;
  private timer: number = -1;

  aboutToAppear(): void {
    this.refresh();
    this.timer = setInterval(() => {
      if (this.autoRefresh) {
        this.refresh();
      }
    }, 1500);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  refresh(): void {
    const all: CallLogEntry[] = CallLog.list();
    const filtered: CallLogEntry[] = [];
    const needle: string = this.filter.trim().toLowerCase();
    for (let i = 0; i < all.length; i++) {
      const entry: CallLogEntry = all[i];
      if (this.onlyErrors && entry.ok) {
        continue;
      }
      if (needle !== '' && entry.command.toLowerCase().indexOf(needle) < 0
        && entry.detail.toLowerCase().indexOf(needle) < 0) {
        continue;
      }
      filtered.push(entry);
    }
    this.entries = filtered;
    this.total = CallLog.size();
    this.errors = CallLog.errorCount();
  }

  @Builder
  pageTopBar() {
    PageHeader({
        title: '日志',
        subtitle: '运行记录与问题排查',
        onBack: () => {
            ROOT_PATH_STACK.pop();
        }
      }) {
        Button('清空', { type: ButtonType.Normal })
        .fontSize(UIType.caption)
        .constraintSize({ minHeight: 44 })
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .fontColor(this.uiColors.textSecondary)
        .onClick(() => {
        CallLog.clear();
        this.refresh();
        })
      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Danger))
      }
  }

  @Builder
  buildSurfaceContent() {
      Column({ space: Spacing.sm }) {
        
  
        Row({ space: Spacing.sm }) {
          TextInput({ text: this.filter, placeholder: '过滤命令名或错误信息' })
            .fontColor(this.uiColors.textPrimary)
            .placeholderColor(this.uiColors.textTertiary)
            .backgroundColor(this.uiColors.bgSurfaceHigh)
            .borderRadius(UIRadius.sm)
            .fontSize(Typography.micro)
            .constraintSize({ minHeight: 44 })
            .layoutWeight(1)
            .backgroundColor(this.uiColors.bgSurfaceHigh)
            .borderRadius(Radius.sm)
            .onChange((value: string) => {
              this.filter = value;
              this.refresh();
            })
          .attributeModifier(new InputFieldStyle(this.uiColors))
      Button(this.onlyErrors ? '只看错误' : '全部', { type: ButtonType.Normal })
            .fontSize(UIType.caption)
            .constraintSize({ minHeight: 44 })
            .backgroundColor(this.onlyErrors ? this.uiColors.accent : this.uiColors.bgSurfaceHigh)
            .fontColor(this.onlyErrors ? this.uiColors.textInverse : this.uiColors.textSecondary)
            .onClick(() => {
              this.onlyErrors = !this.onlyErrors;
              this.refresh();
            })
          .attributeModifier(new ActionButtonStyle(this.uiColors, (this.onlyErrors) ? ActionTone.Selected : ActionTone.Normal))
      Button(this.autoRefresh ? '自动刷新中' : '已暂停', { type: ButtonType.Normal })
            .fontSize(UIType.caption)
            .constraintSize({ minHeight: 44 })
            .backgroundColor(this.uiColors.bgSurfaceHigh)
            .fontColor(this.uiColors.textSecondary)
            .onClick(() => {
              this.autoRefresh = !this.autoRefresh;
            })
        .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
        .width('100%')
        .padding({ left: Spacing.md, right: Spacing.md })
  
        Text(`共 ${this.total} 条调用记录，失败 ${this.errors} 条 · 显示 ${this.entries.length} 条`)
          .fontSize(Typography.micro)
          .fontColor(this.uiColors.textTertiary)
          .width('100%')
          .padding({ left: Spacing.md })
  
        Column() {
          Column({ space: 4 }) {
            if (this.entries.length === 0) {
              Text('还没有命令调用记录。随便点几下界面就会产生。')
                .fontSize(Typography.caption)
                .fontColor(this.uiColors.textTertiary)
                .width('100%')
                .padding(Spacing.md)
            } else {
              ForEach(this.entries, (entry: CallLogEntry) => {
                Column({ space: 2 }) {
                  Row({ space: 6 }) {
                    Text(entry.at)
                      .fontSize(Typography.micro)
                      .fontColor(this.uiColors.textTertiary)
                    Text(entry.command)
                      .fontSize(Typography.micro)
                      .fontColor(entry.ok ? this.uiColors.textSecondary : this.uiColors.danger)
                      .layoutWeight(1)
                      .maxLines(1)
                    Text(`${entry.ms}ms`)
                      .fontSize(Typography.micro)
                      .fontColor(this.uiColors.textTertiary)
                  }
                  .width('100%')
                  if (this.selectedSeq === entry.seq || !entry.ok) {
                    Text(entry.detail)
                      .fontSize(Typography.micro)
                      .fontColor(entry.ok ? this.uiColors.textTertiary : this.uiColors.danger)
                      .width('100%')
                      .maxLines(4)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                }
                .width('100%')
                .padding({ top: 4, bottom: 4, left: 8, right: 8 })
                .borderRadius(Radius.sm)
                .backgroundColor(this.selectedSeq === entry.seq ? this.uiColors.bgSurfaceHigh : Color.Transparent)
                .onClick(() => {
                  this.selectedSeq = this.selectedSeq === entry.seq ? 0 : entry.seq;
                })
              }, (entry: CallLogEntry) => `${entry.seq}`)
            }
  
            Column({ space: 4 }) {
              SectionTitle('LLM API 日志', this.uiColors)
              Text('原项目这块来自 Tauri 侧日志通道；鸿蒙端 Rust 核心没有暴露读取命令，暂无法展示。'
                + '已记录为待补项（需要在 host crate 增加读取命令）。')
                .fontSize(Typography.micro)
                .fontColor(this.uiColors.textTertiary)
                .width('100%')
            }
            .width('100%')
            .padding(Spacing.md)
            .borderRadius(GLASS_CARD.radius)
            .backgroundColor(this.uiColors.bgSurface)
            .border({ width: 1, color: this.uiColors.borderSubtle })
          }
          .width('100%')
          .padding({ left: Spacing.md, right: Spacing.md, bottom: Spacing.xxl })
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
