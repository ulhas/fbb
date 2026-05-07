import {
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { and, asc, desc, eq, gte, lte, sql } from 'drizzle-orm';
import { WINSTON_MODULE_PROVIDER } from 'nest-winston';
import type { Logger } from 'winston';

import { DatabaseService } from '../database/database.service';
import { workoutGroupScores } from '../database/schema/workout-group-scores';
import { workoutSetLogs } from '../database/schema/workout-set-logs';
import { workoutSessions } from '../database/schema/workout-sessions';
import type { CreateWorkoutSessionDto } from './dto/create-workout-session.dto';
import type {
  WorkoutSessionRowDto,
  WorkoutSessionSummaryRow,
} from './dto/workout-session-row.dto';

@Injectable()
export class WorkoutsService {
  constructor(
    private readonly database: DatabaseService,
    @Inject(WINSTON_MODULE_PROVIDER) private readonly logger: Logger,
  ) {}

  // Idempotent upsert keyed on (user_id, client_session_id). A retry from a
  // flaky network reuses the same client-side UUID and gets the same row
  // back — set logs and group scores are wholesale-replaced inside the
  // transaction so the most recent payload wins. Returns the persisted
  // session in the same shape the GET detail endpoint emits.
  async upsertSession(
    userId: string,
    payload: CreateWorkoutSessionDto,
  ): Promise<WorkoutSessionRowDto> {
    return this.database.db.transaction(async (tx) => {
      // Look up an existing row first; cross-user reuse of a client_session_id
      // is rejected loudly (it would only happen if a device hands its keychain
      // to another account, which is a security signal).
      const [existing] = await tx
        .select()
        .from(workoutSessions)
        .where(eq(workoutSessions.clientSessionId, payload.client_session_id))
        .limit(1);

      if (existing && existing.userId !== userId) {
        this.logger.warn({
          msg: 'workouts.upsert.client_session_id_user_mismatch',
          clientSessionId: payload.client_session_id,
          ownerUserId: existing.userId,
          callerUserId: userId,
        });
        throw new ForbiddenException(
          'client_session_id belongs to a different user',
        );
      }

      let sessionId: string;
      if (existing) {
        await tx
          .update(workoutSessions)
          .set({
            trackCode: payload.track_code,
            scheduledOn: payload.scheduled_on,
            dayId: payload.day_id ?? null,
            startedAt: new Date(payload.started_at),
            endedAt: payload.ended_at ? new Date(payload.ended_at) : null,
            totalElapsedSeconds: payload.total_elapsed_seconds,
            status: payload.status,
            notes: payload.notes ?? null,
            weightUnit: payload.weight_unit,
            updatedAt: sql`now()`,
          })
          .where(eq(workoutSessions.id, existing.id));
        sessionId = existing.id;

        // Wholesale replace child rows. Cheaper and simpler than diffing —
        // a typical session has < 100 set logs.
        await tx
          .delete(workoutSetLogs)
          .where(eq(workoutSetLogs.sessionId, sessionId));
        await tx
          .delete(workoutGroupScores)
          .where(eq(workoutGroupScores.sessionId, sessionId));
      } else {
        const [inserted] = await tx
          .insert(workoutSessions)
          .values({
            userId,
            trackCode: payload.track_code,
            scheduledOn: payload.scheduled_on,
            dayId: payload.day_id ?? null,
            clientSessionId: payload.client_session_id,
            startedAt: new Date(payload.started_at),
            endedAt: payload.ended_at ? new Date(payload.ended_at) : null,
            totalElapsedSeconds: payload.total_elapsed_seconds,
            status: payload.status,
            notes: payload.notes ?? null,
            weightUnit: payload.weight_unit,
          })
          .returning({ id: workoutSessions.id });
        sessionId = inserted.id;
      }

      if (payload.set_logs.length > 0) {
        await tx.insert(workoutSetLogs).values(
          payload.set_logs.map((log) => ({
            sessionId,
            sectionPosition: log.section_position,
            groupPosition: log.group_position,
            exercisePosition: log.exercise_position,
            setPosition: log.set_position,
            perSide: log.per_side ?? null,
            outcome: log.outcome,
            actualReps: log.actual_reps ?? null,
            actualWeightKg:
              log.actual_weight_kg != null
                ? String(log.actual_weight_kg)
                : null,
            actualRpe:
              log.actual_rpe != null ? String(log.actual_rpe) : null,
            restTakenSeconds: log.rest_taken_seconds ?? null,
            completedAt: new Date(log.completed_at),
          })),
        );
      }

      if (payload.group_scores.length > 0) {
        await tx.insert(workoutGroupScores).values(
          payload.group_scores.map((score) => ({
            sessionId,
            sectionPosition: score.section_position,
            groupPosition: score.group_position,
            prescriptionMode: score.prescription_mode,
            rounds: score.rounds ?? null,
            partialReps: score.partial_reps ?? null,
            finishSeconds: score.finish_seconds ?? null,
            totalReps: score.total_reps ?? null,
          })),
        );
      }

      return this.loadDetailWithinTx(tx, sessionId);
    });
  }

  async listForUser(
    userId: string,
    range: { from?: string; to?: string },
  ): Promise<WorkoutSessionSummaryRow[]> {
    const conditions = [eq(workoutSessions.userId, userId)];
    if (range.from) {
      conditions.push(gte(workoutSessions.scheduledOn, range.from));
    }
    if (range.to) {
      conditions.push(lte(workoutSessions.scheduledOn, range.to));
    }

    const rows = await this.database.db
      .select({
        id: workoutSessions.id,
        trackCode: workoutSessions.trackCode,
        scheduledOn: workoutSessions.scheduledOn,
        startedAt: workoutSessions.startedAt,
        endedAt: workoutSessions.endedAt,
        totalElapsedSeconds: workoutSessions.totalElapsedSeconds,
        status: workoutSessions.status,
      })
      .from(workoutSessions)
      .where(and(...conditions))
      .orderBy(desc(workoutSessions.startedAt));

    return rows.map((r) => ({
      id: r.id,
      track_code: r.trackCode,
      scheduled_on: r.scheduledOn,
      started_at: r.startedAt.toISOString(),
      ended_at: r.endedAt ? r.endedAt.toISOString() : null,
      total_elapsed_seconds: r.totalElapsedSeconds,
      status: r.status as 'completed' | 'abandoned',
    }));
  }

  async getDetail(
    userId: string,
    sessionId: string,
  ): Promise<WorkoutSessionRowDto> {
    const [session] = await this.database.db
      .select()
      .from(workoutSessions)
      .where(eq(workoutSessions.id, sessionId))
      .limit(1);

    if (!session) {
      throw new NotFoundException(`workout session ${sessionId} not found`);
    }
    if (session.userId !== userId) {
      // Treat as not-found to avoid leaking ownership.
      throw new NotFoundException(`workout session ${sessionId} not found`);
    }

    return this.loadDetailWithinTx(this.database.db, sessionId);
  }

  // Shared loader used after both upsert and direct GET. Accepts either a
  // transaction handle or the top-level db; both implement the select API.
  private async loadDetailWithinTx(
    db: DatabaseService['db'],
    sessionId: string,
  ): Promise<WorkoutSessionRowDto> {
    const [session] = await db
      .select()
      .from(workoutSessions)
      .where(eq(workoutSessions.id, sessionId))
      .limit(1);

    const setLogs = await db
      .select()
      .from(workoutSetLogs)
      .where(eq(workoutSetLogs.sessionId, sessionId))
      .orderBy(
        asc(workoutSetLogs.sectionPosition),
        asc(workoutSetLogs.groupPosition),
        asc(workoutSetLogs.exercisePosition),
        asc(workoutSetLogs.setPosition),
      );

    const groupScores = await db
      .select()
      .from(workoutGroupScores)
      .where(eq(workoutGroupScores.sessionId, sessionId))
      .orderBy(
        asc(workoutGroupScores.sectionPosition),
        asc(workoutGroupScores.groupPosition),
      );

    return {
      id: session.id,
      client_session_id: session.clientSessionId,
      track_code: session.trackCode,
      scheduled_on: session.scheduledOn,
      day_id: session.dayId,
      started_at: session.startedAt.toISOString(),
      ended_at: session.endedAt ? session.endedAt.toISOString() : null,
      total_elapsed_seconds: session.totalElapsedSeconds,
      status: session.status as 'completed' | 'abandoned',
      notes: session.notes,
      weight_unit: session.weightUnit as 'kg' | 'lb',
      set_logs: setLogs.map((log) => ({
        section_position: log.sectionPosition,
        group_position: log.groupPosition,
        exercise_position: log.exercisePosition,
        set_position: log.setPosition,
        per_side: (log.perSide as 'first' | 'second' | 'done' | null) ?? null,
        outcome: log.outcome as 'completed' | 'skipped' | 'partial',
        actual_reps: log.actualReps,
        actual_weight_kg:
          log.actualWeightKg != null ? Number(log.actualWeightKg) : null,
        actual_rpe: log.actualRpe != null ? Number(log.actualRpe) : null,
        rest_taken_seconds: log.restTakenSeconds,
        completed_at: log.completedAt.toISOString(),
      })),
      group_scores: groupScores.map((score) => ({
        section_position: score.sectionPosition,
        group_position: score.groupPosition,
        prescription_mode: score.prescriptionMode as
          | 'straight_sets'
          | 'every_x_minutes'
          | 'emom'
          | 'e2mom'
          | 'e3mom'
          | 'amrap'
          | 'for_time'
          | 'tabata'
          | 'density'
          | 'rounds'
          | 'interval_pyramid'
          | 'continuous_effort'
          | 'free',
        rounds: score.rounds,
        partial_reps: score.partialReps,
        finish_seconds: score.finishSeconds,
        total_reps: score.totalReps,
      })),
      created_at: session.createdAt.toISOString(),
      updated_at: session.updatedAt.toISOString(),
    };
  }
}
