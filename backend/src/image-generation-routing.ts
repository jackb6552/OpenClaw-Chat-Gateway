const DIRECT_IMAGE_REQUEST_PATTERNS = [
  /(?:生成|创建|制作|设计|出|做)(?:一张|一个|一幅|张|个)?[^。！？\n]{0,40}(?:图|图片|图像|插画|海报|头像|壁纸|封面|logo|图标|照片|场景)/i,
  /(?:图|图片|图像|插画|海报|头像|壁纸|封面|logo|图标|照片|场景)[^。！？\n]{0,40}(?:生成|创建|制作|设计|出图|生图)/i,
  /(?:文生图|生图|画图|画一张|画一幅|画个|画一个|绘制|画出)/i,
  /^(?:请|帮我|给我|为我)\s*画(?!重点)[^。！？\n]{1,80}/i,
  /^(?:请|帮我|给我|为我)?\s*绘图/i,
  /\b(?:draw|paint|sketch|render|generate|create|make|design)\b[^.\n]{0,80}\b(?:image|picture|illustration|poster|logo|icon|wallpaper|cover|photo|scene)\b/i,
  /\b(?:image|picture|illustration|poster|logo|icon|wallpaper|cover|photo|scene)\b[^.\n]{0,80}\b(?:generation|generate|create|make|design|render)\b/i,
];

const PROMPT_AUTHORING_PATTERNS = [
  /(?:提示词|prompt)[^。！？\n]{0,16}(?:优化|润色|改写|扩写|翻译|整理|生成|写|输出)/i,
  /(?:优化|润色|改写|扩写|翻译|整理|写|输出)[^。！？\n]{0,16}(?:提示词|prompt)/i,
];

const NON_GENERATION_QUESTION_PATTERNS = [
  /(?:为什么|怎么|如何|是否|能不能|可以吗|是不是|什么原因)/,
  /(?:分析|评价|建议|识别|描述|解释|总结|翻译|看图|读图|检测|测试|验证)/,
  /\b(?:why|how|whether|analy[sz]e|review|describe|explain|summari[sz]e|translate|detect|test|validate)\b/i,
];

const VISUAL_PROMPT_TOKENS = [
  '海报',
  '插画',
  '绘本',
  '摄影',
  '照片',
  '画面',
  '风格',
  '构图',
  '色彩',
  '光影',
  '镜头',
  '水彩',
  '油画',
  '手绘',
  '素描',
  '像素',
  '人物',
  '场景',
  '侧影',
  '背景',
  '材质',
  '纹理',
  '留白',
  '壁纸',
  '封面',
  '头像',
  '图标',
  'logo',
  'poster',
  'illustration',
  'photo',
  'photography',
  'cinematic',
  'composition',
  'lighting',
  'watercolor',
  'sketch',
  'portrait',
  'background',
  'wallpaper',
  'cover',
  'icon',
];

function normalizePrompt(value: string): string {
  return value
    .replace(/\r\n?/g, '\n')
    .replace(/\s+/g, ' ')
    .trim();
}

function hasPromptAuthoringIntent(prompt: string): boolean {
  return PROMPT_AUTHORING_PATTERNS.some((pattern) => pattern.test(prompt));
}

function hasNonGenerationQuestionIntent(prompt: string): boolean {
  return NON_GENERATION_QUESTION_PATTERNS.some((pattern) => pattern.test(prompt));
}

function hasDirectImageRequest(prompt: string): boolean {
  return DIRECT_IMAGE_REQUEST_PATTERNS.some((pattern) => pattern.test(prompt));
}

function countVisualPromptTokens(prompt: string): number {
  const normalized = prompt.toLowerCase();
  return VISUAL_PROMPT_TOKENS.reduce((count, token) => {
    return normalized.includes(token.toLowerCase()) ? count + 1 : count;
  }, 0);
}

export function isLikelyImageGenerationPrompt(value: string): boolean {
  const prompt = normalizePrompt(value);
  if (!prompt) return false;

  const directImageRequest = hasDirectImageRequest(prompt);
  if (directImageRequest) {
    return true;
  }

  if (hasPromptAuthoringIntent(prompt) || hasNonGenerationQuestionIntent(prompt)) {
    return false;
  }

  return countVisualPromptTokens(prompt) >= 3;
}
