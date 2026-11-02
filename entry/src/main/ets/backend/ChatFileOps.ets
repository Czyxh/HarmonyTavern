// 聊天正文文件操作（P8-18）：消息编辑 / 删除 / 截断。
//
// 为什么要有这一层：TauriTavern 的 Rust 核心**没有**改单条消息的命令——
// 原项目里"编辑/删除/重新生成"是 SillyTavern 前端 JS + ST 后端 /api/chats/save 干的活，
// 这部分逻辑不在 ttavern 的 263 条命令里（只有 add_message 能追加）。
//
// 所以这里走"读沙箱 jsonl → 改行 → 写回 → clear_chat_cache"的路径：
//   1. get_chat_payload_path 拿到聊天文件**绝对路径**（比猜目录可靠，能处理角色目录别名）
//   2. 按行解析：ST 的 .jsonl 首行通常是元数据对象，后面每行一条消息（有 mes 字段）
//   3. 改完写回，再调 clear_chat_cache 让后端丢掉内存缓存，否则重读还是旧内容
//
// 风险提示：这是绕过后端直接改文件，必须成对做"写文件 + 清缓存"。
//
// 对应 DevEco 工程路径：entry/src/main/ets/backend/ChatFileOps.ets
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Backend } from './Backend';

const DOMAIN: number = 0x0004;
const TAG: string = 'HarmonyTavern';

export class ChatFileOps {
  /** 聊天文件绝对路径。 */
  static async pathOf(characterName: string, fileName: string): Promise<string> {
    return await Backend.getChatPayloadPath(characterName, fileName, false);
  }

  static readText(path: string): string {
    return fs.readTextSync(path);
  }

  static writeText(path: string, text: string): void {
    const file: fs.File = fs.openSync(path,
      fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC | fs.OpenMode.CREATE);
    fs.writeSync(file.fd, text);
    fs.closeSync(file);
  }

  private static nonEmptyLines(raw: string): string[] {
    const all: string[] = raw.split('\n');
    const kept: string[] = [];
    for (let i = 0; i < all.length; i++) {
      if (all[i].trim() !== '') {
        kept.push(all[i]);
      }
    }
    return kept;
  }

  /** 哪些行是"消息"（相对 messages 数组的下标一一对应）。 */
  static messageLineIndexes(lines: string[]): number[] {
    const out: number[] = [];
    for (let i = 0; i < lines.length; i++) {
      try {
        const obj: ESObject = JSON.parse(lines[i]) as ESObject;
        const mes: string | undefined = obj.mes as string;
        if (mes !== undefined) {
          out.push(i);
        }
      } catch (err) {
        // 不是合法 JSON 的行跳过（空行/注释），不影响其它行
      }
    }
    return out;
  }

  /**
   * 确保聊天头里有 `chat_metadata.integrity`，返回该值。
   *
   * **为什么需要**：扩展数据（extension store）在磁盘上是
   * `chats/<角色>/.tauritavern/<integrity>/<namespace>/<key>.json`，
   * 也就是**用 integrity 当目录名**。上游是 SillyTavern 客户端在建会话时自己生成一个
   * uuid 塞进首行 metadata 的；我们的 `create_chat` 命令只接受
   * `{character_name, user_name, first_message}`，没地方传 metadata，
   * 所以鸿蒙端建出来的会话一律没有 integrity —— 后果是
   * `list_character_chat_store_keys` 直接报 `Chat metadata integrity is missing`。
   *
   * 这里按上游语义补一个（客户端生成、写回首行、清缓存），补完扩展 KV 才可用。
   */
  static async ensureIntegrity(characterName: string, fileName: string): Promise<string> {
    const path: string = await ChatFileOps.pathOf(characterName, fileName);
    const raw: string = ChatFileOps.readText(path);
    const lines: string[] = ChatFileOps.nonEmptyLines(raw);
    if (lines.length === 0) {
      throw new Error('会话文件是空的');
    }
    // 首行就是 header（SillyTavern 约定）；不是 vitals 消息
    let header: ESObject = {};
    try {
      header = JSON.parse(lines[0]) as ESObject;
    } catch (err) {
      throw new Error('首行不是合法 JSON，无法补 integrity');
    }
    let metadata: ESObject = header.chat_metadata as ESObject;
    if (metadata === undefined || metadata === null) {
      metadata = {};
    }
    const existing: string = metadata.integrity as string;
    if (existing !== undefined && existing !== null && existing !== '') {
      return existing;
    }
    const integrity: string = util.generateRandomUUID(false);
    metadata.integrity = integrity;
    header.chat_metadata = metadata;
    lines[0] = JSON.stringify(header);
    // 写回时保留原有行序（首行 + 消息行），末尾补换行
    ChatFileOps.writeText(path, lines.join('\n') + '\n');
    await Backend.clearChatCache();
    return integrity;
  }

