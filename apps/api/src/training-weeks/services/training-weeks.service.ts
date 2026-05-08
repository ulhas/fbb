import { Inject, Injectable } from '@nestjs/common';
import { WINSTON_MODULE_PROVIDER } from 'nest-winston';
import type { Logger } from 'winston';

import type {
  ModelSpec,
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
import { computeCostUsd, findCatalogEntry } from './models';
import { TrainingWeekPersister } from './training-week.persister';
import { UploadJobsService } from './upload-jobs.service';

export interface UploadInput {
  filename: string;
  buffer: Buffer;
  dryRun: boolean;
  requestId: string;
  // When omitted, uses the env-driven default ModelSpec via DayParser. Reparse
  // calls (POST /upload-jobs/:id/reparse-as) supply an explicit one.
  modelSpec?: ModelSpec;
}

@Injectable()
export class TrainingWeeksService {
  constructor(
    private readonly pdfText: PdfTextService,
    private readonly dayParser: DayParser,
    private readonly persister: TrainingWeekPersister,
    private readonly uploadJobs: UploadJobsService,
    @Inject(WINSTON_MODULE_PROVIDER) private readonly logger: Logger,
  ) {}

  // Async entry point: persists a job row, writes the PDF to disk so /retry
  // can re-parse failed days later, and kicks off `executeJob` on the next
  // tick. The PDF buffer also stays in process memory for the duration of
  // the parse via the closure, so the disk write is solely a retry
  // affordance — the active parse never reads it back.
  async enqueue(input: UploadInput): Promise<{ jobId: string }> {
    const job = await this.uploadJobs.create({
      filename: input.filename,
      sizeBytes: input.buffer.byteLength,
      dryRun: input.dryRun,
      requestId: input.requestId,
    });

    // Save before launching the parse — if disk write fails we'd rather know
    // immediately than discover at retry time.
    try {
      await this.uploadJobs.savePdf(job.id, input.buffer);
    } catch (err) {
      this.logger.error({
        msg: 'upload_job.pdf_save_failed',
        jobId: job.id,
        requestId: input.requestId,
        error: err instanceof Error ? err.message : String(err),
      });
      // Non-fatal: continue with the parse; retry won't be possible for this
      // job, which is acceptable for an admin tool.
    }

    // Don't await — the request returns once the job row is durable.
    void this.executeJob(job.id, input).catch((err) => {
      this.logger.error({
        msg: 'upload_job.unhandled_error',
        jobId: job.id,
        requestId: input.requestId,
        error: err instanceof Error ? err.message : String(err),
      });
      void this.uploadJobs.markFailed(
        job.id,
        err instanceof Error ? err.message : String(err),
      );
    });

    return { jobId: job.id };
  }

  // Spawns a NEW upload job from an existing job's PDF, using a different
  // ModelSpec. This is what powers the admin "Reparse with…" picker — the
  // original job is left untouched so two runs can be compared side-by-side.
  // Throws when the source PDF was cleaned up from disk.
  async reparseAs(
    sourceJobId: string,
    modelSpec: ModelSpec,
    requestId: string,
  ): Promise<{ jobId: string }> {
    const source = await this.uploadJobs.get(sourceJobId);
    if (!source) {
      throw new Error(`upload job ${sourceJobId} not found`);
    }
    const buffer = await this.uploadJobs.loadPdf(sourceJobId);
    if (!buffer) {
      throw new Error(
        `pdf for upload job ${sourceJobId} is no longer on disk; re-upload required`,
      );
    }
    return this.enqueue({
      filename: source.filename,
      buffer,
      dryRun: false,
      requestId,
      modelSpec,
    });
  }

  // Wipes every microcycle for a calendar week. Source upload-jobs are kept
  // (audit trail + the original PDF stays addressable); the admin can
  // re-upload to rebuild. Returns the count of microcycles deleted.
  async deleteWeek(
    weekStartsOn: string,
  ): Promise<{ deletedCount: number }> {
    return this.persister.deleteWeek(weekStartsOn);
  }

  // Re-parses only the days that failed last time, using the PDF buffer we
  // saved on enqueue. Reuses the same job row (no new id) — status flips
  // back to 'running' for the duration. Days that succeed land in the
  // relational tables; result_payload.parse_warnings is rewritten to drop
  // the locators that now pass. Document tree in result_payload stays as-is
  // (relational is the source of truth from now on).
  //
  // `opts.dayLocators`, when provided, overrides the auto-derivation and
  // forces re-parse of exactly those locators (`track_code/YYYY-MM-DD`).
  // Used by the admin UI to re-run days the LLM "succeeded" on but returned
  // empty — those don't carry a parse_warning so the auto-derivation skips
  // them.
  async retry(
    jobId: string,
    opts?: { dayLocators?: string[] },
  ): Promise<{ jobId: string; failedDayCount: number }> {
    const job = await this.uploadJobs.get(jobId);
    if (!job) {
      throw new Error(`upload job ${jobId} not found`);
    }
    if (job.status === 'queued' || job.status === 'running') {
      throw new Error(
        `upload job ${jobId} is still ${job.status}; wait for it to finish before retrying`,
      );
    }

    const buffer = await this.uploadJobs.loadPdf(jobId);
    if (!buffer) {
      throw new Error(
        `original PDF is no longer on disk for job ${jobId}; re-upload to retry`,
      );
    }

    const existing = (job.resultPayload ?? null) as UploadResponseDto | null;

    let failedLocators: Set<string>;
    if (opts?.dayLocators) {
      const requested = opts.dayLocators;
      const malformed = requested.filter(
        (l) => !/^[A-Za-z0-9_]+\/\d{4}-\d{2}-\d{2}$/.test(l),
      );
      if (malformed.length > 0) {
        throw new Error(
          `invalid day locator(s): ${malformed.join(', ')} — expected "track_code/YYYY-MM-DD"`,
        );
      }
      failedLocators = new Set(requested);
    } else {
      failedLocators = new Set(
        (existing?.parse_warnings ?? [])
          .filter(
            (w) =>
              w.scope === 'day' &&
              (w.code === 'no_object_generated' ||
                w.code === 'llm_error' ||
                w.code === 'persist_failed'),
          )
          .map((w) => w.locator),
      );
    }

    if (failedLocators.size === 0) {
      this.logger.info({
        msg: 'upload_job.retry_noop',
        jobId,
        reason: 'no_failed_days',
      });
      return { jobId, failedDayCount: 0 };
    }

    await this.uploadJobs.markRunning(jobId);

    void this.executeRetry(jobId, {
      filename: job.filename,
      buffer,
      dryRun: false,
      requestId: job.requestId,
    }, failedLocators, existing).catch((err) => {
      this.logger.error({
        msg: 'upload_job.retry_unhandled_error',
        jobId,
        error: err instanceof Error ? err.message : String(err),
      });
      void this.uploadJobs.markFailed(
        jobId,
        err instanceof Error ? err.message : String(err),
      );
    });

    return { jobId, failedDayCount: failedLocators.size };
  }

  private async executeRetry(
    jobId: string,
    input: UploadInput,
    failedLocators: Set<string>,
    existing: UploadResponseDto | null,
  ): Promise<void> {
    const { filename, buffer, requestId } = input;
    const overallStart = Date.now();

    this.logger.info({
      msg: 'upload_job.retry_start',
      jobId,
      requestId,
      failedDayCount: failedLocators.size,
    });

    this.persister.resetMovementCache();

    // Re-extract + re-segment. Both are deterministic so the chunks line up
    // 1:1 with the original run.
    const extracted = await this.pdfText.extract(buffer);
    const segResult = segment(extracted.fullText);

    // Build the subset of chunks corresponding to failed locators, keeping
    // the original index so we can correlate per-day callbacks back.
    const retryChunks: Array<{ chunk: typeof segResult.chunks[number]; originalIndex: number }> = [];
    segResult.chunks.forEach((chunk, originalIndex) => {
      if (failedLocators.has(`${chunk.trackCode}/${chunk.scheduledOn}`)) {
        retryChunks.push({ chunk, originalIndex });
      }
    });

    // Resolve dayIds for the retry set. Shells were created on the original
    // run; we reuse them rather than dropping & recreating (which would
    // cascade-delete sibling days that succeeded).
    const dayIdByRetryIndex = await this.persister.findDayIds(
      filename,
      retryChunks.map(({ chunk }, i) => ({
        trackCode: chunk.trackCode,
        position: chunk.position,
        key: i,
      })),
    );

    const newWarnings: ParseWarning[] = [];
    const succeededLocators = new Set<string>();

    // Retry reuses the original job's modelSpec (we want apples-to-apples on
    // a re-attempt). Falls back to env default if the original predates the
    // multi-provider schema.
    const modelSpec =
      existing?.parse_metrics?.model_spec ?? this.dayParser.defaultModelSpec();
    const batch = await this.dayParser.parseAll(
      retryChunks.map((c) => c.chunk),
      filename,
      requestId,
      async (filteredIndex, outcome) => {
        const dayId = dayIdByRetryIndex.get(filteredIndex);
        const chunk = retryChunks[filteredIndex].chunk;
        const locator = `${chunk.trackCode}/${chunk.scheduledOn}`;
        if (!dayId || !outcome.day) return;
        try {
          // Defensive: a previously-failed day shouldn't have any contents,
          // but if a partial persist left orphans, clear them before
          // re-inserting so we don't violate (day_id, position) uniques.
          await this.persister.clearDayContents(dayId);
          await this.persister.persistDayContents(dayId, outcome.day, requestId);
          succeededLocators.add(locator);
        } catch (err) {
          newWarnings.push({
            scope: 'day',
            locator,
            code: 'persist_failed',
            detail: err instanceof Error ? err.message : String(err),
          });
        }
      },
      modelSpec,
    );

    for (const o of batch.outcomes) newWarnings.push(...o.warnings);

    // Merge: keep all non-day warnings + day warnings whose locator wasn't
    // in this retry set + new warnings from the retry. Locators that
    // succeeded this round drop out entirely.
    const keptWarnings = (existing?.parse_warnings ?? []).filter((w) => {
      if (w.scope !== 'day') return true;
      if (!failedLocators.has(w.locator)) return true;
      // This warning was for a retried locator; drop it. New warnings (if
      // it failed again) get added below.
      return false;
    });
    // Dedupe new warnings by locator+code so a successful locator's slate
    // is clean.
    const finalWarnings = [
      ...keptWarnings,
      ...newWarnings.filter((w) => !succeededLocators.has(w.locator)),
    ];

    // Cumulative totals after this retry round.
    const totalInput =
      (existing?.parse_metrics?.tokens_input_total ?? 0) +
      batch.metrics.tokensInputTotal;
    const totalCachedInput =
      (existing?.parse_metrics?.tokens_cached_input_total ?? 0) +
      batch.metrics.tokensCachedInputTotal;
    const totalOutput =
      (existing?.parse_metrics?.tokens_output_total ?? 0) +
      batch.metrics.tokensOutputTotal;
    const retryCost = this.costFor(modelSpec, {
      input: totalInput,
      cachedInput: totalCachedInput,
      output: totalOutput,
    });
    const merged: UploadResponseDto = {
      request_id: existing?.request_id ?? requestId,
      document: existing?.document ?? null,
      parse_warnings: finalWarnings,
      parse_metrics: {
        model: modelSpec.model,
        model_spec: modelSpec,
        temperature: 0,
        extraction_ms: existing?.parse_metrics?.extraction_ms ?? 0,
        segmentation_ms: existing?.parse_metrics?.segmentation_ms ?? 0,
        llm_total_ms:
          (existing?.parse_metrics?.llm_total_ms ?? 0) + batch.metrics.llmTotalMs,
        llm_calls:
          (existing?.parse_metrics?.llm_calls ?? 0) + batch.metrics.llmCalls,
        tokens_input_total: totalInput,
        tokens_cached_input_total: totalCachedInput,
        tokens_output_total: totalOutput,
        cost_input_usd: retryCost?.input,
        cost_cached_input_usd: retryCost?.cached,
        cost_output_usd: retryCost?.output,
        cost_total_usd: retryCost?.total,
        tokens_total:
          (existing?.parse_metrics?.tokens_total ?? 0) +
          batch.metrics.tokensInputTotal +
          batch.metrics.tokensOutputTotal,
        concurrency: batch.metrics.concurrency,
      },
    };

    await this.uploadJobs.markSucceeded(jobId, merged);

    this.logger.info({
      msg: 'upload_job.retry_complete',
      jobId,
      requestId,
      attempted: retryChunks.length,
      succeeded: succeededLocators.size,
      stillFailing: retryChunks.length - succeededLocators.size,
      durationMs: Date.now() - overallStart,
    });
  }

  private async executeJob(jobId: string, input: UploadInput): Promise<void> {
    await this.uploadJobs.markRunning(jobId);
    try {
      const result = await this.runParse(input);
      // Per-day persistence already happened inline during runParse. The
      // result we mark on the job is the same shape as before — the source
      // of truth for the parsed structure now lives in the relational
      // tables; this jsonb is the snapshot used by the detail endpoint
      // until it's switched over to read from those tables.
      await this.uploadJobs.markSucceeded(jobId, result);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      this.logger.warn({
        msg: 'upload_job.failed',
        jobId,
        requestId: input.requestId,
        error: message,
      });
      await this.uploadJobs.markFailed(jobId, message);
    }
  }

  private async runParse(input: UploadInput): Promise<UploadResponseDto> {
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

    // Drop the per-upload movement-id cache from any prior parse — it's
    // only valid within a single upload's parallel-parse window.
    this.persister.resetMovementCache();

    // Stage 2.5: pre-create relational shells (tracks → microcycles → days)
    // so each LLM-parsed day can immediately persist its sections in its own
    // transaction. If a track's shell creation fails, its days simply won't
    // be in `dayIdByChunkIndex` and per-day persistence skips them — the
    // upload still completes and the parsed result lands in upload_jobs
    // result_payload either way.
    const shellsStart = Date.now();
    const shells = await this.persister.prepareShells(
      filename,
      segResult,
      requestId,
    );
    this.logger.info({
      msg: 'upload.shells_ready',
      requestId,
      filename,
      tracks: shells.trackCount,
      microcycles: shells.microcycleCount,
      days: shells.dayCount,
      durationMs: Date.now() - shellsStart,
    });

    // Stage 3: per-day LLM parse + incremental persistence. Each parse that
    // succeeds writes its sections immediately so partial uploads remain
    // queryable from the relational tables.
    const modelSpec = input.modelSpec ?? this.dayParser.defaultModelSpec();
    const batch = await this.dayParser.parseAll(
      segResult.chunks,
      filename,
      requestId,
      async (chunkIndex, outcome) => {
        const dayId = shells.dayIdByChunkIndex.get(chunkIndex);
        if (!dayId || !outcome.day) return;
        try {
          await this.persister.persistDayContents(
            dayId,
            outcome.day,
            requestId,
          );
        } catch (err) {
          // The persister already logged details; surface as a warning so the
          // result_payload reflects the per-day persist failure.
          warnings.push({
            scope: 'day',
            locator: `${segResult.chunks[chunkIndex].trackCode}/${segResult.chunks[chunkIndex].scheduledOn}`,
            code: 'persist_failed',
            detail: err instanceof Error ? err.message : String(err),
          });
        }
      },
      modelSpec,
    );
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

    const cost = this.costFor(modelSpec, {
      input: batch.metrics.tokensInputTotal,
      cachedInput: batch.metrics.tokensCachedInputTotal,
      output: batch.metrics.tokensOutputTotal,
    });
    const metrics: ParseMetrics = {
      model: modelSpec.model,
      model_spec: modelSpec,
      temperature: 0,
      extraction_ms: extractionMs,
      segmentation_ms: segmentationMs,
      llm_total_ms: batch.metrics.llmTotalMs,
      llm_calls: batch.metrics.llmCalls,
      tokens_input_total: batch.metrics.tokensInputTotal,
      tokens_cached_input_total: batch.metrics.tokensCachedInputTotal,
      tokens_output_total: batch.metrics.tokensOutputTotal,
      tokens_total: batch.metrics.tokensInputTotal + batch.metrics.tokensOutputTotal,
      cost_input_usd: cost?.input,
      cost_cached_input_usd: cost?.cached,
      cost_output_usd: cost?.output,
      cost_total_usd: cost?.total,
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

  // Cost from token usage + the model's catalog pricing. Returns null when
  // the model isn't in the catalog (e.g. an env override pointing at an
  // unrecognised model id) — caller persists undefined cost fields in that
  // case rather than misleading zeros.
  private costFor(
    spec: ModelSpec,
    tokens: { input: number; cachedInput: number; output: number },
  ): { input: number; cached: number; output: number; total: number } | null {
    const entry = findCatalogEntry(spec);
    if (!entry) return null;
    return computeCostUsd(entry.pricing, tokens);
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
