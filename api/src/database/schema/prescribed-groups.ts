import { sql } from 'drizzle-orm';
import {
  boolean,
  check,
  index,
  integer,
  jsonb,
  pgTable,
  text,
  timestamp,
  unique,
  uuid,
} from 'drizzle-orm/pg-core';

import { SCORING_KINDS, inEnum } from './enums';
import { sections } from './sections';

export const prescribedGroups = pgTable(
  'prescribed_groups',
  {
    id: uuid('id').primaryKey().default(sql`uuid_generate_v7()`),
    sectionId: uuid('section_id')
      .notNull()
      .references(() => sections.id, { onDelete: 'cascade' }),
    position: integer('position').notNull(),
    roundCountMin: integer('round_count_min'),
    roundCountMax: integer('round_count_max'),
    intervalSeconds: integer('interval_seconds'),
    capSeconds: integer('cap_seconds'),
    restBetweenRoundsSecondsMin: integer('rest_between_rounds_seconds_min'),
    restBetweenRoundsSecondsMax: integer('rest_between_rounds_seconds_max'),
    restBetweenRoundsText: text('rest_between_rounds_text'),
    loadingNote: text('loading_note'),
    effortNote: text('effort_note'),
    shortOnTimeRemove: boolean('short_on_time_remove').notNull().default(false),
    scoring: text('scoring'),
    metadata: jsonb('metadata').notNull().default(sql`'{}'::jsonb`),
    cmsSourceId: text('cms_source_id'),
    cmsRevision: text('cms_revision'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    unique('prescribed_groups_section_position_unique').on(t.sectionId, t.position),
    check(
      'prescribed_groups_round_min_check',
      sql`${t.roundCountMin} is null or ${t.roundCountMin} > 0`,
    ),
    check(
      'prescribed_groups_round_max_check',
      sql`${t.roundCountMax} is null or ${t.roundCountMax} >= coalesce(${t.roundCountMin}, 0)`,
    ),
    check(
      'prescribed_groups_rest_max_check',
      sql`${t.restBetweenRoundsSecondsMax} is null or ${t.restBetweenRoundsSecondsMax} >= coalesce(${t.restBetweenRoundsSecondsMin}, 0)`,
    ),
    check(
      'prescribed_groups_scoring_check',
      sql`${t.scoring} is null or ${inEnum(t.scoring, SCORING_KINDS)}`,
    ),
    index('prescribed_groups_section_id_idx').on(t.sectionId),
    index('prescribed_groups_short_on_time_idx')
      .on(t.sectionId)
      .where(sql`${t.shortOnTimeRemove}`),
  ],
);

export type PrescribedGroup = typeof prescribedGroups.$inferSelect;
export type NewPrescribedGroup = typeof prescribedGroups.$inferInsert;
