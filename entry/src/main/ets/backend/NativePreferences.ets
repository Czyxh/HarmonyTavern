import { Backend, UserSettingsRevisionShape } from './Backend';
import { GenerateRequestDto } from './Types';

export interface NativePreferences {
  user_name: string;
  user_avatar: string;
  persona_position: string;
  persona_role: string;
  persona_depth: number;
  persona_description: string;
  system_prompt: string;
  system_prompt_enabled: boolean;
  prefer_character_prompt: boolean;
  prefer_character_jailbreak: boolean;
  auto_scroll_chat_to_bottom: boolean;
  confirm_message_delete: boolean;
  trim_spaces: boolean;
  temperature: number;
  top_p: number;
  max_tokens: number;
  context_tokens: number;
  reasoning_effort: string;
}
export interface NativePreferencesSnapshot {
  preferences: NativePreferences;
  revision: UserSettingsRevisionShape;
  avatar_path: string;
}
export function defaultNativePreferences(): NativePreferences {
  return { user_name: 'User', user_avatar: '', persona_position: 'after_character', persona_role: 'system', persona_depth: 4,
    persona_description: '', system_prompt: '', system_prompt_enabled: true,
    prefer_character_prompt: true, prefer_character_jailbreak: true, auto_scroll_chat_to_bottom: true,
    confirm_message_delete: true, trim_spaces: true, temperature: 1, top_p: 1, max_tokens: 8192, context_tokens: 32768, reasoning_effort: 'auto' };
}
export class NativeSettings {
  static get(): Promise<NativePreferencesSnapshot> {
    return Backend.call<NativePreferencesSnapshot>('get_native_preferences', {});
  }
  static save(preferences: NativePreferences, revision: UserSettingsRevisionShape): Promise<NativePreferencesSnapshot> {
    return Backend.call<NativePreferencesSnapshot>('update_native_preferences', {
      preferences: preferences, expectedRevision: revision
    });
  }
  static prepareChat(characterName: string, dto: GenerateRequestDto, fileName: string = '', pendingMessage: string = ''): Promise<GenerateRequestDto> {
    if (fileName !== '') {
      return Backend.call<GenerateRequestDto>('prepare_native_chat', { characterName: characterName, fileName: fileName, dto: dto, pendingMessage: pendingMessage });
    }
    return Backend.call<GenerateRequestDto>('prepare_native_chat', { characterName: characterName, dto: dto });
  }
}
