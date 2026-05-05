import { sql } from 'drizzle-orm';
import {
  boolean,
  check,
  foreignKey,
  index,
  integer,
  pgTable,
  text,
  timestamp,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';

import { PER_SIDE_STARTS, inEnum } from './enums';
import { movements } from './movements';
import { prescribedGroups } from './prescribed-groups';

export const prescribedExercises = pgTable(
  'prescribed_exercises',
  {
    id: uuid('id').primaryKey().default(sql`uuidv7()`),
    groupId: uuid('group_id')
      .notNull()
      .references(() => prescribedGroups.id, { onDelete: 'cascade' }),
    position: integer('position').notNull(),
    movementId: uuid('movement_id')
      .notNull()
      .references(() => movements.id, { onDelete: 'restrict' }),
    alternateOfExerciseId: uuid('alternate_of_exercise_id'),
    chainedIntoNext: boolean('chained_into_next').notNull().default(false),
    restAfterSecondsMin: integer('rest_after_seconds_min'),
    restAfterSecondsMax: integer('rest_after_seconds_max'),
    restAfterText: text('rest_after_text'),
    isUnilateral: boolean('is_unilateral').notNull().default(false),
    perSideStarts: text('per_side_starts'),
    notes: text('notes'),
    cmsSourceId: text('cms_source_id'),
    cmsRevision: text('cms_revision'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    foreignKey({
      name: 'prescribed_exercises_alternate_fk',
      columns: [t.alternateOfExerciseId],
      foreignColumns: [t.id],
    }).onDelete('cascade'),
    // Schema-validity Pass 3 #1: split the original NULL-distinct unique into a
    // partial-unique pair so two primary movements at the same (group, position)
    // are correctly rejected by the index, regardless of Postgres NULL semantics.
    uniqueIndex('prescribed_exercises_primary_unique')
      .on(t.groupId, t.position)
      .where(sql`alternate_of_exercise_id is null`),
    uniqueIndex('prescribed_exercises_alternate_unique')
      .on(t.groupId, t.position, t.alternateOfExerciseId)
      .where(sql`alternate_of_exercise_id is not null`),
    check(
      'prescribed_exercises_self_ref_check',
      sql`${t.alternateOfExerciseId} is null or ${t.alternateOfExerciseId} <> ${t.id}`,
    ),
    check(
      'prescribed_exercises_per_side_check',
      sql`${t.perSideStarts} is null or ${inEnum(t.perSideStarts, PER_SIDE_STARTS)}`,
    ),
    check(
      'prescribed_exercises_rest_max_check',
      sql`${t.restAfterSecondsMax} is null or ${t.restAfterSecondsMax} >= coalesce(${t.restAfterSecondsMin}, 0)`,
    ),
    index('prescribed_exercises_group_id_idx').on(t.groupId),
    index('prescribed_exercises_movement_id_idx').on(t.movementId),
    index('prescribed_exercises_alternate_idx')
      .on(t.alternateOfExerciseId)
      .where(sql`${t.alternateOfExerciseId} is not null`),
  ],
);

export type PrescribedExercise = typeof prescribedExercises.$inferSelect;
export type NewPrescribedExercise = typeof prescribedExercises.$inferInsert;
