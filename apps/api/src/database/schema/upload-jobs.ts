import { sql } from 'drizzle-orm';
import {
  bigint,
  boolean,
  check,
  index,
  jsonb,
  pgTable,
  text,
  timestamp,
  uuid,
} from 'drizzle-orm/pg-core';

import { inEnum } from './enums';

export const UPLOAD_JOB_STATUSES = [
  'queued',
  'running',
  'succeeded',
  'failed',
] as const;
export type UploadJobStatus = (typeof UPLOAD_JOB_STATUSES)[number];

// Tracks the lifecycle of a PDF upload while it parses asynchronously. The
// admin client polls `GET /upload-jobs/:id/status` until status is terminal
// (succeeded | failed) and reads `result_payload` for the parsed document.
export const uploadJobs = pgTable(
  'upload_jobs',
  {
    id: uuid('id').primaryKey().default(sql`uuidv7()`),
    status: text('status').notNull().default('queued'),
    filename: text('filename').notNull(),
    sizeBytes: bigint('size_bytes', { mode: 'number' }).notNull(),
    dryRun: boolean('dry_run').notNull().default(false),
    requestId: text('request_id').notNull(),
    // Full UploadResponseDto on success — same shape the synchronous endpoint
    // used to return inline. Stored as jsonb so the polling endpoint can
    // stream it back without re-running the parser.
    resultPayload: jsonb('result_payload'),
    errorMessage: text('error_message'),
    createdAt: timestamp('created_at', { withTimezone: true })
      .notNull()
      .defaultNow(),
    startedAt: timestamp('started_at', { withTimezone: true }),
    finishedAt: timestamp('finished_at', { withTimezone: true }),
  },
  (t) => [
    check('upload_jobs_status_check', inEnum(t.status, UPLOAD_JOB_STATUSES)),
    index('upload_jobs_status_idx').on(t.status, t.createdAt),
  ],
);

export type UploadJob = typeof uploadJobs.$inferSelect;
export type NewUploadJob = typeof uploadJobs.$inferInsert;
