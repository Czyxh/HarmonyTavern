import { GenerateRequestDto, CharacterDto } from './Types';
import { StorySettings } from './NativeStory';
import { ProviderSetup } from './ProviderSetup';

export interface StoryDraft {
  title: string;
  scenario: string;
  style: string;
  author_note: string;
  opening_message: string;
}
interface StoryAssistantResponse { choices?: StoryAssistantChoice[]; }
interface StoryAssistantChoice { finish_reason?: string; }
interface StoryPromptCharacter { name: string; description: string; first_mes: string; }
interface StoryPrompt { requirement: string; character: StoryPromptCharacter; current: StoryDraft; }

export class StoryAssistant {
  static request(requirement: string, character: CharacterDto, story: StorySettings): GenerateRequestDto {
    if (requirement.trim() === '' || requirement.length > 3000) { throw new Error('请填写 1～3000 字的故事需求'); }
    const prompt: StoryPrompt = { requirement: requirement.trim(), character: { name: character.name,
      description: (character.description ?? '').substring(0, 6000), first_mes: (character.first_mes ?? '').substring(0, 3000) },
      current: { title: story.title, scenario: story.scenario, style: story.style,
        author_note: story.author_note, opening_message: story.opening_message } };
    return { stream: false, temperature: 0.6, max_tokens: 2200,
      messages: [{ role: 'system', content: '你是新建普通对话的故事配置助手。依据用户需求和所选角色生成可编辑草稿，只返回合法JSON对象，必须包含title、scenario、style、author_note、opening_message五个字符串字段。title不超过100字，其余每项不超过3000字。保留用户明确填写的设定，不冒充用户发言，不生成角色卡、世界书选择、聊天模式或工具指令。opening_message是角色的开场白。用中文，不要Markdown或解释。' },
        { role: 'user', content: JSON.stringify(prompt) }] };
  }
  static result(response: ESObject): StoryDraft {
    const finish: string = (response as StoryAssistantResponse).choices?.[0]?.finish_reason ?? '';
    if (finish !== '' && !['stop', 'end_turn', 'STOP'].includes(finish)) { throw new Error('草稿未完整生成，请重试'); }
    const text: string = ProviderSetup.responseText(response).trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '');
    if (text.length > 16000) { throw new Error('生成草稿过长，请缩短需求后重试'); }
    let draft: StoryDraft;
    try { draft = JSON.parse(text) as StoryDraft; }
    catch (_) { throw new Error('辅助模型返回的草稿不是有效 JSON，请重试'); }
    if (draft === null || typeof draft !== 'object' || typeof draft.title !== 'string' ||
      typeof draft.scenario !== 'string' || typeof draft.style !== 'string' ||
      typeof draft.author_note !== 'string' || typeof draft.opening_message !== 'string') {
      throw new Error('辅助模型没有返回完整的故事草稿');
    }
    if (draft.title.length > 100 || [draft.scenario, draft.style, draft.author_note, draft.opening_message]
      .some((value: string): boolean => value.length > 3000) ||
      [draft.title, draft.scenario, draft.style, draft.author_note, draft.opening_message].every((value: string): boolean => value.trim() === '')) {
      throw new Error('故事草稿为空或超出长度限制，请重试');
    }
    return { title: draft.title, scenario: draft.scenario, style: draft.style,
      author_note: draft.author_note, opening_message: draft.opening_message };
  }
}