  /** 读首行 metadata 里的 integrity（没有就返回空串）。 */
  static async readIntegrity(characterName: string, fileName: string): Promise<string> {
    const path: string = await ChatFileOps.pathOf(characterName, fileName);
    const lines: string[] = ChatFileOps.nonEmptyLines(ChatFileOps.readText(path));
    if (lines.length === 0) {
      return '';
    }
    try {
      const header: ESObject = JSON.parse(lines[0]) as ESObject;
      const metadata: ESObject = header.chat_metadata as ESObject;
      if (metadata === undefined || metadata === null) {
        return '';
      }
      const value: string = metadata.integrity as string;
      return value === undefined || value === null ? '' : value;
    } catch (err) {
      return '';
    }
  }

  /** 改一条消息的正文。index 是消息在 messages 数组里的下标。 */
  static async editMessage(characterName: string, fileName: string,
    index: number, newText: string): Promise<void> {
    const path: string = await ChatFileOps.pathOf(characterName, fileName);
    const lines: string[] = ChatFileOps.nonEmptyLines(ChatFileOps.readText(path));
    const msgIndexes: number[] = ChatFileOps.messageLineIndexes(lines);
    if (index < 0 || index >= msgIndexes.length) {
      throw new Error(`消息下标越界：${index}，当前共 ${msgIndexes.length} 条`);
    }
    const lineNo: number = msgIndexes[index];
    const obj: ESObject = JSON.parse(lines[lineNo]) as ESObject;
    obj.mes = newText;
    lines[lineNo] = JSON.stringify(obj);
    ChatFileOps.writeText(path, lines.join('\n') + '\n');
    await Backend.clearChatCache();
    hilog.info(DOMAIN, TAG, 'message edited: index=%{public}d', index);
  }

  /** 删一条消息。 */
  static async deleteMessage(characterName: string, fileName: string, index: number): Promise<void> {
    const path: string = await ChatFileOps.pathOf(characterName, fileName);
    const lines: string[] = ChatFileOps.nonEmptyLines(ChatFileOps.readText(path));
    const msgIndexes: number[] = ChatFileOps.messageLineIndexes(lines);
    if (index < 0 || index >= msgIndexes.length) {
      throw new Error(`消息下标越界：${index}，当前共 ${msgIndexes.length} 条`);
    }
    const lineNo: number = msgIndexes[index];
    const kept: string[] = [];
    for (let i = 0; i < lines.length; i++) {
      if (i !== lineNo) {
        kept.push(lines[i]);
      }
    }
    ChatFileOps.writeText(path, kept.join('\n') + '\n');
    await Backend.clearChatCache();
    hilog.info(DOMAIN, TAG, 'message deleted: index=%{public}d', index);
  }

  /**
   * 删掉从 index 开始的全部消息（含 index）。
   * 用于"在这里重新生成"：先截断到 index，再重新生成一条。
   */
  static async deleteMessagesFrom(characterName: string, fileName: string, index: number): Promise<number> {
    const path: string = await ChatFileOps.pathOf(characterName, fileName);
    const lines: string[] = ChatFileOps.nonEmptyLines(ChatFileOps.readText(path));
    const msgIndexes: number[] = ChatFileOps.messageLineIndexes(lines);
    if (index < 0 || index >= msgIndexes.length) {
      throw new Error(`消息下标越界：${index}，当前共 ${msgIndexes.length} 条`);
    }
    const cutLine: number = msgIndexes[index];
    const kept: string[] = [];
    for (let i = 0; i < lines.length; i++) {
      if (i < cutLine) {
        kept.push(lines[i]);
      }
    }
    ChatFileOps.writeText(path, kept.join('\n') + '\n');
    await Backend.clearChatCache();
    const removed: number = msgIndexes.length - index;
    hilog.info(DOMAIN, TAG, 'messages truncated from %{public}d, removed %{public}d', index, removed);
    return removed;
  }
}
