// 文件选择 + 沙箱落地（导入页共用）。
//
// 对应 DevEco 工程路径：entry/src/main/ets/utils/ImportFiles.ets
//
// 为什么要落地到沙箱：
//   picker 返回的是 `file://docs/...` / `file://media/...` 这类 URI，
//   Rust 侧只用 std::fs 打开**真实路径**，拿 URI 会 NotFound。
//   所以先把字节拷进 `<filesDir>/imports/`，再把沙箱路径交给核心。
//
// 对应 DevEco 工程路径：entry/src/main/ets/utils/ImportFiles.ets
import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';

/** 打开系统文件选择器，返回 URI；用户取消返回空串。 */
export async function pickDocument(
  context: common.UIAbilityContext,
  filters: string[]
): Promise<string> {
  const options: picker.DocumentSelectOptions = {
    maxSelectNumber: 1,
    fileSuffixFilters: filters
  };
  const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
  const uris: string[] = await documentPicker.select(options);
  if (uris === undefined || uris === null || uris.length === 0) {
    return '';
  }
  return uris[0];
}

/** URI 里的文件名（去掉查询串）；取不到就用 fallback。 */
export function fileNameOf(uri: string, fallback: string): string {
  const clean: string = uri.split('?')[0];
  const slash: number = clean.lastIndexOf('/');
  const name: string = slash >= 0 ? clean.substring(slash + 1) : clean;
  return name === '' ? fallback : name;
}

/** 确保 `<filesDir>/imports` 存在并返回它。 */
function importsDir(context: common.UIAbilityContext): string {
  const dir: string = `${context.filesDir}/imports`;
  if (!fs.accessSync(dir)) {
    fs.mkdirSync(dir, true);
  }
  return dir;
}

/** 把 picker URI 的字节拷进沙箱，返回沙箱路径。 */
export function copyToSandbox(
  context: common.UIAbilityContext,
  uri: string,
  fallbackName: string
): string {
  const dest: string = `${importsDir(context)}/${fallbackName}`;
  const src: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
  try {
    const stat: fs.Stat = fs.statSync(src.fd);
    const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
    let offset: number = 0;
    // 大文件一次 readSync 可能读不全，循环到读满为止
    while (offset < stat.size) {
      const read: number = fs.readSync(src.fd, buffer, { offset: offset, length: stat.size - offset });
      if (read <= 0) {
        break;
      }
      offset += read;
    }
    const out: fs.File = fs.openSync(dest, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(out.fd, buffer);
    } finally {
      fs.closeSync(out);
    }
  } finally {
    fs.closeSync(src);
  }
  return dest;
}

/** 把一段文本写进沙箱，返回路径。 */
export function writeTextToSandbox(
  context: common.UIAbilityContext,
  text: string,
  name: string
): string {
  const dest: string = `${importsDir(context)}/${name}`;
  const file: fs.File = fs.openSync(dest, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
  try {
    fs.writeSync(file.fd, text);
  } finally {
    fs.closeSync(file);
  }
  return dest;
}
