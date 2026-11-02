import { Backend } from './Backend';
import { ChatDto, GenerateRequestDto, TokenUsage } from './Types';

export interface StorySettings {
  title: string;
  scenario: string;
  style: string;
  author_note: string;
  opening_message: string;
  mode: string;
  choice_count: number;
  choices_enabled?: boolean;
  world_books: string[];
  world_ui_request: string;
  world_model_id?: string;
  world_update_mode?: string;
  world_sidebar_side?: string;
}
export interface StoryOption {
  label: string;
  reply: string;
}
export interface StoryChoices {
  turn: string;
  options: StoryOption[];
  needs_options: boolean;
}
export interface StoryReply {
  chat: ChatDto;
  choices: StoryOption[];
}
export function defaultStorySettings(): StorySettings {
  return { title: '', scenario: '', style: '', author_note: '', opening_message: '', mode: 'free', choice_count: 3, choices_enabled: false, world_books: [], world_ui_request: '',
    world_model_id: '', world_update_mode: 'auxiliary', world_sidebar_side: 'auto' };
}
export function storyChoicesEnabled(story: StorySettings): boolean {
  return story.choices_enabled === true || story.mode === 'choices';
}
export class NativeStory {
  static async get(characterName: string, fileName: string): Promise<StorySettings> {
    const story: StorySettings = await Backend.call<StorySettings>('get_native_story', { characterName: characterName, fileName: fileName });
    if (story.world_ui_request === undefined) { story.world_ui_request = ''; }
    if (story.mode === 'choices') { story.mode = 'free'; story.choices_enabled = true; }
    return story;
  }
  static save(characterName: string, fileName: string, story: StorySettings): Promise<StorySettings> {
    return Backend.call<StorySettings>('save_native_story', { characterName: characterName, fileName: fileName, story: story });
  }
  static create(characterName: string, story: StorySettings): Promise<ChatDto> {
    return Backend.call<ChatDto>('create_native_story', { characterName: characterName, story: story });
  }
  static choices(characterName: string, fileName: string): Promise<StoryChoices> {
    return Backend.call<StoryChoices>('get_native_story_choices', { characterName: characterName, fileName: fileName });
  }
  static prepareChoices(characterName: string, fileName: string, dto: GenerateRequestDto): Promise<GenerateRequestDto> {
    return Backend.call<GenerateRequestDto>('prepare_native_story_choices', { characterName: characterName, fileName: fileName, dto: dto });
  }
  static commitChoices(characterName: string, fileName: string, expectedTurn: string, text: string): Promise<StoryChoices> {
    return Backend.call<StoryChoices>('commit_native_story_choices', {
      characterName: characterName, fileName: fileName, expectedTurn: expectedTurn, text: text
    });
  }
  static commit(characterName: string, fileName: string, text: string, usage?: TokenUsage, usageComplete: boolean = true,
    reasoning: string = '', reasoningTruncated: boolean = false, expectedWorldConfig: string = '', model: string = '', usageRequest: string = ''): Promise<StoryReply> {
    return Backend.call<StoryReply>('commit_native_story_reply', {
      characterName: characterName, fileName: fileName, text: text, usage: usage, usageComplete: usageComplete,
      reasoning: reasoning, reasoningTruncated: reasoningTruncated, expectedWorldConfig: expectedWorldConfig, model: model, usageRequest: usageRequest
    });
  }
}
