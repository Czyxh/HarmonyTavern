import { SurfaceStyle } from '../theme/SurfaceStyles';
import { ActionButtonStyle, ActionTone, InputFieldStyle, TextAreaFieldStyle } from '../theme/ControlStyles';
import { HeaderAction } from '../components/HeaderAction';
import { OriginMotion } from '../theme/OriginMotion';
import { COLORS as INITIAL_COLORS, ColorTokens } from '../theme/Tokens';
import { PageSurface } from '../components/PageSurface';
import { SCROLL_EDGE_OPTIONS, SCROLL_NESTED_OPTIONS } from '../theme/ScrollFeedback';
import { Radius as UIRadius, Typography as UIType } from '../theme/Tokens';
import { PageHeader } from '../components/PageHeader';
// 资源（P8-22）：用户图片与用户文件。
//
// 对应 DevEco 工程路径：entry/src/main/ets/pages/AssetsPage.ets
//
// 原项目里这些是 SillyTavern 的「背景 / 角色图 / 表情 / 用户文件」目录管理：
//   list_user_image_folders → 有哪些图片目录
//   list_user_images        → 某个目录下的图片
//   upload_user_image       → 上传图片（图库/相机选取 → base64）
//   delete_user_image       → 删图
//   upload_user_file        → 上传任意文件到 user/files/
//   delete_user_file        → 删文件
//   verify_user_files       → 批量检查路径是否还在
import { Backend, BackendError } from '../backend/Backend';
import { UserFileUploadResult, UserImageUploadResult } from '../backend/Types';
import { ROOT_PATH_STACK } from '../nav/RootNav';
import { Radius, Spacing, Touch, Typography } from '../theme/Tokens';
import { GLASS_HEADER, glassEffect } from '../theme/Glass';
import { EmptyHint, ErrorBannerView } from '../components/Builders';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { picker } from '@kit.CoreFileKit';

@Component
export struct AssetsPage {
  @StorageProp('uiColors') uiColors: ColorTokens = INITIAL_COLORS;
  @State tab: string = 'images';
  @State loading: boolean = true;
  @State busy: boolean = false;
  @State errorText: string = '';
  @State statusText: string = '';

  @State folders: string[] = [];
  @State folderIndex: number = 0;
  /** 后端还没建任何图片目录时，允许手填一个（上传时后端会建）。 */
  @State manualFolder: string = 'backgrounds';
  @State images: string[] = [];

