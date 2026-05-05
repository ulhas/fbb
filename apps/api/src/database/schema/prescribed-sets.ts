import { sql } from 'drizzle-orm';
import {
  boolean,
  check,
  index,
  integer,
  jsonb,
  numeric,
  pgTable,
  text,
  timestamp,
  unique,
  uuid,
} from 'drizzle-orm/pg-core';

import { REPS_KINDS, SET_KINDS, inEnum } from './enums';
import { prescribedExercises } from './prescribed-exercises';

export const prescribedSets = pgTable(
  'prescribed_sets',
  {
    id: uuid('id').primaryKey().default(sql`uuidv7()`),
    exerciseId: uuid('exercise_id')
      .notNull()
      .references(() => prescribedExercises.id, { onDelete: 'cascade' }),
    position: integer('position').notNull(),
    setKind: text('set_kind').notNull().default('working'),
    repsKind: text('reps_kind').notNull().default('fixed'),
    repsMin: integer('reps_min'),
    repsMax: integer('reps_max'),
    repsText: text('reps_text'),
    durationSecondsMin: integer('duration_seconds_min'),
    durationSecondsMax: integer('duration_seconds_max'),
    perSide: boolean('per_side').notNull().default(false),
    tempo: text('tempo'),
    rpeMin: numeric('rpe_min', { precision: 3, scale: 1 }),
    rpeMax: numeric('rpe_max', { precision: 3, scale: 1 }),
    rpeText: text('rpe_text'),
    weightRef: jsonb('weight_ref').notNull().default(sql`'{}'::jsonb`),
    restAfterSecondsMin: integer('rest_after_seconds_min'),
    restAfterSecondsMax: integer('rest_after_seconds_max'),
    restAfterText: text('rest_after_text'),
    hasDropSet: boolean('has_drop_set').notNull().default(false),
    dropSetDescriptor: jsonb('drop_set_descriptor'),
    notes: text('notes'),
    cmsSourceId: text('cms_source_id'),
    cmsRevision: text('cms_revision'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    unique('prescribed_sets_exercise_position_unique').on(t.exerciseId, t.position),
    check('prescribed_sets_set_kind_check', inEnum(t.setKind, SET_KINDS)),
    check('prescribed_sets_reps_kind_check', inEnum(t.repsKind, REPS_KINDS)),
    check(
      'prescribed_sets_reps_min_check',
      sql`${t.repsMin} is null or ${t.repsMin} > 0`,
    ),
    check(
      'prescribed_sets_reps_max_check',
      sql`${t.repsMax} is null or ${t.repsMax} >= coalesce(${t.repsMin}, 0)`,
    ),
    check(
      'prescribed_sets_duration_min_check',
      sql`${t.durationSecondsMin} is null or ${t.durationSecondsMin} > 0`,
    ),
    check(
      'prescribed_sets_duration_max_check',
      sql`${t.durationSecondsMax} is null or ${t.durationSecondsMax} >= coalesce(${t.durationSecondsMin}, 0)`,
    ),
    check(
      'prescribed_sets_tempo_check',
      sql`${t.tempo} is null or (length(${t.tempo}) = 4 and ${t.tempo} ~ '^[0-9XA]{4}$')`,
    ),
    check(
      'prescribed_sets_rpe_min_check',
      sql`${t.rpeMin} is null or (${t.rpeMin} >= 1 and ${t.rpeMin} <= 10)`,
    ),
    check(
      'prescribed_sets_rpe_max_check',
      sql`${t.rpeMax} is null or (${t.rpeMax} >= coalesce(${t.rpeMin}, 0) and ${t.rpeMax} <= 10)`,
    ),
    check(
      'prescribed_sets_rest_max_check',
      sql`${t.restAfterSecondsMax} is null or ${t.restAfterSecondsMax} >= coalesce(${t.restAfterSecondsMin}, 0)`,
    ),
    index('prescribed_sets_exercise_id_idx').on(t.exerciseId),
    index('prescribed_sets_weight_ref_gin').using(
      'gin',
      sql`weight_ref jsonb_path_ops`,
    ),
  ],
);

export type PrescribedSet = typeof prescribedSets.$inferSelect;
export type NewPrescribedSet = typeof prescribedSets.$inferInsert;
