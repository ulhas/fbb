import { Inject, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { WINSTON_MODULE_PROVIDER } from 'nest-winston';
import type { Logger } from 'winston';

import type {
  ParseMetrics,
  ParseWarning,
  ParsedDay,
  ParsedDocument,
  ParsedTrack,
} from '../schemas/parsed-document.schema';
import type { UploadResponseDto } from '../dto/parse-result.dto';
import { DayParser } from './day.parser';
import { PdfTextService } from './pdf-text.service';
import { parseToc } from './toc.parser';
import { classifyTrack, segment } from './document.segmenter';

export interface UploadInput {
  filename: string;
  buffer: Buffer;
  dryRun: boolean;
  requestId: string;
}

@Injectable()
export class TrainingWeeksService {
  constructor(
    private readonly configService: ConfigService,
    private readonly pdfText: PdfTextService,
    private readonly dayParser: DayParser,
    @Inject(WINSTON_MODULE_PROVIDER) private readonly logger: Logger,
  ) {}

  async uploadAndParse(input: UploadInput): Promise<UploadResponseDto> {
    const { filename, buffer, dryRun, requestId } = input;
    const overallStart = Date.now();

    this.logger.info({
      msg: 'upload.received',
      requestId,
      filename,
      bytes: buffer.byteLength,
      dryRun,
    });

    // Stage 1: extract text from the PDF.
    const extractStart = Date.now();
    const extracted = await this.pdfText.extract(buffer);
    const extractionMs = Date.now() - extractStart;

    // Stage 2: deterministic TOC parse + segmentation. Both run on the same
    // fullText; they're cheap relative to PDF extraction.
    const segStart = Date.now();
    const toc = parseToc(extracted.fullText);
    const segResult = segment(extracted.fullText);
    const segmentationMs = Date.now() - segStart;

    const warnings: ParseWarning[] = [];
    warnings.push(...segResult.warnings);
    warnings.push(...this.crossCheckTocVsBody(toc, segResult.chunks));

    this.logger.info({
      msg: 'upload.segmented',
      requestId,
      filename,
      pageCount: extracted.pageCount,
      tocEntries: toc.entries.length,
      bodyChunks: segResult.chunks.length,
      tracks: segResult.tracks.length,
      segmenterWarnings: segResult.warnings.length,
      crossCheckWarnings: warnings.length - segResult.warnings.length,
      extractionMs,
      segmentationMs,
    });

    // Dry-run short-circuit: report segmentation only, no LLM cost.
    if (dryRun) {
      return this.buildDryRunResponse({
        requestId,
        filename,
        extracted,
        weekStartsOn: segResult.weekStartsOn ?? toc.weekStartsOn,
        chunks: segResult.chunks,
        tracks: segResult.tracks,
        warnings,
        extractionMs,
        segmentationMs,
        overallStart,
      });
    }

    // Stage 3: per-day LLM parse, concurrency-limited.
    const batch = await this.dayParser.parseAll(segResult.chunks, filename, requestId);
    for (const o of batch.outcomes) {
      warnings.push(...o.warnings);
    }

    // Stage 4: assemble the parsed-document tree.
    const document = this.assemble({
      filename,
      weekStartsOn: segResult.weekStartsOn ?? toc.weekStartsOn ?? '',
      pageCount: extracted.pageCount,
      tracks: segResult.tracks,
      outcomes: batch.outcomes,
      chunks: segResult.chunks,
    });

    const metrics: ParseMetrics = {
      model:
        this.configService.get<string>('openai.parseModel') ?? 'gpt-4o-2024-11-20',
      temperature: 0,
      extraction_ms: extractionMs,
      segmentation_ms: segmentationMs,
      llm_total_ms: batch.metrics.llmTotalMs,
      llm_calls: batch.metrics.llmCalls,
      tokens_input_total: batch.metrics.tokensInputTotal,
      tokens_output_total: batch.metrics.tokensOutputTotal,
      tokens_total: batch.metrics.tokensInputTotal + batch.metrics.tokensOutputTotal,
      concurrency: batch.metrics.concurrency,
    };

    this.logger.info({
      msg: 'upload.complete',
      requestId,
      filename,
      totalMs: Date.now() - overallStart,
      tracks: document.tracks.length,
      days: document.tracks.reduce((s, t) => s + t.days.length, 0),
      warnings: warnings.length,
      tokens: metrics.tokens_total,
    });

    return {
      request_id: requestId,
      document,
      parse_warnings: warnings,
      parse_metrics: metrics,
    };
  }

  private crossCheckTocVsBody(
    toc: ReturnType<typeof parseToc>,
    chunks: ReturnType<typeof segment>['chunks'],
  ): ParseWarning[] {
    const warnings: ParseWarning[] = [];
    const tocSet = new Set(
      toc.entries.map((e) => {
        const { trackCode } = classifyTrack(e.trackHeading);
        return `${trackCode}/${e.scheduledOn}`;
      }),
    );
    const bodySet = new Set(chunks.map((c) => `${c.trackCode}/${c.scheduledOn}`));

    for (const expected of tocSet) {
      if (!bodySet.has(expected)) {
        warnings.push({
          scope: 'document',
          locator: expected,
          code: 'toc_missing_in_body',
          detail: `TOC anchor list lists ${expected} but the body has no matching day chunk`,
        });
      }
    }
    for (const found of bodySet) {
      if (!tocSet.has(found)) {
        warnings.push({
          scope: 'document',
          locator: found,
          code: 'body_extra_vs_toc',
          detail: `body parsed ${found} but the TOC anchor list does not list it`,
        });
      }
    }
    return warnings;
  }

  private assemble(input: {
    filename: string;
    weekStartsOn: string;
    pageCount: number;
    tracks: ReturnType<typeof segment>['tracks'];
    outcomes: Array<{ day: ParsedDay | null }>;
    chunks: ReturnType<typeof segment>['chunks'];
  }): ParsedDocument {
    const daysByTrack = new Map<string, ParsedDay[]>();
    for (let i = 0; i < input.outcomes.length; i++) {
      const day = input.outcomes[i].day;
      if (!day) continue;
      const trackCode = input.chunks[i].trackCode;
      const list = daysByTrack.get(trackCode) ?? [];
      list.push(day);
      daysByTrack.set(trackCode, list);
    }

    const tracks: ParsedTrack[] = input.tracks.map((t) => ({
      track_code: t.trackCode,
      family: t.family,
      cadence: t.cadence,
      display_name: t.displayName,
      microcycle: {
        kind: t.microcycle.kind,
        starts_on: t.microcycle.startsOn,
        ends_on: t.microcycle.endsOn,
        mesocycle_position_hint: t.microcycle.mesocyclePositionHint,
        week_position: t.microcycle.weekPosition,
      },
      days: (daysByTrack.get(t.trackCode) ?? []).sort(
        (a, b) => a.position - b.position,
      ),
    }));

    return {
      source_filename: input.filename,
      week_starts_on: input.weekStartsOn,
      page_count: input.pageCount,
      tracks,
    };
  }

  private buildDryRunResponse(args: {
    requestId: string;
    filename: string;
    extracted: { pageCount: number };
    weekStartsOn: string | null;
    chunks: ReturnType<typeof segment>['chunks'];
    tracks: ReturnType<typeof segment>['tracks'];
    warnings: ParseWarning[];
    extractionMs: number;
    segmentationMs: number;
    overallStart: number;
  }): UploadResponseDto {
    const dayCountByTrack = new Map<string, number>();
    for (const c of args.chunks) {
      dayCountByTrack.set(c.trackCode, (dayCountByTrack.get(c.trackCode) ?? 0) + 1);
    }
    const tracksOut = args.tracks.map((t) => ({
      track_code: t.trackCode,
      family: t.family,
      cadence: t.cadence,
      display_name: t.displayName,
      day_count: dayCountByTrack.get(t.trackCode) ?? 0,
    }));

    return {
      request_id: args.requestId,
      document: null,
      parse_warnings: args.warnings,
      parse_metrics: {
        model: 'dry_run',
        temperature: 0,
        extraction_ms: args.extractionMs,
        segmentation_ms: args.segmentationMs,
        llm_total_ms: 0,
        llm_calls: 0,
        tokens_input_total: 0,
        tokens_output_total: 0,
        tokens_total: 0,
        concurrency: 0,
      },
      dry_run: {
        week_starts_on: args.weekStartsOn,
        page_count: args.extracted.pageCount,
        track_count: args.tracks.length,
        day_count: args.chunks.length,
        tracks: tracksOut,
        chunks: args.chunks.map((c) => ({
          track_code: c.trackCode,
          scheduled_on: c.scheduledOn,
          position: c.position,
          kind: c.kind,
          week_position: c.weekPosition,
          day_position: c.dayPosition,
          raw_text_preview: c.rawText.slice(0, 240),
        })),
      },
    };
  }
}
