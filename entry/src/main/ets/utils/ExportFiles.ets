import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';

export async function saveBytes(context: common.UIAbilityContext, fileName: string, bytes: ArrayBuffer): Promise<boolean> {
  const document: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
  const uris: string[] = await document.save({ newFileNames: [fileName] });
  if (uris.length === 0) { return false; }
  const file: fs.File = fs.openSync(uris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
  try { fs.writeSync(file.fd, bytes); } finally { fs.closeSync(file); }
  return true;
}
