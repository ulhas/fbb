import { Inject, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Output, generateText, NoObjectGeneratedError } from 'ai';
import { WINSTON_MODULE_PROVIDER } from 'nest-winston';
import pLimit from 'p-limit';
import type { Logger } from 'winston';

import {
  parsedDayLLMSchema,
  type ModelSpec,
  type ParsedDay,
  type ParsedDayLLM,
  type ParseWarning,
} from '../schemas/parsed-document.schema';
import { SYSTEM_PROMPT, buildUserPrompt } from '../prompts/parse-day.prompt';
import { DEFAULT_MODEL_SPEC, resolveModel, type ResolvedModel } from './models';
import type { DayChunk } from './document.segmenter';

export interface DayParseOutcome {
  day: ParsedDay | null;
  warnings: ParseWarning[];
  metrics: {
    durationMs: number;
    tokensInput: number;
    // Subset of `tokensInput` that hit the provider's prompt cache (Anthropic
    // ephemeral cache, OpenAI auto-cache). Used to compute cost at the
    // discounted cached rate.
    tokensCachedInput: number;
    tokensOutput: number;
    attempts: number;
  };
}

export interface DayParseBatchResult {
  outcomes: DayParseOutcome[];
  metrics: {
    llmTotalMs: number;
    llmCalls: number;
    tokensInputTotal: number;
    tokensCachedInputTotal: number;
    tokensOutputTotal: number;
    concurrency: number;
  };
}

@Injectable()
export class DayParser {
  constructor(
    private readonly configService: ConfigService,
    @Inject(WINSTON_MODULE_PROVIDER) private readonly logger: Logger,
  ) {}

  async parseAll(
    chunks: DayChunk[],
    sourceFilename: string,
    requestId?: string,
    onDayComplete?: (
      chunkIndex: number,
      outcome: DayParseOutcome,
    ) => Promise<void>,
    modelSpec: ModelSpec = this.defaultModelSpec(),
  ): Promise<DayParseBatchResult> {
    const concurrency = this.configService.get<number>('parser.concurrency') ?? 8;
    const limit = pLimit(concurrency);
    const startedAt = Date.now();

    // Each scheduled task awaits the parse, optionally invokes the per-day
    // callback (which is where incremental persistence lands), then returns
    // the outcome to the caller. Errors in the callback are logged and
    // swallowed — they shouldn't poison the rest of the batch.
    const outcomes = await Promise.all(
      chunks.map((chunk, i) =>
        limit(async () => {
          const outcome = await this.parseOne(
            chunk,
            sourceFilename,
            i,
            requestId,
            modelSpec,
          );
          if (onDayComplete) {
            try {
              await onDayComplete(i, outcome);
            } catch (err) {
              this.logger.warn({
                msg: 'day.parse.callback_failed',
                requestId,
                chunkIndex: i,
                locator: `${chunk.trackCode}/${chunk.scheduledOn}`,
                error: err instanceof Error ? err.message : String(err),
              });
            }
          }
          return outcome;
        }),
      ),
    );

    const llmTotalMs = Date.now() - startedAt;
    const tokensInputTotal = outcomes.reduce((s, o) => s + o.metrics.tokensInput, 0);
    const tokensCachedInputTotal = outcomes.reduce(
      (s, o) => s + o.metrics.tokensCachedInput,
      0,
    );
    const tokensOutputTotal = outcomes.reduce((s, o) => s + o.metrics.tokensOutput, 0);

    return {
      outcomes,
      metrics: {
        llmTotalMs,
        llmCalls: outcomes.length,
        tokensInputTotal,
        tokensCachedInputTotal,
        tokensOutputTotal,
        concurrency,
      },
    };
  }

  // Reads the legacy openai.* config (parseModel + reasoningEffort) so the
  // existing happy path (POST /upload-jobs without a model spec) still picks
  // up env-driven overrides. New callers (POST /upload-jobs/:id/reparse-as)
  // pass an explicit ModelSpec instead.
  defaultModelSpec(): ModelSpec {
    const model = this.configService.get<string>('openai.parseModel');
    const reasoningEffort = this.configService.get<string>(
      'openai.reasoningEffort',
    );
    if (!model) return DEFAULT_MODEL_SPEC;
    return {
      provider: 'openai',
      model,
      reasoning_effort:
        (reasoningEffort as ModelSpec['reasoning_effort']) ?? null,
    };
  }

