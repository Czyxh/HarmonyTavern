import { Backend } from './Backend';
import { ChatMessageDto } from './Types';
export interface GroupSessionData { chatId: string; messages: ChatMessageDto[]; }
export class GroupSession {
  static create(groupId: string): Promise<GroupSessionData> {
    return Backend.call<GroupSessionData>('native_group_session', { groupId: groupId, operation: 'create' });
  }
  static read(groupId: string, chatId: string): Promise<GroupSessionData> {
    return Backend.call<GroupSessionData>('native_group_session', { groupId: groupId, chatId: chatId, operation: 'read' });
  }
  static append(groupId: string, chatId: string, expectedCount: number, message: ChatMessageDto): Promise<GroupSessionData> {
    return Backend.call<GroupSessionData>('native_group_session', {
      groupId: groupId, chatId: chatId, expectedCount: expectedCount, message: message, operation: 'append'
    });
  }
}
export class GroupConversationIntent {
  static groupId: string = '';
  static chatId: string = '';
  static request(groupId: string, chatId: string): void {
    GroupConversationIntent.groupId = groupId; GroupConversationIntent.chatId = chatId;
  }
}
