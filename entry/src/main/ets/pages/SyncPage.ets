import { ActionButtonStyle, ActionTone, InputFieldStyle } from '../theme/ControlStyles';
import { HeaderAction } from '../components/HeaderAction';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { PageSurface } from '../components/PageSurface';
import { Radius as UIRadius, Typography as UIType } from '../theme/Tokens';
import { PageHeader } from '../components/PageHeader';
// 同步（P8-9）：对应原项目 src/scripts/tauri/setting/sync-app。
//
// 原面板四段：本机（服务器开关/设备名/配对信息）、设备（已配对列表 + 推送/拉取/删除）、
// 范围（数据集勾选）、进度（上次成功/失败/下次运行）。外加 tt_sync 直连服务器列表。
// 这里按同样顺序搬，数据全部来自真实命令。
//
// 注意：真实同步需要**两台设备**；单机只能验证到"服务端启动/配对信息/数据集目录/自动化配置"。
//
// 对应 DevEco 工程路径：entry/src/main/ets/pages/SyncPage.ets
import { Backend, BackendError } from '../backend/Backend';
import {
  LanSyncPairedDeviceDto,
  LanSyncPairingInfoDto,
  SyncDatasetCatalogDto,
  SyncOperationOptions,
  TtSyncPairedServerDto
} from '../backend/Types';
import { ROOT_PATH_STACK } from '../nav/RootNav';
import { Radius, Spacing, Typography } from '../theme/Tokens';
import { GLASS_CARD, GLASS_HEADER, glassEffect } from '../theme/Glass';
import { EmptyHint, ErrorBannerView, SectionTitle } from '../components/Builders';

/** lan_sync_get_status 的返回（Rust LanSyncStatus，snake_case）。 */
interface LanSyncStatusShape {
  device_name: string;
  running: boolean;
  address?: string;
  available_addresses: string[];
  port: number;
  sync_mode: string;
  manual_default_mode: string;
  sync_mode_overridden: boolean;
  overwrite_policy: string;
}

/** 数据集选择（ttsync-contract DatasetSelection）。 */
interface DatasetSelectionShape {
  policy_version: number;
  dataset_ids: string[];
}

/** sync_automation_get_config 的返回。 */
interface SyncAutomationConfigShape {
  lan_server_auto_start: boolean;
  auto_sync_enabled: boolean;
  interval_minutes: number;
  sync_mode: string;
  selection: DatasetSelectionShape;
}

interface SyncAutomationStatusShape {
  last_result?: string;
  last_run_ms?: number;
  next_run_ms?: number;
  last_error?: string;
}

@Component
export struct SyncPage {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @State loading: boolean = true;
  @State busy: boolean = false;
  @State errorText: string = '';
  @State statusText: string = '';

  @State status: LanSyncStatusShape | undefined = undefined;
  @State pairing: LanSyncPairingInfoDto | undefined = undefined;
  @State devices: LanSyncPairedDeviceDto[] = [];
  @State servers: TtSyncPairedServerDto[] = [];
  @State datasets: string[] = [];
  @State selectedDatasets: string[] = [];
  @State autoConfig: SyncAutomationConfigShape | undefined = undefined;
  @State autoStatus: SyncAutomationStatusShape | undefined = undefined;

