// NAPI 模块 'libttavern.so' 的类型声明。
// P1–P3 手写，与 lib.rs 的 6 个 #[napi] 导出逐一对应。
// P7 步骤 4 验证：napi-build-ohos 在 OHOS 目标下不生成 .d.ts（构建产物里无 index.d.ts），
// 因此这份手写声明就是 ArkTS 侧的唯一类型源；运行时已由 P6.2 12/12 + 事件监听实测覆盖。
declare module 'libttavern.so' {
  export function hello(): string;
  export function add(a: number, b: number): number;

  // 生命周期：注入沙箱路径（filesDir/databaseDir/cacheDir/bundleName/versionName 的 JSON）
  // 返回就绪状态 JSON；失败时 reject（Error.message 为原因文本）。
  export function initialize(pathsJson: string): Promise<string>;

  // 就绪状态/版本 JSON（ready/version/platform/dataRoot/logRoot/bundledResources/services/initializedAt）
  export function getBackendStatus(): Promise<string>;

  // 通用命令入口：返回 JSON 信封，永不 reject。
  //  成功 → {"ok":true,"data":<结果>}
  //  失败 → {"ok":false,"error":{"code":"not_found","message":"..."}}
  export function invoke(command: string, payloadJson?: string): Promise<string>;

  // 事件订阅：Rust → ArkTS，回调收到 {"event":"<name>","payload":<json>} 信封字符串。
  export function setEventListener(listener: (envelope: string) => void): void;
}
