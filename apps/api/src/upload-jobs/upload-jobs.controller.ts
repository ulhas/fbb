import {
  BadRequestException,
  Body,
  ConflictException,
  Controller,
  GoneException,
  Get,
  HttpCode,
  HttpStatus,
  NotFoundException,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  Req,
  UnsupportedMediaTypeException,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Request } from 'express';
import { randomUUID } from 'node:crypto';

import { AdminGuard } from '../training-weeks/admin.guard';
import type { UploadResponseDto } from '../training-weeks/dto/parse-result.dto';
import type { UploadJobStatus } from '../database/schema/upload-jobs';
import { TrainingWeeksService } from '../training-weeks/services/training-weeks.service';
import {
  type UploadJobDetail,
  type UploadJobSummary,
  UploadJobsService,
} from '../training-weeks/services/upload-jobs.service';

const MAX_UPLOAD_BYTES = 10 * 1024 * 1024;

// Cap below typical reverse-proxy idle timeouts (nginx default 60s, AWS ALB
// 60s) so the connection stays in the proxy's "alive" window. Frontend reopens
// the poll immediately on response.
const LONG_POLL_DEFAULT_MS = 25_000;
const LONG_POLL_MAX_MS = 55_000;

interface UploadAcceptedDto {
  job_id: string;
  status: UploadJobStatus;
}

interface UploadStatusDto {
  job_id: string;
  status: UploadJobStatus;
  result: UploadResponseDto | null;
  error: string | null;
  created_at: string;
  started_at: string | null;
  finished_at: string | null;
}

// Owns everything about upload jobs: creation (POST), status long-poll, list,
// retry-failed-days. /training-weeks reads the persisted training-week data;
// this controller owns the workflow that *creates* that data.
@Controller('upload-jobs')
@UseGuards(AdminGuard)
export class UploadJobsController {
  constructor(
    private readonly service: TrainingWeeksService,
    private readonly jobs: UploadJobsService,
  ) {}

  @Get()
  async list(): Promise<UploadJobSummary[]> {
    return this.jobs.listSummaries();
  }

  // Full detail. For non-`succeeded` jobs `document` is null and the client
  // can show a status hint; we still return 200 (not 404) so callers can render
  // "still parsing" / "failed" instead of an error page.
  @Get(':id')
  async detail(
    @Param('id', new ParseUUIDPipe()) id: string,
  ): Promise<UploadJobDetail> {
    const detail = await this.jobs.getDetail(id);
    if (!detail) {
      throw new NotFoundException(`upload job ${id} not found`);
    }
    return detail;
  }

  // Re-runs only the days that failed last time. Returns 202 and surfaces the
  // count of days the retry will attempt; the client long-polls the existing
  // status endpoint to track progress (status flips back to 'running' for the
  // duration). Errors:
  // - 404 if the job doesn't exist
  // - 409 if the job is still queued/running from the original parse
  // - 410 if the original PDF is no longer on disk (re-upload required)
  //
  // Body is optional. When `day_locators` is provided, the retry runs against
  // exactly those `track_code/YYYY-MM-DD` pairs instead of auto-deriving the
  // failed-locator set from existing parse warnings. The admin UI uses this
  // to reparse days the LLM returned empty for (no warning recorded).
  @Post(':id/retry')
  @HttpCode(HttpStatus.ACCEPTED)
  async retry(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() body: { day_locators?: string[] } | undefined,
  ): Promise<{ job_id: string; failed_day_count: number }> {
    const dayLocators = body?.day_locators;
    if (dayLocators !== undefined) {
      if (!Array.isArray(dayLocators) || dayLocators.length === 0) {
        throw new BadRequestException(
          'day_locators must be a non-empty array of "track_code/YYYY-MM-DD" strings',
        );
      }
    }

    try {
      const { jobId, failedDayCount } = await this.service.retry(
        id,
        dayLocators ? { dayLocators } : undefined,
      );
      return { job_id: jobId, failed_day_count: failedDayCount };
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      if (message.includes('invalid day locator')) {
        throw new BadRequestException(message);
      }
      if (message.includes('not found')) throw new NotFoundException(message);
      if (message.includes('still')) throw new ConflictException(message);
      if (message.includes('re-upload')) throw new GoneException(message);
      throw err;
    }
  }

  @Post()
  @HttpCode(HttpStatus.ACCEPTED)
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: MAX_UPLOAD_BYTES },
      fileFilter: (_req, file, cb) => {
        if (file.mimetype !== 'application/pdf') {
          return cb(
            new UnsupportedMediaTypeException(
              `expected application/pdf, got ${file.mimetype}`,
            ),
            false,
          );
        }
        cb(null, true);
      },
    }),
  )
  async create(
    @UploadedFile() file: Express.Multer.File,
    @Body('dry_run') dryRunRaw: string | undefined,
    @Req() req: Request,
  ): Promise<UploadAcceptedDto> {
    if (!file) {
      throw new BadRequestException('field "file" is required (multipart/form-data)');
    }
    // Magic-bytes check — multer mimetype is client-asserted.
    if (file.buffer.subarray(0, 5).toString('utf8') !== '%PDF-') {
      throw new UnsupportedMediaTypeException(
        'file does not look like a PDF (missing %PDF- magic header)',
      );
    }

    const dryRun = dryRunRaw === 'true' || dryRunRaw === '1';
    const requestId = req.requestId ?? randomUUID();

    const { jobId } = await this.service.enqueue({
      filename: file.originalname,
      buffer: file.buffer,
      dryRun,
      requestId,
    });

    return { job_id: jobId, status: 'queued' };
  }

  // Long-poll: holds the connection until the job hits a terminal status or
  // `wait_ms` elapses. Frontend reopens immediately on response, so a still-
  // running job just gets another window. `wait_ms=0` returns the current
  // state without blocking — useful for an initial sync read.
  @Get(':id/status')
  async status(
    @Param('id', new ParseUUIDPipe()) jobId: string,
    @Query('wait_ms') waitMsRaw: string | undefined,
  ): Promise<UploadStatusDto> {
    const requestedWait =
      waitMsRaw === undefined ? LONG_POLL_DEFAULT_MS : parseInt(waitMsRaw, 10);
    if (Number.isNaN(requestedWait) || requestedWait < 0) {
      throw new BadRequestException('wait_ms must be a non-negative integer');
    }
    const waitMs = Math.min(requestedWait, LONG_POLL_MAX_MS);

    const job =
      waitMs === 0
        ? await this.jobs.get(jobId)
        : await this.jobs.waitForCompletion(jobId, waitMs);

    if (!job) {
      throw new NotFoundException(`upload job ${jobId} not found`);
    }

    return {
      job_id: job.id,
      status: job.status as UploadJobStatus,
      result: (job.resultPayload as UploadResponseDto | null) ?? null,
      error: job.errorMessage ?? null,
      created_at: job.createdAt.toISOString(),
      started_at: job.startedAt?.toISOString() ?? null,
      finished_at: job.finishedAt?.toISOString() ?? null,
    };
  }
}
