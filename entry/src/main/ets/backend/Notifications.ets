// P7 通知渠道助手：agent 运行完成 / LAN/tt_sync 同步完成通知。
//
// 权限：module.json5 已声明 `ohos.permission.NOTIFICATION`；API 12+ 需
// requestEnableNotification() 获得用户同意后才能 publish。
//
// 对应 DevEco 工程路径：entry/src/main/ets/backend/Notifications.ets
import { notificationManager } from '@kit.NotificationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'HarmonyTavern';

let nextId: number = 1;

/**
 * 申请通知授权（用户同意后返回 true；拒绝/失败返回 false）。
 * △ 需在 DevEco 编译验证：requestEnableNotification 无参重载在部分 SDK 版本可能
 * 需传 UIAbilityContext（@ohos.notificationManager.d.ts L767/L818 两个重载都有）。
 */
export async function requestNotificationPermission(): Promise<boolean> {
  try {
    await notificationManager.requestEnableNotification();
    hilog.info(DOMAIN, TAG, 'notification permission granted');
    return true;
  } catch (err) {
    const message: string = (err as Error).message;
    hilog.warn(DOMAIN, TAG, 'requestEnableNotification failed: %{public}s', message);
    return false;
  }
}

/**
 * 发布一条基础文本通知。
 * 未授权时 publish 会抛错 —— 调用方应先 requestNotificationPermission()。
 * △ 需在 DevEco 编译验证：NotificationRequest / ContentType 的命名空间引用形态。
 */
export async function notify(title: string, text: string): Promise<void> {
  const request: notificationManager.NotificationRequest = {
    id: nextId++,
    content: {
      notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
      normal: {
        title: title,
        text: text,
      },
    },
  };
  await notificationManager.publish(request);
  hilog.info(DOMAIN, TAG, 'notification published: %{public}s | %{public}s', title, text);
}
