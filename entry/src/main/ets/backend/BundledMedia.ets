/**
 * HAP rawfile 媒体抽取器（P4）。
 *
 * 为什么需要它：默认内容分两类资产 ——
 *  1. 文本（138 个 JSON/CSS/HTML，约 200 KB）：由 Rust `build.rs` 编进 `libttavern.so`，无需本模块；
 *  2. 媒体（53 个 PNG/JPG，约 7.34 MB）：编进 `.so` 会因双 ABI 变成 2×7.34 MB，因此随 HAP 的
 *     `rawfile/` 分发，首次启动时由本模块抽取到 `<filesDir>/.bundled-media/`，再把该路径经
 *     `initialize` 的 `bundledMediaDir` 交给 Rust。
 *
 * 幂等性：抽取完成后写 `.bundled-media.json`（含 versionCode 与文件数）。版本未变则直接跳过；
 * 版本变化或文件缺失则重抽。marker 只是记账，写失败只 warn，不影响启动。
 *
 * 失败信息带「阶段 + 路径 + 文件序号」，因为一旦在真机上失败，这些就是唯一的现场证据：
 *   media extraction failed [phase] at file #N (entry) path=... : Invalid argument
 *
 * 对应 DevEco 工程路径：entry/src/main/ets/backend/BundledMedia.ets
 * rawfile 目录：entry/src/main/resources/rawfile/default/content/**（由
 * native/scripts/sync-rawfile-media.ps1 从仓库 default/content 同步，含 MediaManifest.ets）
 */

import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';
import { MEDIA_FILE_COUNT, MEDIA_MANIFEST, MEDIA_TOTAL_BYTES } from './MediaManifest';

const DOMAIN: number = 0x0001;
const TAG: string = 'HarmonyTavern';

/** 媒体根目录名（相对 filesDir）。与 Rust 侧 `bundledMediaDir` 约定一致。 */
const MEDIA_ROOT_DIR: string = '.bundled-media';
/** 完成标记文件名。 */
const MARKER_FILE: string = '.bundled-media.json';
/** rawfile 内的公共前缀（rawfile 树镜像仓库 default/ 目录）。 */
const RAWFILE_PREFIX: string = 'default/';

/** 抽取结果，供 UI 显示与日志。 */
export interface MediaExtractionResult {
  /** 媒体根绝对路径，交给 `Backend.initialize({ bundledMediaDir })`。 */
  root: string;
  /** 本次实际写入的文件数（跳过时 0）。 */
  extracted: number;
  /** true 表示版本未变、直接复用上次结果。 */
  reused: boolean;
  /** 清单声明的文件总数。 */
  declared: number;
  /** 清单声明的总字节数（构建期统计）。 */
  totalBytes: number;
}