  @State deviceName: string = '';
  @State pairUri: string = '';
  @State intervalText: string = '15';

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
      this.status = (await Backend.lanSyncGetStatus()) as LanSyncStatusShape;
      this.deviceName = this.status.device_name;
      this.devices = await Backend.lanSyncListDevices();
      this.servers = await Backend.ttSyncListServers();
      const catalog: SyncDatasetCatalogDto = await Backend.syncGetDatasetCatalog();
      this.datasets = catalog.supported_dataset_ids;
      if (this.selectedDatasets.length === 0) {
        this.selectedDatasets = catalog.default_dataset_ids;
      }
      try {
        this.pairing = await Backend.lanSyncGetPairingInfo();
      } catch (err) {
        this.pairing = undefined;
      }
      try {
        this.autoConfig = (await Backend.syncAutomationGetConfig()) as SyncAutomationConfigShape;
        this.intervalText = String(this.autoConfig.interval_minutes);
        this.autoStatus = (await Backend.syncAutomationGetStatus()) as SyncAutomationStatusShape;
      } catch (err) {
        this.autoConfig = undefined;
      }
    } catch (err) {
      this.errorText = `读取同步状态失败：${(err as BackendError).message}`;
    } finally {
      this.loading = false;
    }
  }

  async toggleServer(): Promise<void> {
    if (this.status === undefined) {
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      if (this.status.running) {
        await Backend.lanSyncStopServer();
        this.statusText = '已停止本机同步服务';
      } else {
        await Backend.lanSyncStartServer();
        this.statusText = '已启动本机同步服务';
      }
      await this.reload();
    } catch (err) {
      this.errorText = `切换服务失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async saveDeviceName(): Promise<void> {
    const name: string = this.deviceName.trim();
    if (name === '') {
      this.errorText = '设备名不能为空';
      return;
    }
    this.busy = true;
    try {
      await Backend.lanSyncSetDeviceName(name);
      this.statusText = `设备名已改为 ${name}`;
      await this.reload();
    } catch (err) {
      this.errorText = `改名失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  selection(): DatasetSelectionShape {
    return { policy_version: 1, dataset_ids: this.selectedDatasets };
  }

  operationOptions(): SyncOperationOptions {
    const options: SyncOperationOptions = {
      selection: this.selection() as ESObject,
      overwrite_policy: 'prefer-newer'
    };
    return options;
  }

  toggleDataset(id: string): void {
    const next: string[] = [];
    let found: boolean = false;
    for (let i = 0; i < this.selectedDatasets.length; i++) {
      if (this.selectedDatasets[i] === id) {
        found = true;
      } else {
        next.push(this.selectedDatasets[i]);
      }
    }
    if (!found) {
      next.push(id);
    }
    this.selectedDatasets = next;
  }

  isSelected(id: string): boolean {
    for (let i = 0; i < this.selectedDatasets.length; i++) {
      if (this.selectedDatasets[i] === id) {
        return true;
      }
    }
    return false;
  }

  async pairByUri(): Promise<void> {
    const uri: string = this.pairUri.trim();
    if (uri === '') {
      this.errorText = '先粘贴对方的配对 URI';
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      const device: LanSyncPairedDeviceDto = await Backend.lanSyncRequestPairing(uri);
      this.statusText = `已配对：${device.device_name}`;
      this.pairUri = '';
      await this.reload();
    } catch (err) {
      this.errorText = `配对失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async pushTo(device: LanSyncPairedDeviceDto): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      await Backend.lanSyncPushToDevice(device.device_id, this.operationOptions());
      this.statusText = `已推送到 ${device.device_name}`;
      await this.reload();
    } catch (err) {
      this.errorText = `推送失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async pullFrom(device: LanSyncPairedDeviceDto): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      await Backend.lanSyncSyncFromDevice(device.device_id, this.operationOptions());
      this.statusText = `已从 ${device.device_name} 拉取`;
      await this.reload();
    } catch (err) {
      this.errorText = `拉取失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async removeDevice(device: LanSyncPairedDeviceDto): Promise<void> {
    this.busy = true;
    try {
      await Backend.lanSyncRemoveDevice(device.device_id);
      this.statusText = `已移除 ${device.device_name}`;
      await this.reload();
    } catch (err) {
      this.errorText = `移除失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async saveAutomation(enabled: boolean): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      const minutes: number = Number.parseInt(this.intervalText, 10);
      const interval: number = Number.isNaN(minutes) || minutes < 1 ? 15 : minutes;
      const config: ESObject = {
        lan_server_auto_start: this.autoConfig !== undefined ? this.autoConfig!.lan_server_auto_start : false,
        auto_sync_enabled: enabled,
        interval_minutes: interval,
        sync_mode: 'normal',
        selection: this.selection()
      };
      await Backend.syncAutomationUpdateConfig(config);
      this.statusText = enabled ? `已启用自动同步（每 ${interval} 分钟）` : '已关闭自动同步';
      await this.reload();
    } catch (err) {
      this.errorText = `保存自动化配置失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async ttPull(server: TtSyncPairedServerDto): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      await Backend.ttSyncPull(server.server_device_id, 'normal', this.operationOptions());
      this.statusText = `已从 ${server.server_device_name} 拉取`;
      await this.reload();
    } catch (err) {
      this.errorText = `拉取失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async ttPush(server: TtSyncPairedServerDto): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      await Backend.ttSyncPush(server.server_device_id, 'normal', this.operationOptions());
      this.statusText = `已推送到 ${server.server_device_name}`;
      await this.reload();
    } catch (err) {
      this.errorText = `推送失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  @Builder
  pageTopBar() {
    PageHeader({
        title: '同步',
        subtitle: '让内容在设备间流动',
        onBack: () => {
            ROOT_PATH_STACK.pop();
        }
      }) {
        HeaderAction({ label: '刷新', marker: 'syncpage-refresh-1', available: !this.busy,
          pending: this.loading,
          onAction: async (): Promise<void> => { await this.reload(); } })
      }
  }

  @Builder
  buildSurfaceContent() {
      Column({ space: Spacing.sm }) {
        
  
        if (this.statusText !== '') {
          Text(this.statusText)
            .fontSize(Typography.caption)
            .fontColor(this.uiColors.textTertiary)
            .width('100%')
            .padding({ left: Spacing.md })
        }
        ErrorBannerView({ text: this.errorText })
  
        Column() {
          Column({ space: Spacing.md }) {
            if (this.loading) {
              Text('读取中…').fontSize(Typography.caption).fontColor(this.uiColors.textTertiary)
            } else {
              this.localCard()
              this.devicesCard()
              this.datasetCard()
              this.automationCard()
              this.ttServersCard()
            }
          }
          .width('100%')
          .padding({ bottom: Spacing.xxl })
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

  @Builder
  localCard() {
    Column({ space: Spacing.sm }) {
      SectionTitle('本机', this.uiColors)
      if (this.status !== undefined) {
        Text(this.status!.running
          ? `服务运行中 · ${this.endpointText()}`
          : '服务未启动')
          .fontSize(Typography.caption)
          .fontColor(this.status!.running ? this.uiColors.accent : this.uiColors.textTertiary)
          .width('100%')
        Text(`同步模式 ${this.status!.sync_mode} · 覆盖策略 ${this.status!.overwrite_policy}`)
          .fontSize(Typography.micro)
          .fontColor(this.uiColors.textTertiary)
          .width('100%')
      }
      Row({ space: Spacing.sm }) {
        TextInput({ text: this.deviceName, placeholder: '本机设备名' })
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
            this.deviceName = value;
          })
        .attributeModifier(new InputFieldStyle(this.uiColors))
      Button('保存', { type: ButtonType.Normal })
          .fontSize(UIType.caption)
          .constraintSize({ minHeight: 44 })
          .enabled(!this.busy)
          .onClick(() => {
            this.saveDeviceName();
          })
      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      }
      .width('100%')

      Button(this.status !== undefined && this.status!.running ? '停止同步服务' : '启动同步服务', { type: ButtonType.Normal })
        .fontSize(Typography.caption)
        .constraintSize({ minHeight: 44 })
        .width('100%')
        .enabled(!this.busy)
        .onClick(() => {
          this.toggleServer();
        })

      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      if (this.pairing !== undefined) {
        Column({ space: 4 }) {
          Text('把下面这串交给另一台设备（对方粘贴后配对）')
            .fontSize(Typography.micro)
            .fontColor(this.uiColors.textTertiary)
            .width('100%')
          Text(this.pairing!.pair_uri)
            .fontSize(Typography.micro)
            .fontColor(this.uiColors.textSecondary)
            .width('100%')
            .maxLines(4)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .padding(Spacing.sm)
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(Radius.sm)

        Row({ space: Spacing.sm }) {
          TextInput({ text: this.pairUri, placeholder: '粘贴对方的配对 URI' })
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
              this.pairUri = value;
            })
          .attributeModifier(new InputFieldStyle(this.uiColors))
      Button('配对', { type: ButtonType.Normal })
            .fontSize(UIType.caption)
            .constraintSize({ minHeight: 44 })
            .enabled(!this.busy)
            .onClick(() => {
              this.pairByUri();
            })
        .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
        .width('100%')
      }
    }
    .width('100%')
    .padding(Spacing.md)
    .borderRadius(GLASS_CARD.radius)
    .backgroundColor(this.uiColors.bgSurface)
    .border({ width: 1, color: this.uiColors.borderSubtle })
  }

  @Builder
  devicesCard() {
    Column({ space: Spacing.sm }) {
      SectionTitle('已配对设备', this.uiColors)
      if (this.devices.length === 0) {
        EmptyHint('还没有配对设备', '两台设备都要启动服务，然后互相配对', this.uiColors)
      } else {
        ForEach(this.devices, (device: LanSyncPairedDeviceDto) => {
          Column({ space: 6 }) {
            Text(device.device_name)
              .fontSize(Typography.caption)
              .fontColor(this.uiColors.textPrimary)
              .width('100%')
            Text(`${device.last_known_address !== undefined ? device.last_known_address : '地址未知'} · 上次同步 ${this.fmtMs(device.last_sync_ms)}`)
              .fontSize(Typography.micro)
              .fontColor(this.uiColors.textTertiary)
              .width('100%')
            Row({ space: Spacing.sm }) {
              Button('推送', { type: ButtonType.Normal })
                .fontSize(UIType.caption)
                .constraintSize({ minHeight: 44 })
                .layoutWeight(1)
                .enabled(!this.busy)
                .onClick(() => {
                  this.pushTo(device);
                })
              .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button('拉取', { type: ButtonType.Normal })
                .fontSize(UIType.caption)
                .constraintSize({ minHeight: 44 })
                .layoutWeight(1)
                .enabled(!this.busy)
                .onClick(() => {
                  this.pullFrom(device);
                })
              .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button('移除', { type: ButtonType.Normal })
                .fontSize(UIType.caption)
                .constraintSize({ minHeight: 44 })
                .backgroundColor(this.uiColors.danger)
                .enabled(!this.busy)
                .onClick(() => {
                  this.removeDevice(device);
                })
            .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Danger))
      }
            .width('100%')
          }
          .width('100%')
          .padding({ top: 6, bottom: 6 })
        }, (device: LanSyncPairedDeviceDto) => device.device_id)
      }
    }
    .width('100%')
    .padding(Spacing.md)
    .borderRadius(GLASS_CARD.radius)
    .backgroundColor(this.uiColors.bgSurface)
    .border({ width: 1, color: this.uiColors.borderSubtle })
  }

  @Builder
  datasetCard() {
    Column({ space: Spacing.sm }) {
      SectionTitle('同步范围', this.uiColors)
      Text(`已选 ${this.selectedDatasets.length} / ${this.datasets.length} 个数据集`)
        .fontSize(Typography.micro)
        .fontColor(this.uiColors.textTertiary)
        .width('100%')
      ForEach(this.datasets, (id: string) => {
        Row({ space: Spacing.sm }) {
          Text(id)
            .fontSize(Typography.caption)
            .fontColor(this.uiColors.textSecondary)
            .layoutWeight(1)
          Toggle({ type: ToggleType.Checkbox, isOn: this.isSelected(id) })
            .selectedColor(this.uiColors.accent)
            .onChange(() => {
              this.toggleDataset(id);
            })
        }
        .width('100%')
      }, (id: string) => id)
    }
    .width('100%')
    .padding(Spacing.md)
    .borderRadius(GLASS_CARD.radius)
    .backgroundColor(this.uiColors.bgSurface)
    .border({ width: 1, color: this.uiColors.borderSubtle })
  }

  @Builder
  automationCard() {
    Column({ space: Spacing.sm }) {
      SectionTitle('自动同步', this.uiColors)
      if (this.autoConfig !== undefined) {
        Text(this.autoConfig!.auto_sync_enabled ? '已启用' : '已关闭')
          .fontSize(Typography.caption)
          .fontColor(this.autoConfig!.auto_sync_enabled ? this.uiColors.accent : this.uiColors.textTertiary)
          .width('100%')
      }
      if (this.autoStatus !== undefined) {
        Text(`上次结果：${this.autoStatus!.last_result !== undefined ? this.autoStatus!.last_result : '无'}`
          + `${this.autoStatus!.last_error !== undefined ? ' · 错误：' + this.autoStatus!.last_error : ''}`)
          .fontSize(Typography.micro)
          .fontColor(this.uiColors.textTertiary)
          .width('100%')
          .maxLines(2)
      }
      Row({ space: Spacing.sm }) {
        TextInput({ text: this.intervalText, placeholder: '间隔分钟' })
          .fontColor(this.uiColors.textPrimary)
          .placeholderColor(this.uiColors.textTertiary)
          .backgroundColor(this.uiColors.bgSurfaceHigh)
          .borderRadius(UIRadius.sm)
          .fontSize(Typography.caption)
          .constraintSize({ minHeight: 44 })
          .width(120)
          .backgroundColor(this.uiColors.bgSurfaceHigh)
          .borderRadius(Radius.sm)
          .onChange((value: string) => {
            this.intervalText = value;
          })
        .attributeModifier(new InputFieldStyle(this.uiColors))
      Button('启用', { type: ButtonType.Normal })
          .fontSize(UIType.caption)
          .constraintSize({ minHeight: 44 })
          .layoutWeight(1)
          .enabled(!this.busy)
          .onClick(() => {
            this.saveAutomation(true);
          })
        .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button('关闭', { type: ButtonType.Normal })
          .fontSize(UIType.caption)
          .constraintSize({ minHeight: 44 })
          .backgroundColor(this.uiColors.bgSurfaceHigh)
          .fontColor(this.uiColors.textSecondary)
          .enabled(!this.busy)
          .onClick(() => {
            this.saveAutomation(false);
          })
      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
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
  ttServersCard() {
    Column({ space: Spacing.sm }) {
      SectionTitle('tt_sync 服务器', this.uiColors)
      if (this.servers.length === 0) {
        EmptyHint('没有已配对的 tt_sync 服务器', '需要一台跑着 ttsync 服务端的设备', this.uiColors)
      } else {
        ForEach(this.servers, (server: TtSyncPairedServerDto) => {
          Column({ space: 6 }) {
            Text(server.server_device_name)
              .fontSize(Typography.caption)
              .fontColor(this.uiColors.textPrimary)
              .width('100%')
            Text(`${server.base_url} · 读 ${server.permissions.read ? '✓' : '✗'} 写 ${server.permissions.write ? '✓' : '✗'}`)
              .fontSize(Typography.micro)
              .fontColor(this.uiColors.textTertiary)
              .width('100%')
            Row({ space: Spacing.sm }) {
              Button('拉取', { type: ButtonType.Normal })
                .fontSize(UIType.caption)
                .constraintSize({ minHeight: 44 })
                .layoutWeight(1)
                .enabled(!this.busy)
                .onClick(() => {
                  this.ttPull(server);
                })
              .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Button('推送', { type: ButtonType.Normal })
                .fontSize(UIType.caption)
                .constraintSize({ minHeight: 44 })
                .layoutWeight(1)
                .enabled(!this.busy && server.permissions.write)
                .onClick(() => {
                  this.ttPush(server);
                })
            .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      }
            .width('100%')
          }
          .width('100%')
          .padding({ top: 6, bottom: 6 })
        }, (server: TtSyncPairedServerDto) => server.server_device_id)
      }
    }
    .width('100%')
    .padding(Spacing.md)
    .borderRadius(GLASS_CARD.radius)
    .backgroundColor(this.uiColors.bgSurface)
    .border({ width: 1, color: this.uiColors.borderSubtle })
  }

  /** 后端返回的 address 可能已经带了端口（如 https://10.0.2.15:55392），避免重复拼接。 */
  endpointText(): string {
    if (this.status === undefined) {
      return '未知地址';
    }
    const address: string | undefined = this.status.address;
    if (address === undefined || address === null || address === '') {
      return `端口 ${this.status.port}`;
    }
    const suffix: string = `:${this.status.port}`;
    if (address.indexOf(suffix) >= 0) {
      return address;
    }
    return `${address}${suffix}`;
  }

  fmtMs(ms?: number): string {    if (ms === undefined || ms === null) {
      return '从未';
    }
    const date: Date = new Date(ms);
    return `${date.getMonth() + 1}/${date.getDate()} ${date.getHours()}:${date.getMinutes()}`;
  }
}
