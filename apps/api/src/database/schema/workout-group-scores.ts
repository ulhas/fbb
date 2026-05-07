import { sql } from 'drizzle-orm';
import {
  check,
  integer,
  pgTable,
  text,
  unique,
  uuid,
} from 'drizzle-orm/pg-core';

import { PRESCRIPTION_MODES, inEnum } from './enums';
import { workoutSessions } from './workout-sessions';

// Group-level score: AMRAP rounds + partial reps, for_time finish, density
// total reps, etc. One row per group the user actually engaged with — groups
// the user skipped have no row. UNIQUE on (session, section, group) enforces
// one score per group; the iOS client overwrites on POST upsert.
export const workoutGroupScores = pgTable(
  'workout_group_scores',
  {
    id: uuid('id').primaryKey().default(sql`uuidv7()`),
    sessionId: uuid('session_id')
      .notNull()
      .references(() => workoutSessions.id, { onDelete: 'cascade' }),
    sectionPosition: integer('section_position').notNull(),
    groupPosition: integer('group_position').notNull(),
    prescriptionMode: text('prescription_mode').notNull(),
    rounds: integer('rounds'),
    partialReps: integer('partial_reps'),
    finishSeconds: integer('finish_seconds'),
    totalReps: integer('total_reps'),
  },
  (t) => [
    unique('workout_group_scores_session_group_unique').on(
      t.sessionId,
      t.sectionPosition,
      t.groupPosition,
    ),
    check(
      'workout_group_scores_prescription_mode_check',
      inEnum(t.prescriptionMode, PRESCRIPTION_MODES),
    ),
    check(
      'workout_group_scores_rounds_check',
      sql`${t.rounds} is null or ${t.rounds} >= 0`,
    ),
    check(
      'workout_group_scores_partial_reps_check',
      sql`${t.partialReps} is null or ${t.partialReps} >= 0`,
    ),
    check(
      'workout_group_scores_finish_seconds_check',
      sql`${t.finishSeconds} is null or ${t.finishSeconds} >= 0`,
    ),
    check(
      'workout_group_scores_total_reps_check',
      sql`${t.totalReps} is null or ${t.totalReps} >= 0`,
    ),
  ],
);

export type WorkoutGroupScore = typeof workoutGroupScores.$inferSelect;
export type NewWorkoutGroupScore = typeof workoutGroupScores.$inferInsert;