  private async parseOne(
    chunk: DayChunk,
    sourceFilename: string,
    index: number,
    requestId: string | undefined,
    modelSpec: ModelSpec,
  ): Promise<DayParseOutcome> {
    const locator = `${chunk.trackCode}/${chunk.scheduledOn}`;
    const startedAt = Date.now();

    // Lesson-day Marcus letters: skip the LLM entirely. We have no sections to
    // parse, just narrative — wrap it as a coaching_notes entry and return.
    if (chunk.kind === 'lesson') {
      const day: ParsedDay = {
        scheduled_on: chunk.scheduledOn,
        position: chunk.position,
        display_name: chunk.displayName,
        kind: 'lesson',
        is_optional: false,
        week_position: chunk.weekPosition,
        day_position: chunk.dayPosition,
        raw_text: chunk.rawText,
        cms_source_id: this.cmsSourceId(sourceFilename, chunk),
        sections: [],
        coaching_notes: [
          {
            kind: 'lesson',
            title: chunk.displayName,
            body_markdown: chunk.rawText.trim(),
          },
        ],
      };
      return {
        day,
        warnings: [],
        metrics: {
          durationMs: Date.now() - startedAt,
          tokensInput: 0,
          tokensCachedInput: 0,
          tokensOutput: 0,
          attempts: 0,
        },
      };
    }

    const maxRetries = this.configService.get<number>('parser.maxRetries') ?? 2;
    const warnings: ParseWarning[] = [];

    let resolved: ResolvedModel;
    try {
      resolved = resolveModel({
        spec: modelSpec,
        openaiApiKey: this.configService.get<string>('openai.apiKey'),
        anthropicApiKey: this.configService.get<string>('anthropic.apiKey'),
      });
    } catch (err) {
      this.logger.error({
        msg: 'day.parse.model_resolve_failed',
        requestId,
        locator,
        provider: modelSpec.provider,
        model: modelSpec.model,
        error: err instanceof Error ? err.message : String(err),
      });
      return {
        day: null,
        warnings: [
          {
            scope: 'day',
            locator,
            code: 'model_resolve_failed',
            detail: err instanceof Error ? err.message : String(err),
          },
        ],
        metrics: {
          durationMs: Date.now() - startedAt,
          tokensInput: 0,
          tokensCachedInput: 0,
          tokensOutput: 0,
          attempts: 0,
        },
      };
    }

    let llm: ParsedDayLLM | null = null;
    let tokensInput = 0;
    let tokensCachedInput = 0;
    let tokensOutput = 0;

    this.logger.info({
      msg: 'day.parse.start',
      requestId,
      locator,
      index,
      kind: chunk.kind,
      rawTextChars: chunk.rawText.length,
      provider: modelSpec.provider,
      model: modelSpec.model,
      reasoningEffort: modelSpec.reasoning_effort,
    });

    try {
      const result = await generateText({
        model: resolved.model,
        output: Output.object({ schema: parsedDayLLMSchema }),
        system: SYSTEM_PROMPT,
        prompt: buildUserPrompt(chunk),
        ...(resolved.applyTemperatureZero ? { temperature: 0 } : {}),
        maxRetries,
        providerOptions: resolved.providerOptions,
      });
      llm = result.output as ParsedDayLLM;
      tokensInput = result.usage?.inputTokens ?? 0;
      tokensOutput = result.usage?.outputTokens ?? 0;
      // Both providers report cached prefix hits via inputTokenDetails.
      // AI SDK normalises this into `cachedInputTokens` (deprecated alias)
      // and `inputTokenDetails.cacheReadTokens`. Read both with a safe
      // fallback so older AI SDK versions stay supported.
      const usage = result.usage as
        | {
            cachedInputTokens?: number;
            inputTokenDetails?: { cacheReadTokens?: number };
          }
        | undefined;
      tokensCachedInput =
        usage?.inputTokenDetails?.cacheReadTokens ??
        usage?.cachedInputTokens ??
        0;
    } catch (err) {
      // Capture as much context as the AI SDK gives us. NoObjectGeneratedError
      // carries `text` (the raw model output that failed validation) and
      // `cause` (the underlying ZodError or schema-validation error). Logging
      // these is what lets us see *why* a particular day didn't fit the
      // schema — without them the failure is opaque.
      const errCtx: Record<string, unknown> = {
        msg: 'day.parse.llm_failure',
        requestId,
        locator,
        index,
        kind: chunk.kind,
        rawTextChars: chunk.rawText.length,
        rawTextPreview: chunk.rawText.slice(0, 240),
        error: err instanceof Error ? err.message : String(err),
      };
      if (err instanceof NoObjectGeneratedError) {
        errCtx.code = 'no_object_generated';
        errCtx.modelOutputText = err.text?.slice(0, 4000) ?? null;
        errCtx.modelUsage = err.usage ?? null;
        errCtx.causeName = err.cause instanceof Error ? err.cause.name : null;
        errCtx.causeMessage =
          err.cause instanceof Error ? err.cause.message : String(err.cause ?? '');
        // Walk the cause chain looking for Zod issues. AI_TypeValidationError
        // wraps the underlying ZodError; surfacing its `issues[]` is the only
        // way to know *which* field rejected without re-running the call.
        const issues = extractZodIssues(err.cause);
        if (issues.length > 0) {
          errCtx.zodIssues = issues
            .slice(0, 10)
            .map((i) => ({
              path: i.path.join('.'),
              code: i.code,
              message: i.message,
            }));
        }
        warnings.push({
          scope: 'day',
          locator,
          code: 'no_object_generated',
          detail: issues.length > 0
            ? `${err.message} | first issue: ${issues[0].path.join('.')} — ${issues[0].message}`
            : err.message,
        });
      } else {
        errCtx.code = 'llm_error';
        warnings.push({
          scope: 'day',
          locator,
          code: 'llm_error',
          detail: err instanceof Error ? err.message : String(err),
        });
      }
      this.logger.warn(errCtx);
    }

    if (!llm) {
      return {
        day: null,
        warnings,
        metrics: {
          durationMs: Date.now() - startedAt,
          tokensInput,
          tokensCachedInput,
          tokensOutput,
          attempts: maxRetries + 1,
        },
      };
    }

    // Patch in everything the segmenter already knows. Day-position mismatch
    // is raised at segment time (see document.segmenter.ts), so we don't need
    // to ask the LLM to echo it back for cross-check.
    const day: ParsedDay = {
      ...llm,
      scheduled_on: chunk.scheduledOn,
      position: chunk.position,
      display_name: chunk.displayName,
      kind: chunk.kind,
      is_optional: chunk.isOptional,
      week_position: chunk.weekPosition,
      day_position: chunk.dayPosition,
      raw_text: chunk.rawText,
      cms_source_id: this.cmsSourceId(sourceFilename, chunk),
    };

    this.logger.info({
      msg: 'day.parse.ok',
      requestId,
      locator,
      sections: day.sections.length,
      tokensInput,
      tokensCachedInput,
      tokensOutput,
      durationMs: Date.now() - startedAt,
    });

    return {
      day,
      warnings,
      metrics: {
        durationMs: Date.now() - startedAt,
        tokensInput,
        tokensCachedInput,
        tokensOutput,
        attempts: 1,
      },
    };
  }

