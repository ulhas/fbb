import { sql } from 'drizzle-orm';
import {
  check,
  index,
  integer,
  numeric,
  pgTable,
  text,
  timestamp,
  uuid,
} from 'drizzle-orm/pg-core';

import { workoutSessions } from './workout-sessions';

// Per-set completion log. Each completed (or skipped/partial) set is one
// row. Linkage to the prescribed plan is by *position tuple* — not FK to
// `prescribed_sets` — so the log survives plan re-parses and renames. If
// a session is later replayed against the canonical plan, the tuple
// resolves the prescribed set deterministically via `(section_position,
// group_position, exercise_position, set_position)`.
export const workoutSetLogs = pgTable(
  'workout_set_logs',
  {
    id: uuid('id').primaryKey().default(sql`uuidv7()`),
    sessionId: uuid('session_id')
      .notNull()
      .references(() => workoutSessions.id, { onDelete: 'cascade' }),
    sectionPosition: integer('section_position').notNull(),
    groupPosition: integer('group_position').notNull(),
    exercisePosition: integer('exercise_position').notNull(),
    setPosition: integer('set_position').notNull(),
    perSide: text('per_side'),
    outcome: text('outcome').notNull(),
    actualReps: integer('actual_reps'),
    actualWeightKg: numeric('actual_weight_kg', { precision: 7, scale: 2 }),
    actualRpe: numeric('actual_rpe', { precision: 3, scale: 1 }),
    restTakenSeconds: integer('rest_taken_seconds'),
    completedAt: timestamp('completed_at', { withTimezone: true }).notNull(),
  },
  (t) => [
    check(
      'workout_set_logs_outcome_check',
      sql`${t.outcome} in ('completed', 'skipped', 'partial')`,
    ),
    check(
      'workout_set_logs_per_side_check',
      sql`${t.perSide} is null or ${t.perSide} in ('first', 'second', 'done')`,
    ),
    check(
      'workout_set_logs_actual_reps_check',
      sql`${t.actualReps} is null or ${t.actualReps} >= 0`,
    ),
    check(
      'workout_set_logs_actual_weight_check',
      sql`${t.actualWeightKg} is null or ${t.actualWeightKg} >= 0`,
    ),
    check(
      'workout_set_logs_actual_rpe_check',
      sql`${t.actualRpe} is null or (${t.actualRpe} >= 1 and ${t.actualRpe} <= 10)`,
    ),
    check(
      'workout_set_logs_rest_taken_check',
      sql`${t.restTakenSeconds} is null or ${t.restTakenSeconds} >= 0`,
    ),
    index('workout_set_logs_session_idx').on(t.sessionId),
  ],
);

export type WorkoutSetLog = typeof workoutSetLogs.$inferSelect;
export type NewWorkoutSetLog = typeof workoutSetLogs.$inferInsert;
