import 'dotenv/config';

export default () => ({
  port: parseInt(process.env.PORT ?? '3000', 10),
  database: {
    url: process.env.DATABASE_URL,
  },
  openai: {
    apiKey: process.env.OPENAI_API_KEY,
    parseModel: process.env.OPENAI_PARSE_MODEL ?? 'gpt-5.5-2026-04-23',
    // GPT-5 family reasoning effort. Values per OpenAI docs:
    // 'minimal' | 'low' | 'medium' | 'high'. Defaulting to 'medium' — most
    // per-day parses are mechanical pattern matching, not chain-of-thought
    // problems, and reasoning tokens are billed as output. Bump to 'high' if
    // a particular run benefits from extra deliberation.
    reasoningEffort: process.env.OPENAI_REASONING_EFFORT ?? 'medium',
  },
  anthropic: {
    apiKey: process.env.ANTHROPIC_API_KEY,
  },
  parser: {
    // Sample PDFs are <1MB; 10MB cap leaves ample headroom for bulkier weeks.
    maxUploadBytes: parseInt(process.env.PARSER_MAX_UPLOAD_BYTES ?? `${10 * 1024 * 1024}`, 10),
    // One LLM call per track lets wall-time scale with the slowest track,
    // not the day count. Tier-1 OpenAI handles 8 concurrent generateObject calls trivially.
    concurrency: parseInt(process.env.PARSER_CONCURRENCY ?? '8', 10),
    // generateObject re-asks the model on Zod validation failure before falling back to *_text.
    maxRetries: parseInt(process.env.PARSER_MAX_RETRIES ?? '2', 10),
    // Where the original PDF buffer is stored so /retry can re-parse failed
    // days without making the client re-upload. Defaults to a sibling of the
    // process cwd; override per-environment if `pnpm dev` runs from elsewhere.
    uploadsDir: process.env.UPLOADS_DIR ?? 'data/uploads',
  },
});
