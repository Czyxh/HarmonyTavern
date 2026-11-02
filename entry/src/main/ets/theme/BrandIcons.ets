export class BrandIcons {
  static provider(id: string): string {
    if (id === 'deepseek') { return 'deepseek'; }
    if (id === 'openai') { return 'openai'; }
    if (id === 'claude') { return 'claude'; }
    if (id === 'makersuite') { return 'gemini'; }
    if (id === 'moonshot') { return 'kimi'; }
    if (id === 'zai') { return 'zai'; }
    if (id === 'zhipu') { return 'zhipu'; }
    if (id === 'minimax') { return 'minimax'; }
    if (id === 'xai') { return 'grok'; }
    if (id === 'cohere') { return 'cohere'; }
    if (id === 'qwen') { return 'qwen'; }
    if (id === 'doubao') { return 'doubao'; }
    if (id === 'qianfan') { return 'wenxin'; }
    if (id === 'hunyuan') { return 'hunyuan'; }
    if (id === 'stepfun') { return 'stepfun'; }
    if (id === 'mistral') { return 'mistral'; }
    if (id === 'yi') { return 'yi'; }
    if (id === 'baichuan') { return 'baichuan'; }
    if (id === 'perplexity') { return 'perplexity'; }
    if (id === 'openrouter') { return 'openrouter'; }
    if (id === 'siliconflow') { return 'siliconcloud'; }
    if (id === 'groq') { return 'groq'; }
    if (id === 'opencode') { return 'opencode'; }
    if (id === 'chutes') { return 'chutes'; }
    if (id === 'pollinations') { return 'pollinations'; }
    if (id === 'workers_ai') { return 'cloudflare'; }
    if (id === 'aws_bedrock') { return 'bedrock'; }
    if (id === 'vertexai') { return 'vertexai'; }
    if (id === 'together') { return 'together'; }
    if (id === 'fireworks') { return 'fireworks'; }
    if (id === 'ollama') { return 'ollama'; }
    if (id === 'lmstudio') { return 'lmstudio'; }
    return '';
  }

  static model(id: string): string {
    const normalized: string = id.trim().toLowerCase();
    const name: string = normalized.split('/').pop() ?? '';
    if (/^(deepseek)([-_.:]|$)/.test(name)) { return 'deepseek'; }
    if (/^(claude)([-_.:]|$)/.test(name)) { return 'claude'; }
    if (/^(gemini)([-_.:]|$)/.test(name)) { return 'gemini'; }
    if (/^(gemma)([-_.:0-9]|$)/.test(name)) { return 'gemma'; }
    if (/^(qwen|qwq|qvq)([-_.:0-9]|$)/.test(name)) { return 'qwen'; }
    if (/^(kimi|moonshot)([-_.:]|$)/.test(name)) { return 'kimi'; }
    if (/^(glm|chatglm)([-_.:0-9]|$)/.test(name)) { return 'zhipu'; }
    if (/^(minimax|abab)([-_.:0-9]|$)/.test(name)) { return 'minimax'; }
    if (/^grok([-_.:0-9]|$)/.test(name)) { return 'grok'; }
    if (/^(command)([-_.:]|$)/.test(name) || normalized.startsWith('cohere/')) { return 'cohere'; }
    if (/^(doubao)([-_.:]|$)/.test(name)) { return 'doubao'; }
    if (/^(ernie)([-_.:0-9]|$)/.test(name)) { return 'wenxin'; }
    if (/^(hunyuan)([-_.:]|$)/.test(name)) { return 'hunyuan'; }
    if (/^step([-_.:0-9]|$)/.test(name)) { return 'stepfun'; }
    if (/^(mistral|mixtral|codestral|magistral|ministral|devstral|voxtral|pixtral)([-_.:0-9]|$)/.test(name)) { return 'mistral'; }
    if (/^yi([-_.:0-9]|$)/.test(name)) { return 'yi'; }
    if (/^baichuan([-_.:0-9]|$)/.test(name)) { return 'baichuan'; }
    if (/^sonar([-_.:]|$)/.test(name)) { return 'perplexity'; }
    if (/^(llama)([-_.:0-9]|$)/.test(name)) { return 'meta'; }
    if (/^(gpt|chatgpt|o[1-9]|text-embedding|dall-e|whisper)([-_.:0-9]|$)/.test(name)) { return 'openai'; }
    return '';
  }

  static monochrome(brand: string): boolean {
    return ['openai', 'zai', 'grok', 'groq', 'opencode', 'chutes', 'pollinations', 'ollama', 'lmstudio'].includes(brand);
  }

  static resource(brand: string): Resource {
    if (brand === 'deepseek') { return $r('app.media.brand_deepseek'); }
    if (brand === 'openai') { return $r('app.media.brand_openai'); }
    if (brand === 'claude') { return $r('app.media.brand_claude'); }
    if (brand === 'gemini') { return $r('app.media.brand_gemini'); }
    if (brand === 'kimi') { return $r('app.media.brand_kimi'); }
    if (brand === 'zai') { return $r('app.media.brand_zai'); }
    if (brand === 'zhipu') { return $r('app.media.brand_zhipu'); }
    if (brand === 'minimax') { return $r('app.media.brand_minimax'); }
    if (brand === 'grok') { return $r('app.media.brand_grok'); }
    if (brand === 'cohere') { return $r('app.media.brand_cohere'); }
    if (brand === 'qwen') { return $r('app.media.brand_qwen'); }
    if (brand === 'doubao') { return $r('app.media.brand_doubao'); }
    if (brand === 'wenxin') { return $r('app.media.brand_wenxin'); }
    if (brand === 'hunyuan') { return $r('app.media.brand_hunyuan'); }
    if (brand === 'stepfun') { return $r('app.media.brand_stepfun'); }
    if (brand === 'mistral') { return $r('app.media.brand_mistral'); }
    if (brand === 'yi') { return $r('app.media.brand_yi'); }
    if (brand === 'baichuan') { return $r('app.media.brand_baichuan'); }
    if (brand === 'perplexity') { return $r('app.media.brand_perplexity'); }
    if (brand === 'openrouter') { return $r('app.media.brand_openrouter'); }
    if (brand === 'siliconcloud') { return $r('app.media.brand_siliconcloud'); }
    if (brand === 'groq') { return $r('app.media.brand_groq'); }
    if (brand === 'opencode') { return $r('app.media.brand_opencode'); }
    if (brand === 'chutes') { return $r('app.media.brand_chutes'); }
    if (brand === 'pollinations') { return $r('app.media.brand_pollinations'); }
    if (brand === 'cloudflare') { return $r('app.media.brand_cloudflare'); }
    if (brand === 'bedrock') { return $r('app.media.brand_bedrock'); }
    if (brand === 'vertexai') { return $r('app.media.brand_vertexai'); }
    if (brand === 'together') { return $r('app.media.brand_together'); }
    if (brand === 'fireworks') { return $r('app.media.brand_fireworks'); }
    if (brand === 'ollama') { return $r('app.media.brand_ollama'); }
    if (brand === 'lmstudio') { return $r('app.media.brand_lmstudio'); }
    if (brand === 'meta') { return $r('app.media.brand_meta'); }
    if (brand === 'gemma') { return $r('app.media.brand_gemma'); }
    return $r('app.media.icon_model');
  }
}