export class BundledMedia {
  /**
   * 确保 rawfile 媒体已抽取到沙箱。可在启动流程里重复调用。
   * @param context UIAbilityContext（提供 filesDir 与 resourceManager）
   * @param versionCode HAP 的 versionCode；变化时重抽
   */
  static ensureExtracted(context: common.UIAbilityContext, versionCode: number): MediaExtractionResult {
    const root: string = `${context.filesDir}/${MEDIA_ROOT_DIR}`;
    const marker: string = `${root}/${MARKER_FILE}`;
    const stamp: string = `{"versionCode":${versionCode},"files":${MEDIA_FILE_COUNT}}`;

    if (BundledMedia.markerMatches(marker, stamp)) {
      hilog.info(DOMAIN, TAG, 'bundled media already extracted: %{public}s', root);
      return { root: root, extracted: 0, reused: true, declared: MEDIA_FILE_COUNT, totalBytes: MEDIA_TOTAL_BYTES };
    }

    let phase: string = 'mkdir(root)';
    let index: number = 0;
    let target: string = root;

    try {
      BundledMedia.ensureDir(root);

      for (index = 0; index < MEDIA_MANIFEST.length; index += 1) {
        const entry: string = MEDIA_MANIFEST[index];
        target = `${root}/${entry}`;

        phase = 'mkdir(parent)';
        BundledMedia.ensureDir(target.substring(0, target.lastIndexOf('/')));

        phase = 'getRawFileContentSync';
        const bytes: Uint8Array = context.resourceManager.getRawFileContentSync(RAWFILE_PREFIX + entry);

        phase = 'writeFile';
        BundledMedia.writeBytes(target, bytes);
      }
    } catch (error) {
      // fail fast：媒体文件缺失会让默认内容静默缺图，必须中断并带上足够的现场信息。
      const err = error as BusinessError;
      const entry: string = index < MEDIA_MANIFEST.length ? MEDIA_MANIFEST[index] : '(none)';
      hilog.error(DOMAIN, TAG,
        'media extraction failed [%{public}s] at file #%{public}d (%{public}s): %{public}s (root=%{public}s)',
        phase, index, entry, err.message, root);
      throw new Error(
        `media extraction failed [${phase}] at file #${index} (${entry}) root=${root}: ${err.message}`);
    }

    // marker 只是“已抽取”的记账：写失败最坏结果是下次重抽 53 个文件（幂等、无副作用），
    // 因此这里**不能**升级为启动失败——否则一个记账问题会把整个后端拦在门外。
    try {
      BundledMedia.writeBytes(marker, new util.TextEncoder().encodeInto(stamp));
    } catch (error) {
      const err = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'failed to write media marker (%{public}s); media will be re-extracted next launch',
        err.message);
    }

    hilog.info(DOMAIN, TAG, 'bundled media extracted: %{public}d files into %{public}s', MEDIA_MANIFEST.length, root);
    return {
      root: root,
      extracted: MEDIA_MANIFEST.length,
      reused: false,
      declared: MEDIA_FILE_COUNT,
      totalBytes: MEDIA_TOTAL_BYTES
    };
  }

  /** brand-new file write: 先删后建，只依赖 CREATE|READ_WRITE（不依赖 TRUNC 位）。 */
  private static writeBytes(target: string, bytes: Uint8Array): void {
    if (fs.accessSync(target)) {
      fs.unlinkSync(target);
    }
    const file = fs.openSync(target, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
    try {
      // 传 ArrayBuffer 而不是原生返回的 Uint8Array 视图：部分设备对「native 视图 + fd」组合
      // 会报 Invalid argument。
      const buffer: ArrayBuffer = new ArrayBuffer(bytes.byteLength);
      new Uint8Array(buffer).set(bytes);
      fs.writeSync(file.fd, buffer);
    } finally {
      fs.closeSync(file);
    }
  }

  /** marker 存在且内容与期望完全一致。 */
  private static markerMatches(marker: string, stamp: string): boolean {
    if (!fs.accessSync(marker)) {
      return false;
    }
    try {
      return fs.readTextSync(marker) === stamp;
    } catch (error) {
      const err = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'failed to read media marker: %{public}s', err.message);
      return false;
    }
  }

  /**
   * 逐段创建目录。
   *
   * 故意**不用** `mkdirSync(path, true)`：不同 SDK 版本的第二参数有 `recursion: boolean`
   * 与 `mode?: number` 两种签名，传 `true` 在其中一种上会直接抛 Invalid argument。
   * 单参数 `mkdirSync(path)` 在所有版本上含义一致。
   */
  private static ensureDir(path: string): void {
    if (fs.accessSync(path)) {
      return;
    }

    const parts: string[] = path.split('/');
    let current: string = parts[0] === '' ? '' : parts[0];
    for (let i = 1; i < parts.length; i += 1) {
      const segment: string = parts[i];
      if (segment === '') {
        continue;
      }
      current = `${current}/${segment}`;
      if (!fs.accessSync(current)) {
        fs.mkdirSync(current);
      }
    }
  }
}