  private cmsSourceId(sourceFilename: string, chunk: DayChunk): string {
    return `persist-pdf:${sourceFilename}#${chunk.trackCode}/${chunk.scheduledOn}`;
  }
}

interface ZodLikeIssue {
  path: Array<string | number>;
  code: string;
  message: string;
}

/**
 * Walk an unknown error cause chain looking for Zod-style `.issues[]`. The AI
 * SDK wraps Zod validation errors in `AI_TypeValidationError`, so the
 * `ZodError` is two layers deep at minimum. Extracts a flat list of issues
 * with `path`, `code`, and `message` for structured logging.
 */
function extractZodIssues(cause: unknown, depth = 0): ZodLikeIssue[] {
  if (depth > 5 || cause == null || typeof cause !== 'object') return [];
  const obj = cause as { issues?: unknown; cause?: unknown; errors?: unknown };
  if (Array.isArray(obj.issues)) {
    return obj.issues
      .filter((i): i is ZodLikeIssue =>
        i != null && typeof i === 'object' &&
        Array.isArray((i as { path?: unknown }).path) &&
        typeof (i as { message?: unknown }).message === 'string',
      )
      .map((i) => ({
        path: i.path,
        code: typeof i.code === 'string' ? i.code : 'unknown',
        message: i.message,
      }));
  }
  if (obj.cause) return extractZodIssues(obj.cause, depth + 1);
  if (Array.isArray(obj.errors)) {
    for (const e of obj.errors) {
      const found = extractZodIssues(e, depth + 1);
      if (found.length > 0) return found;
    }
  }
  return [];
}
