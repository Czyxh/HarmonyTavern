import { CharacterDto } from './Types';
import { UpdateCharacterDto } from './AdminTypes';

export interface CharacterForm {
  originalName: string;
  originalDisplayName: string;
  name: string;
  description: string;
  personality: string;
  scenario: string;
  firstMes: string;
  mesExample: string;
  creator: string;
  creatorNotes: string;
  version: string;
  tags: string;
  systemPrompt: string;
  postHistory: string;
  alternateGreetings: string[];
}
export class CharacterEditing {
  static key(character: CharacterDto): string { return (character.avatar ?? '').replace(/\.png$/i, '') || character.name; }
  static form(character?: CharacterDto): CharacterForm {
    return { originalName: character === undefined ? '' : CharacterEditing.key(character), originalDisplayName: character?.name ?? '',
      name: character?.name ?? '', description: character?.description ?? '', personality: character?.personality ?? '',
      scenario: character?.scenario ?? '', firstMes: character?.first_mes ?? '', mesExample: character?.mes_example ?? '',
      creator: character?.creator ?? '', creatorNotes: character?.creator_notes ?? '', version: character?.character_version ?? '',
      tags: (character?.tags ?? []).join('，'), systemPrompt: character?.system_prompt ?? '',
      postHistory: character?.post_history_instructions ?? '', alternateGreetings: (character?.alternate_greetings ?? []).slice() };
  }
  static update(form: CharacterForm): UpdateCharacterDto {
    const tags: string[] = [];
    for (const tag of form.tags.split(/[,，\n]/).map((item: string): string => item.trim())) {
      if (tag !== '' && !tags.includes(tag)) { tags.push(tag); }
    }
    return { description: form.description, personality: form.personality, scenario: form.scenario,
      first_mes: form.firstMes, mes_example: form.mesExample, creator: form.creator, creator_notes: form.creatorNotes,
      character_version: form.version, tags: tags, system_prompt: form.systemPrompt,
      post_history_instructions: form.postHistory, alternate_greetings: form.alternateGreetings.filter((value: string): boolean => value.trim() !== '') };
  }
}
