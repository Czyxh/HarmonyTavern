// 命令调用日志（应用内活动日志）。
//
// 原项目 Dev Logs 应用有两块：LiveLogPanel（应用/后端实时日志）与 LlmApiLogsPanel（LLM 请求日志）。
// 鸿蒙端没有 Tauri 那套日志通道，这里提供等价的"可观测性"：把每一次 native 命令调用
// （命令名、耗时、成功/失败、错误码与消息）记进一个固定容量的环形缓冲，日志页实时展示。
//
// LLM API 请求/响应日志目前没有后端命令可读（Rust 核心没有暴露读取接口），
// 已在 docs/功能对齐清单.md 记为待补：需要给 host crate 增加一条读日志命令。
//
// 对应 DevEco 工程路径：entry/src/main/ets/backend/CallLog.ets

export interface CallLogEntry {
  seq: number;
  /** HH:mm:ss.SSS */
  at: string;
  command: string;
  ok: boolean;
  ms: number;
  /** 请求 payload 长度（字符），便于判断是不是大对象。 */
  payloadChars: number;
  /** 失败时的 code/message，或成功时的 data 类型摘要。 */
  detail: string;
}

const LIMIT: number = 400;

export class CallLog {
  private static entries: CallLogEntry[] = [];
  private static seq: number = 0;

  static record(command: string, ok: boolean, ms: number, payloadChars: number, detail: string): void {
    CallLog.seq = CallLog.seq + 1;
    const entry: CallLogEntry = {
      seq: CallLog.seq,
      at: CallLog.stamp(),
      command: command,
      ok: ok,
      ms: Math.round(ms),
      payloadChars: payloadChars,
      detail: detail
    };
    CallLog.entries.push(entry);
    if (CallLog.entries.length > LIMIT) {
      CallLog.entries.splice(0, CallLog.entries.length - LIMIT);
    }
  }

  /** 新的在前。 */
  static list(): CallLogEntry[] {
    const result: CallLogEntry[] = [];
    for (let i = CallLog.entries.length - 1; i >= 0; i--) {
      result.push(CallLog.entries[i]);
    }
    return result;
  }

  static size(): number {
    return CallLog.entries.length;
  }

  static errorCount(): number {
    let errors: number = 0;
    for (let i = 0; i < CallLog.entries.length; i++) {
      if (!CallLog.entries[i].ok) {
        errors = errors + 1;
      }
    }
    return errors;
  }

  static clear(): void {
    CallLog.entries = [];
  }

  private static stamp(): string {
    const now: Date = new Date();
    const hh: string = now.getHours() < 10 ? `0${now.getHours()}` : `${now.getHours()}`;
    const mm: string = now.getMinutes() < 10 ? `0${now.getMinutes()}` : `${now.getMinutes()}`;
    const ss: string = now.getSeconds() < 10 ? `0${now.getSeconds()}` : `${now.getSeconds()}`;
    const ms: number = now.getMilliseconds();
    const msText: string = ms < 10 ? `00${ms}` : (ms < 100 ? `0${ms}` : `${ms}`);
    return `${hh}:${mm}:${ss}.${msText}`;
  }
}