  @State fileName: string = '';
  @State verifyInput: string = '';
  @State verifyResult: string = '';

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
      this.folders = await Backend.listUserImageFolders();
      if (this.folders.length === 0) {
        this.images = [];
        this.statusText = '后端还没有图片目录（第一次上传时会自动创建）';
      } else {
        if (this.folderIndex >= this.folders.length) {
          this.folderIndex = 0;
        }
        await this.loadImages();
      }
    } catch (err) {
      this.errorText = `读取失败：${(err as BackendError).message}`;
    } finally {
      this.loading = false;
    }
  }

  async loadImages(): Promise<void> {
    if (this.folders.length === 0) {
      return;
    }
    const folder: string = this.folders[this.folderIndex];
    this.images = await Backend.listUserImages({ folder: folder });
    this.statusText = `${folder} · ${this.images.length} 张`;
  }

  async selectFolder(index: number): Promise<void> {
    if (this.folderIndex === index) {
      return;
    }
    this.folderIndex = index;
    this.errorText = '';
    try {
      await this.loadImages();
    } catch (err) {
      this.errorText = `读取图片失败：${(err as BackendError).message}`;
    }
  }

  /** 图库选一张 → base64 → upload_user_image。 */
  async pickAndUploadImage(): Promise<void> {
    const targetFolder: string = this.folders.length > 0
      ? this.folders[this.folderIndex]
      : this.manualFolder.trim();
    if (targetFolder === '') {
      this.errorText = '先填一个目标目录';
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const pickerInstance: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await pickerInstance.select(options);
      if (result.photoUris.length === 0) {
        return;
      }
      const uri: string = result.photoUris[0];
      const file: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const stat: fs.Stat = fs.statSync(file.fd);
      const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);
      fs.closeSync(file);
      const base64: string = new util.Base64Helper().encodeToStringSync(new Uint8Array(buffer));
      const uploaded: UserImageUploadResult = await Backend.uploadUserImage({
        imageBase64: base64,
        format: 'png',
        filename: `upload_${Date.now()}.png`,
        chName: targetFolder
      });
      this.statusText = `已上传 ${uploaded.path}`;
      await this.reload();
    } catch (err) {
      this.errorText = `上传图片失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  confirmDeleteImage(path: string): void {
    this.getUIContext().showAlertDialog({
      title: '删除图片',
      alignment: DialogAlignment.Center,
      transition: OriginMotion.dialog(this.getUIContext(), 'asset-delete-' + path),
      message: path,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        action: () => {
          this.deleteImage(path);
        }
      }
    });
  }

  async deleteImage(path: string): Promise<void> {
    this.busy = true;
    try {
      await Backend.deleteUserImage(path);
      this.statusText = `已删除 ${path}`;
      await this.loadImages();
    } catch (err) {
      this.errorText = `删除失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  /** 文件选择器选一个文件 → base64 → upload_user_file。 */
  async pickAndUploadFile(): Promise<void> {
    this.busy = true;
    this.errorText = '';
    try {
      const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker();
      const uris: string[] = await documentPicker.select(options);
      if (uris.length === 0) {
        return;
      }
      const uri: string = uris[0];
      const file: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const stat: fs.Stat = fs.statSync(file.fd);
      const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);
      fs.closeSync(file);
      const base64: string = new util.Base64Helper().encodeToStringSync(new Uint8Array(buffer));
      const segments: string[] = uri.split('/');
      const guessed: string = segments.length === 0 ? `file_${Date.now()}` : segments[segments.length - 1];
      const name: string = this.fileName.trim() === '' ? guessed : this.fileName.trim();
      const uploaded: UserFileUploadResult = await Backend.uploadUserFile(name, base64);
      this.fileName = '';
      this.statusText = `已上传 ${uploaded.path}`;
    } catch (err) {
      this.errorText = `上传文件失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async verifyFiles(): Promise<void> {
    const urls: string[] = this.verifyInput.split('\n')
      .map((line: string) => line.trim())
      .filter((line: string) => line !== '');
    if (urls.length === 0) {
      this.errorText = '先每行填一个路径';
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      const result: Record<string, boolean> = await Backend.verifyUserFiles(urls);
      const keys: string[] = Object.keys(result);
      const lines: string[] = [];
      for (let i = 0; i < keys.length; i++) {
        const k: string = keys[i];
        lines.push(`${result[k] ? '✅' : '❌'} ${k}`);
      }
      this.verifyResult = lines.join('\n');
      this.statusText = `检查了 ${keys.length} 个路径`;
    } catch (err) {
      this.errorText = `检查失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  async deleteUploadedFile(path: string): Promise<void> {
    this.busy = true;
    try {
      await Backend.deleteUserFile(path);
      this.statusText = `已删除 ${path}`;
      this.verifyResult = '';
    } catch (err) {
      this.errorText = `删除失败：${(err as BackendError).message}`;
    } finally {
      this.busy = false;
    }
  }

  @Builder
  pageTopBar() {
    PageHeader({
        title: '资源',
        subtitle: '收纳图片、文件与声音',
        onBack: () => {
            ROOT_PATH_STACK.pop();
        }
      }) {
        HeaderAction({ label: '刷新', marker: 'assetspage-refresh-1', available: !this.busy,
          pending: this.loading,
          onAction: async (): Promise<void> => { await this.reload(); } })
      }
  }

  @Builder
  buildSurfaceContent() {
      Column({ space: Spacing.sm }) {
        
  
        Row({ space: 6 }) {
          Button('图片', { type: ButtonType.Normal })
            .fontSize(UIType.caption)
            .constraintSize({ minHeight: 44 })
            .backgroundColor(this.tab === 'images' ? this.uiColors.accent : this.uiColors.bgSurfaceHigh)
            .fontColor(this.tab === 'images' ? this.uiColors.textInverse : this.uiColors.textSecondary)
            .onClick(() => {
              this.tab = 'images';
            })
          .attributeModifier(new ActionButtonStyle(this.uiColors, (this.tab === 'images') ? ActionTone.Selected : ActionTone.Normal))
      Button('文件', { type: ButtonType.Normal })
            .fontSize(UIType.caption)
            .constraintSize({ minHeight: 44 })
            .backgroundColor(this.tab === 'files' ? this.uiColors.accent : this.uiColors.bgSurfaceHigh)
            .fontColor(this.tab === 'files' ? this.uiColors.textInverse : this.uiColors.textSecondary)
            .onClick(() => {
              this.tab = 'files';
            })
        .attributeModifier(new ActionButtonStyle(this.uiColors, (this.tab === 'files') ? ActionTone.Selected : ActionTone.Normal))
      }
        .width('100%')
        .padding({ left: Spacing.md })
  
        if (this.statusText !== '') {
          Text(this.statusText)
            .fontSize(Typography.micro)
            .fontColor(this.uiColors.textTertiary)
            .width('100%')
            .padding({ left: Spacing.md, right: Spacing.md })
            .maxLines(3)
        }
        ErrorBannerView({ text: this.errorText })
  
        Column() {
          Column({ space: Spacing.md }) {
            if (this.loading) {
              Text('读取中…').fontSize(Typography.caption).fontColor(this.uiColors.textTertiary)
            } else if (this.tab === 'images') {
              this.imagesTab()
            } else {
              this.filesTab()
            }
          }
          .width('100%')
          .padding({ bottom: 130 })
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
  imagesTab() {
    Column({ space: Spacing.md }) {
      Text('图片目录')
        .fontSize(Typography.micro)
        .fontColor(this.uiColors.textTertiary)
        .width('100%')
      if (this.folders.length === 0) {
        TextInput({ placeholder: '目标目录，例如 backgrounds', text: this.manualFolder })
          .fontColor(this.uiColors.textPrimary)
          .placeholderColor(this.uiColors.textTertiary)
          .backgroundColor(this.uiColors.bgSurfaceHigh)
          .borderRadius(UIRadius.sm)
          .fontSize(Typography.caption)
          .height(Touch.minTarget)
          .width('100%')
          .backgroundColor(this.uiColors.bgSurfaceHigh)
          .onChange((value: string) => {
            this.manualFolder = value;
          })
      .attributeModifier(new InputFieldStyle(this.uiColors))
      }
      Scroll() {
        Row({ space: 6 }) {
          ForEach(this.folders, (folder: string, index: number) => {
            Button(folder, { type: ButtonType.Normal })
              .fontSize(UIType.micro)
              .constraintSize({ minHeight: 44 })
              .backgroundColor(this.folderIndex === index ? this.uiColors.accent : this.uiColors.bgSurfaceHigh)
              .fontColor(this.folderIndex === index ? this.uiColors.textInverse : this.uiColors.textSecondary)
              .onClick(() => {
                this.selectFolder(index);
              })
          .attributeModifier(new ActionButtonStyle(this.uiColors, (this.folderIndex === index) ? ActionTone.Selected : ActionTone.Normal))
      }, (folder: string, index: number) => `${folder}-${index}`)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .edgeEffect(EdgeEffect.Spring, SCROLL_EDGE_OPTIONS)
      .nestedScroll(SCROLL_NESTED_OPTIONS)
      .scrollBar(BarState.Off)
      .width('100%')

      Button('从图库上传图片', { type: ButtonType.Normal })
        .fontSize(Typography.caption)
        .height(Touch.minTarget)
        .width('100%')
        .enabled(!this.busy)
        .onClick(() => {
          this.pickAndUploadImage();
        })

      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      if (this.images.length === 0) {
        EmptyHint('这个目录还没有图片', '换一个目录，或从图库上传一张', this.uiColors)
      } else {
        ForEach(this.images, (path: string) => {
          Row({ space: Spacing.sm }) {
            Text(path)
              .fontSize(Typography.micro)
              .fontColor(this.uiColors.textSecondary)
              .layoutWeight(1)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Button('删除', { type: ButtonType.Normal })
              .fontSize(UIType.micro)
              .constraintSize({ minHeight: 44 })
              .backgroundColor(this.uiColors.danger)
              .id('asset-delete-' + path)
              .onClick(() => {
                this.confirmDeleteImage(path);
              })
          .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Danger))
      }
          .width('100%')
          .padding(Spacing.sm)
          .backgroundColor(this.uiColors.bgSurface)
          .borderRadius(Radius.sm)
          .attributeModifier(new SurfaceStyle(this.uiColors, Radius.sm))
        }, (path: string) => path)
      }
    }
    .width('100%')
  }

  @Builder
  filesTab() {
    Column({ space: Spacing.md }) {
      Text('用户文件放在 default-user/user/files/，会以 /user/files/<名字> 的形式被提示词引用。')
        .fontSize(Typography.micro)
        .fontColor(this.uiColors.textTertiary)
        .width('100%')
      TextInput({ placeholder: '保存文件名（留空用原文件名）', text: this.fileName })
        .fontColor(this.uiColors.textPrimary)
        .placeholderColor(this.uiColors.textTertiary)
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(UIRadius.sm)
        .fontSize(Typography.caption)
        .height(Touch.minTarget)
        .width('100%')
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .onChange((value: string) => {
          this.fileName = value;
        })
      .attributeModifier(new InputFieldStyle(this.uiColors))
      Button('选择文件并上传', { type: ButtonType.Normal })
        .fontSize(Typography.caption)
        .height(Touch.minTarget)
        .width('100%')
        .enabled(!this.busy)
        .onClick(() => {
          this.pickAndUploadFile();
        })

      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Normal))
      Text('校验文件是否存在（每行一个路径）')
        .fontSize(Typography.micro)
        .fontColor(this.uiColors.textTertiary)
        .width('100%')
      TextArea({ text: this.verifyInput, placeholder: '/user/files/a.png' })
        .fontColor(this.uiColors.textPrimary)
        .placeholderColor(this.uiColors.textTertiary)
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(UIRadius.sm)
        .fontSize(Typography.caption)
        .height(110)
        .width('100%')
        .backgroundColor(this.uiColors.bgSurfaceHigh)
        .borderRadius(Radius.sm)
        .onChange((value: string) => {
          this.verifyInput = value;
        })
      .attributeModifier(new TextAreaFieldStyle(this.uiColors))
      Button('开始校验', { type: ButtonType.Normal })
        .fontSize(Typography.caption)
        .height(Touch.minTarget)
        .width('100%')
        .enabled(!this.busy)
        .onClick(() => {
          this.verifyFiles();
        })
      .attributeModifier(new ActionButtonStyle(this.uiColors, ActionTone.Primary))
      if (this.verifyResult !== '') {
        Text(this.verifyResult)
          .fontSize(Typography.micro)
          .fontColor(this.uiColors.textSecondary)
          .width('100%')
      }
    }
    .width('100%')
  }
}
