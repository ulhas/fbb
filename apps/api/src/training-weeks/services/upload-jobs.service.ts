import { EventEmitter } from 'node:events';
import { promises as fs } from 'node:fs';
import * as path from 'node:path';

import {
  Inject,
  Injectable,
  type OnApplicationBootstrap,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { desc, eq, inArray, sql } from 'drizzle-orm';
import { WINSTON_MODULE_PROVIDER } from 'nest-winston';
import type { Logger } from 'winston';

import { DatabaseService } from '../../database/database.service';
import {
  type NewUploadJob,
  type UploadJob,
  type UploadJobStatus,
  uploadJobs,
} from '../../database/schema/upload-jobs';
import type { UploadResponseDto } from '../dto/parse-result.dto';

// Single-process completion notifier. Long-poll handlers subscribe on
// `done:<jobId>` and the runner emits on terminal status. Entirely in-memory
// — fine for single-instance admin deployment; if we ever scale out, swap
// for LISTEN/NOTIFY against the upload_jobs table (the DB row already carries
// the canonical state, so a bus-only swap is safe).
@Injectable()
export class UploadJobsService implements OnApplicationBootstrap {
  private readonly emitter = new EventEmitter();

  constructor(
    private readonly database: DatabaseService,
    private readonly config: ConfigService,
    @Inject(WINSTON_MODULE_PROVIDER) private readonly logger: Logger,
  ) {
    // Long-poll handlers attach listeners; allow many without warnings.
    this.emitter.setMaxListeners(0);
  }

  private uploadsPath(jobId: string): string {
    const dir = this.config.get<string>('parser.uploadsDir') ?? 'data/uploads';
    const abs = path.isAbsolute(dir) ? dir : path.resolve(process.cwd(), dir);
    return path.join(abs, `${jobId}.pdf`);
  }

  // Persists the PDF buffer to disk so /retry can re-parse failed days
  // without forcing the client to re-upload. The directory is created
  // lazily; failures here propagate so the caller can surface them.
  async savePdf(jobId: string, buffer: Buffer): Promise<void> {
    const filepath = this.uploadsPath(jobId);
    await fs.mkdir(path.dirname(filepath), { recursive: true });
    await fs.writeFile(filepath, buffer);
  }

  async loadPdf(jobId: string): Promise<Buffer | null> {
    try {
      return await fs.readFile(this.uploadsPath(jobId));
    } catch (err) {
      if ((err as NodeJS.ErrnoException).code === 'ENOENT') return null;
      throw err;
    }
  }

  // Any `queued` or `running` job at startup is an orphan: the previous
  // process held the parse buffer in memory and lost it on exit/reload, so
  // there's nothing left to drive the row to a terminal status. Mark them
  // failed so polling clients stop hammering the GET endpoint forever.
  async onApplicationBootstrap(): Promise<void> {
    const orphans = await this.database.db
      .update(uploadJobs)
      .set({
        status: 'failed',
        errorMessage: 'orphaned by api restart',
        finishedAt: new Date(),
      })
      .where(inArray(uploadJobs.status, ['queued', 'running']))
      .returning({ id: uploadJobs.id });

    if (orphans.length > 0) {
      this.logger.warn({
        msg: 'upload_job.orphans_cleaned',
        count: orphans.length,
        jobIds: orphans.map((o) => o.id),
      });
      // Wake up any in-flight long-poll listeners so they read the new row.
      for (const o of orphans) this.emitter.emit(`done:${o.id}`);
    }
  }

  async create(input: {
    filename: string;
    sizeBytes: number;
    dryRun: boolean;
    requestId: string;
  }): Promise<UploadJob> {
    const row: NewUploadJob = {
      filename: input.filename,
      sizeBytes: input.sizeBytes,
      dryRun: input.dryRun,
      requestId: input.requestId,
      status: 'queued',
    };
    const [created] = await this.database.db
      .insert(uploadJobs)
      .values(row)
      .returning();
    this.logger.info({
      msg: 'upload_job.created',
      jobId: created.id,
      requestId: input.requestId,
      filename: input.filename,
      sizeBytes: input.sizeBytes,
      dryRun: input.dryRun,
    });
    return created;
  }

  async markRunning(id: string): Promise<void> {
    await this.database.db
      .update(uploadJobs)
      .set({ status: 'running', startedAt: new Date() })
      .where(eq(uploadJobs.id, id));
  }

  async markSucceeded(id: string, result: UploadResponseDto): Promise<void> {
    await this.database.db
      .update(uploadJobs)
      .set({
        status: 'succeeded',
        resultPayload: result,
        finishedAt: new Date(),
      })
      .where(eq(uploadJobs.id, id));
    this.emitter.emit(`done:${id}`);
  }

  async markFailed(id: string, error: string): Promise<void> {
    await this.database.db
      .update(uploadJobs)
      .set({
        status: 'failed',
        errorMessage: error,
        finishedAt: new Date(),
      })
      .where(eq(uploadJobs.id, id));
    this.emitter.emit(`done:${id}`);
  }

  // Minimal row for the list page. Computed via jsonb operators on
  // `result_payload` so we can render counts without shipping the full
  // ParsedDocument tree to the browser. Ordering: newest first, capped to
  // `limit` (default 100).
  async listSummaries(
    limit = 100,
  ): Promise<UploadJobSummary[]> {
    const rows = await this.database.db
      .select({
        id: uploadJobs.id,
        filename: uploadJobs.filename,
        status: uploadJobs.status,
        createdAt: uploadJobs.createdAt,
        finishedAt: uploadJobs.finishedAt,
        errorMessage: uploadJobs.errorMessage,
        weekStartsOn: sql<string | null>`${uploadJobs.resultPayload}->'document'->>'week_starts_on'`,
        trackCount: sql<number>`coalesce(jsonb_array_length(${uploadJobs.resultPayload}->'document'->'tracks'), 0)::int`,
        dayCount: sql<number>`coalesce((
          SELECT sum(jsonb_array_length(t->'days'))
          FROM jsonb_array_elements(${uploadJobs.resultPayload}->'document'->'tracks') AS t
        ), 0)::int`,
        warningCount: sql<number>`coalesce(jsonb_array_length(${uploadJobs.resultPayload}->'parse_warnings'), 0)::int`,
        tokensTotal: sql<number>`coalesce((${uploadJobs.resultPayload}->'parse_metrics'->>'tokens_total')::int, 0)`,
      })
      .from(uploadJobs)
      .orderBy(desc(uploadJobs.createdAt))
      .limit(limit);

    return rows.map((r) => ({
      id: r.id,
      source_filename: r.filename,
      status: r.status as UploadJobStatus,
      week_starts_on: r.weekStartsOn,
      track_count: r.trackCount,
      day_count: r.dayCount,
      warning_count: r.warningCount,
      tokens_total: r.tokensTotal,
      uploaded_at: r.createdAt.toISOString(),
      finished_at: r.finishedAt?.toISOString() ?? null,
      error: r.errorMessage,
    }));
  }

  // Detail-page payload. Reads `result_payload` directly — that jsonb already
  // contains the full `UploadResponse` (document tree, warnings, metrics) the
  // synchronous endpoint used to return inline. Once the relational tables
  // become the canonical source for the document tree, this can switch to
  // joining microcycles/days/etc. instead.
  async getDetail(id: string): Promise<UploadJobDetail | null> {
    const job = await this.get(id);
    if (!job) return null;

    type Payload = {
      document?: unknown;
      parse_warnings?: unknown;
      parse_metrics?: unknown;
      dry_run?: unknown;
    };
    const payload = (job.resultPayload ?? null) as Payload | null;
    const document = (payload?.document ?? null) as UploadJobDetail['document'];
    const warnings = (payload?.parse_warnings ?? []) as UploadJobDetail['parse_warnings'];
    const metrics = (payload?.parse_metrics ?? null) as UploadJobDetail['parse_metrics'];
    const dryRunOnly = payload?.dry_run != null && document == null;

    return {
      id: job.id,
      source_filename: job.filename,
      status: job.status as UploadJobStatus,
      uploaded_at: job.createdAt.toISOString(),
      started_at: job.startedAt?.toISOString() ?? null,
      finished_at: job.finishedAt?.toISOString() ?? null,
      error: job.errorMessage ?? null,
      document,
      parse_warnings: warnings,
      parse_metrics: metrics,
      dry_run_only: dryRunOnly,
    };
  }

  async get(id: string): Promise<UploadJob | null> {
    const rows = await this.database.db
      .select()
      .from(uploadJobs)
      .where(eq(uploadJobs.id, id))
      .limit(1);
    return rows[0] ?? null;
  }

  // Resolves when the job becomes terminal OR `timeoutMs` elapses, whichever
  // happens first. Returns the latest row so the caller can decide whether
  // status is now terminal or still running. Re-fetching from the DB after
  // the wake (rather than passing the row through the emitter) keeps the DB
  // as the single source of truth — the emitter is a hint, not a payload.
  async waitForCompletion(
    id: string,
    timeoutMs: number,
  ): Promise<UploadJob | null> {
    const initial = await this.get(id);
    if (!initial) return null;
    if (isTerminal(initial.status as UploadJobStatus)) return initial;

    await new Promise<void>((resolve) => {
      const event = `done:${id}`;
      const onDone = () => {
        clearTimeout(timer);
        this.emitter.off(event, onDone);
        resolve();
      };
      const timer = setTimeout(() => {
        this.emitter.off(event, onDone);
        resolve();
      }, timeoutMs);
      this.emitter.once(event, onDone);
    });

    return this.get(id);
  }
}

function isTerminal(status: UploadJobStatus): boolean {
  return status === 'succeeded' || status === 'failed';
}

export interface UploadJobSummary {
  id: string;
  source_filename: string;
  status: UploadJobStatus;
  week_starts_on: string | null;
  track_count: number;
  day_count: number;
  warning_count: number;
  tokens_total: number;
  uploaded_at: string;
  finished_at: string | null;
  error: string | null;
}

// Same shape as `@fbb/types` TrainingWeekDetail — typed loosely here to avoid
// a workspace import cycle through the controller. The frontend type is the
// authoritative wire shape.
export interface UploadJobDetail {
  id: string;
  source_filename: string;
  status: UploadJobStatus;
  uploaded_at: string;
  started_at: string | null;
  finished_at: string | null;
  error: string | null;
  document: unknown;
  parse_warnings: unknown[];
  parse_metrics: unknown;
  dry_run_only: boolean;
}
