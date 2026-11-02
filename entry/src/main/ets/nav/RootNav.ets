// P7 步骤 4：应用唯一的 NavPathStack 单例。
// Index 的 Navigation 用它做容器栈；ChatPage/SettingsPage 通过它 pop 返回首页。
// 用模块级单例而非构造参数下传，规避 ArkUI 自定义组件构造参数对非 @Prop 成员的限制。
export const ROOT_PATH_STACK: NavPathStack = new NavPathStack();

export class LibraryEditIntent {
  private static character: string = '';
  private static world: string = '';
  static editCharacter(key: string): void {
    LibraryEditIntent.character = key;
    ROOT_PATH_STACK.pushPathByName('pages/CharactersPage', null);
  }
  static takeCharacter(): string {
    const key: string = LibraryEditIntent.character; LibraryEditIntent.character = ''; return key;
  }
  static editWorld(name: string): void {
    LibraryEditIntent.world = name;
    ROOT_PATH_STACK.pushPathByName('pages/WorldInfoPage', null);
  }
  static takeWorld(): string {
    const name: string = LibraryEditIntent.world; LibraryEditIntent.world = ''; return name;
  }
}

export class StoryIntent {
  static characterName: string = '';
  static displayName: string = '';
  static fileName: string = '';
  static greeting: string = '';
  static request(characterName: string, displayName: string, greeting: string = '', fileName: string = ''): void {
    StoryIntent.characterName = characterName;
    StoryIntent.displayName = displayName;
    StoryIntent.greeting = greeting;
    StoryIntent.fileName = fileName;
    ROOT_PATH_STACK.pushPathByName('pages/StoryPage', null);
  }
}

export class GroupIntent {
  static groupId: string = '';
  static creating: boolean = false;
  static request(id: string = ''): void { GroupIntent.groupId = id; GroupIntent.creating = id === ''; }
}

/**
 * 跨页面的一次性意图（P8-1）。
 *
 * ArkUI 的 NavDestination 取参要在 onReady 里读 pathInfo.param，而 ChatPage 是
 * `export struct`、由 pageMap 无参构造；为保持单一路径，这里用模块级一次性变量：
 * 首页设置期望打开的会话 → push ChatPage → ChatPage 在 aboutToAppear 里消费并清空。
 * 不消费就残留会让下次进入聊天页莫名跳会话，所以读取后必须立即复位。
 */
export class ChatIntent {
  /** 待打开会话的 "characterKey|fileName"；空串表示无意图。 */
  private static pending: string = '';

  static request(characterKey: string, fileName: string): void {
    ChatIntent.pending = `${characterKey}|${fileName}`;
  }

  /** 取出并清空。 */
  static take(): string {
    const value: string = ChatIntent.pending;
    ChatIntent.pending = '';
    return value;
  }
}
