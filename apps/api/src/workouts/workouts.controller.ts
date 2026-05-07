import {
  BadRequestException,
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';

import { CurrentUser } from '../auth/current-user.decorator';
import { CurrentUserGuard } from '../auth/current-user.guard';
import type { User } from '../database/schema/users';
import { createWorkoutSessionSchema } from './dto/create-workout-session.dto';
import type {
  WorkoutSessionRowDto,
  WorkoutSessionSummaryRow,
} from './dto/workout-session-row.dto';
import { WorkoutsService } from './workouts.service';

const ISO_DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Workout session ingest + history. Sessions are user-scoped — the guard
// resolves the caller from `X-User-Id`, every endpoint filters by that
// user's id and never trusts the client to scope its own queries.
@Controller('workouts/sessions')
@UseGuards(CurrentUserGuard)
export class WorkoutsController {
  constructor(private readonly workouts: WorkoutsService) {}

  // Idempotent on `client_session_id`. iOS POSTs the entire session
  // (session + set logs + group scores) once on workout end; a retry from
  // a flaky network reuses the same id and returns the same row. Always
  // 200 — we don't distinguish create-vs-update for the iOS client.
  @Post()
  @HttpCode(HttpStatus.OK)
  async upsert(
    @CurrentUser() user: User,
    @Body() body: unknown,
  ): Promise<WorkoutSessionRowDto> {
    const parsed = createWorkoutSessionSchema.safeParse(body);
    if (!parsed.success) {
      throw new BadRequestException({
        message: 'Invalid workout session payload',
        issues: parsed.error.issues,
      });
    }
    return this.workouts.upsertSession(user.id, parsed.data);
  }

  // Lightweight summary list. `from` and `to` are optional ISO dates that
  // bound `scheduled_on`. Newest started_at first.
  @Get()
  async list(
    @CurrentUser() user: User,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ): Promise<WorkoutSessionSummaryRow[]> {
    if (from && !ISO_DATE_RE.test(from)) {
      throw new BadRequestException(
        `from must be an ISO date (YYYY-MM-DD), got "${from}"`,
      );
    }
    if (to && !ISO_DATE_RE.test(to)) {
      throw new BadRequestException(
        `to must be an ISO date (YYYY-MM-DD), got "${to}"`,
      );
    }
    return this.workouts.listForUser(user.id, { from, to });
  }

  @Get(':id')
  async detail(
    @CurrentUser() user: User,
    @Param('id') id: string,
  ): Promise<WorkoutSessionRowDto> {
    if (!UUID_RE.test(id)) {
      throw new BadRequestException(`session id must be a UUID, got "${id}"`);
    }
    return this.workouts.getDetail(user.id, id);
  }
}
