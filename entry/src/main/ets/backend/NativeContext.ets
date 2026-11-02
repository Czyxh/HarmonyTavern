import { Backend } from './Backend';
import { GenerateRequestDto } from './Types';

export interface ContextStatus {
  active: boolean;
  stale: boolean;
  covered: number;
  total: number;
  summary: string;
  original_chars: number;
  sent_chars: number;
}
export interface ContextPlan {
  expectedTurn: string;
  covered: number;
  dto: GenerateRequestDto;
}
export class NativeContext {
  static status(character: string, file: string): Promise<ContextStatus> {
    return Backend.call<ContextStatus>('get_native_context', { characterName: character, fileName: file });
  }
  static prepare(character: string, file: string, dto: GenerateRequestDto): Promise<ContextPlan> {
    return Backend.call<ContextPlan>('prepare_native_context', { characterName: character, fileName: file, dto: dto });
  }
  static commit(character: string, file: string, turn: string, response: ESObject): Promise<ContextStatus> {
    return Backend.call<ContextStatus>('commit_native_context', {
      characterName: character, fileName: file, expectedTurn: turn, response: response
    });
  }
  static reset(character: string, file: string): Promise<ContextStatus> {
    return Backend.call<ContextStatus>('reset_native_context', { characterName: character, fileName: file });
  }
}
