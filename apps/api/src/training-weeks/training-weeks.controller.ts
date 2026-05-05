import {
  BadRequestException,
  Controller,
  Get,
  NotFoundException,
  Param,
  UseGuards,
} from '@nestjs/common';

import { AdminGuard } from './admin.guard';
import {
  TrainingWeeksReadService,
  type TrainingWeekDetailRow,
  type TrainingWeekSummaryRow,
} from './services/training-weeks-read.service';

const ISO_DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

// Reads training-week data straight from the relational tables (microcycles
// and below). Upload-job concerns (POST upload, status long-poll, retry) live
// at /upload-jobs — this controller intentionally has nothing to say about
// jobs.
@Controller('training-weeks')
@UseGuards(AdminGuard)
export class TrainingWeeksController {
  constructor(private readonly reads: TrainingWeeksReadService) {}

  // List of weeks, newest first. One row per `week_starts_on` aggregated
  // across all tracks for that week.
  @Get()
  async list(): Promise<TrainingWeekSummaryRow[]> {
    return this.reads.listWeeks();
  }

  // Full detail for one week — every track, day, section, group, exercise,
  // set. Path param is the ISO date `week_starts_on` (e.g., 2026-04-20).
  @Get(':weekStartsOn')
  async detail(
    @Param('weekStartsOn') weekStartsOn: string,
  ): Promise<TrainingWeekDetailRow> {
    if (!ISO_DATE_RE.test(weekStartsOn)) {
      throw new BadRequestException(
        `weekStartsOn must be an ISO date (YYYY-MM-DD), got "${weekStartsOn}"`,
      );
    }
    const detail = await this.reads.getWeek(weekStartsOn);
    if (!detail) {
      throw new NotFoundException(
        `no training week persisted for week_starts_on=${weekStartsOn}`,
      );
    }
    return detail;
  }
}
