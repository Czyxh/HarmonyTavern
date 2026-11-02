import { ChatMessageDto } from '../backend/Types';

export interface ChatMessageRow {
  message: ChatMessageDto;
  index: number;
  key: string;
}
export class ChatMessageSource implements IDataSource {
  private revision: number = 0;
  private messages: ChatMessageDto[] = [];
  private listeners: DataChangeListener[] = [];
  totalCount(): number { return this.messages.length; }
  getData(index: number): ChatMessageRow { return { message: this.messages[index], index: index, key: this.revision + ':' + index }; }
  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) { this.listeners.push(listener); }
  }
  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index: number = this.listeners.indexOf(listener);
    if (index >= 0) { this.listeners.splice(index, 1); }
  }
  replace(messages: ChatMessageDto[]): void {
    this.revision++;
    this.messages = messages;
    this.listeners.forEach((listener: DataChangeListener): void => { listener.onDataReloaded(); });
  }
}
