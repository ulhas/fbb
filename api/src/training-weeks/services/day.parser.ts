import { Inject, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createOpenAI } from '@ai-sdk/openai';
import { Output, generateText, NoObjectGeneratedError } from 'ai';
import { WINSTON_MODULE_PROVIDER } from 'nest-winston';
import pLimit from 'p-limit';
import type { Logger } from 'winston';

import {
  parsedDayLLMSchema,
  type ParsedDay,
  type ParsedDayLLM,
  type ParseWarning,
} from '../schemas/parsed-document.schema';
import { SYSTEM_PROMPT, buildUserPrompt } from '../prompts/parse-day.prompt';
import type { DayChunk } from './document.segmenter';

export interface DayParseOutcome {
  day: ParsedDay | null;
  warnings: ParseWarning[];
  metrics: {
    durationMs: number;
    tokensInput: number;
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
  ): Promise<DayParseBatchResult> {
    const concurrency = this.configService.get<number>('parser.concurrency') ?? 8;
    const limit = pLimit(concurrency);
    const startedAt = Date.now();

    const outcomes = await Promise.all(
      chunks.map((chunk, i) =>
        limit(() => this.parseOne(chunk, sourceFilename, i, requestId)),
      ),
    );

    const llmTotalMs = Date.now() - startedAt;
    const tokensInputTotal = outcomes.reduce((s, o) => s + o.metrics.tokensInput, 0);
    const tokensOutputTotal = outcomes.reduce((s, o) => s + o.metrics.tokensOutput, 0);

    return {
      outcomes,
      metrics: {
        llmTotalMs,
        llmCalls: outcomes.length,
        tokensInputTotal,
        tokensOutputTotal,
        concurrency,
      },
    };
  }

  private async parseOne(
    chunk: DayChunk,
    sourceFilename: string,
    index: number,
    requestId?: string,
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
          tokensOutput: 0,
          attempts: 0,
        },
      };
    }

    const apiKey = this.configService.get<string>('openai.apiKey');
    const model = this.configService.get<string>('openai.parseModel') ?? 'gpt-4o-2024-11-20';
    const maxRetries = this.configService.get<number>('parser.maxRetries') ?? 2;

    if (!apiKey) {
      this.logger.error({
        msg: 'day.parse.missing_api_key',
        requestId,
        locator,
      });
      return {
        day: null,
        warnings: [
          {
            scope: 'day',
            locator,
            code: 'openai_api_key_missing',
            detail: 'OPENAI_API_KEY is not configured; cannot parse day',
          },
        ],
        metrics: {
          durationMs: Date.now() - startedAt,
          tokensInput: 0,
          tokensOutput: 0,
          attempts: 0,
        },
      };
    }

    const openai = createOpenAI({ apiKey });
    const warnings: ParseWarning[] = [];
    let llm: ParsedDayLLM | null = null;
    let tokensInput = 0;
    let tokensOutput = 0;

    try {
      const result = await generateText({
        model: openai(model),
        output: Output.object({ schema: parsedDayLLMSchema }),
        system: SYSTEM_PROMPT,
        prompt: buildUserPrompt(chunk),
        temperature: 0,
        maxRetries,
      });
      llm = result.output as ParsedDayLLM;
      tokensInput = result.usage?.inputTokens ?? 0;
      tokensOutput = result.usage?.outputTokens ?? 0;
    } catch (err) {
      if (err instanceof NoObjectGeneratedError) {
        warnings.push({
          scope: 'day',
          locator,
          code: 'no_object_generated',
          detail: err.message,
        });
      } else {
        warnings.push({
          scope: 'day',
          locator,
          code: 'llm_error',
          detail: err instanceof Error ? err.message : String(err),
        });
      }
      this.logger.warn({
        msg: 'day.parse.llm_failure',
        requestId,
        locator,
        index,
        error: err instanceof Error ? err.message : String(err),
      });
    }

    if (!llm) {
      return {
        day: null,
        warnings,
        metrics: {
          durationMs: Date.now() - startedAt,
          tokensInput,
          tokensOutput,
          attempts: maxRetries + 1,
        },
      };
    }

    // Cross-check: calendar position vs week-line day_position.
    if (llm.day_position != null && llm.day_position !== chunk.position) {
      warnings.push({
        scope: 'day',
        locator,
        code: 'day_position_mismatch',
        detail: `calendar position=${chunk.position} but llm parsed day_position=${llm.day_position}`,
      });
    }

    const day: ParsedDay = {
      ...llm,
      raw_text: chunk.rawText,
      cms_source_id: this.cmsSourceId(sourceFilename, chunk),
    };

    this.logger.debug({
      msg: 'day.parse.ok',
      requestId,
      locator,
      sections: day.sections.length,
      tokensInput,
      tokensOutput,
      durationMs: Date.now() - startedAt,
    });

    return {
      day,
      warnings,
      metrics: {
        durationMs: Date.now() - startedAt,
        tokensInput,
        tokensOutput,
        attempts: 1,
      },
    };
  }

  private cmsSourceId(sourceFilename: string, chunk: DayChunk): string {
    return `persist-pdf:${sourceFilename}#${chunk.trackCode}/${chunk.scheduledOn}`;
  }
}
