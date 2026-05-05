import { sql } from 'drizzle-orm';
import {
  check,
  index,
  integer,
  pgTable,
  text,
  timestamp,
  unique,
  uuid,
} from 'drizzle-orm/pg-core';

import { PRESCRIPTION_MODES, SECTION_KINDS, inEnum } from './enums';
import { days } from './days';

export const sections = pgTable(
  'sections',
  {
    id: uuid('id').primaryKey().default(sql`uuidv7()`),
    dayId: uuid('day_id')
      .notNull()
      .references(() => days.id, { onDelete: 'cascade' }),
    position: integer('position').notNull(),
    letter: text('letter').notNull(),
    kind: text('kind').notNull(),
    displayName: text('display_name').notNull(),
    targetDurationMin: integer('target_duration_min'),
    targetDurationMax: integer('target_duration_max'),
    prescriptionMode: text('prescription_mode').notNull().default('straight_sets'),
    dailyFocusNote: text('daily_focus_note'),
    effortNote: text('effort_note'),
    cmsSourceId: text('cms_source_id'),
    cmsRevision: text('cms_revision'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    unique('sections_day_position_unique').on(t.dayId, t.position),
    check(
      'sections_letter_check',
      sql`length(${t.letter}) = 1 and ${t.letter} ~ '^[A-Z]$'`,
    ),
    check('sections_kind_check', inEnum(t.kind, SECTION_KINDS)),
    check(
      'sections_prescription_mode_check',
      inEnum(t.prescriptionMode, PRESCRIPTION_MODES),
    ),
    check(
      'sections_duration_min_check',
      sql`${t.targetDurationMin} is null or ${t.targetDurationMin} > 0`,
    ),
    check(
      'sections_duration_max_check',
      sql`${t.targetDurationMax} is null or ${t.targetDurationMax} >= coalesce(${t.targetDurationMin}, 0)`,
    ),
    index('sections_day_id_idx').on(t.dayId),
    index('sections_kind_idx').on(t.kind),
  ],
);

export type Section = typeof sections.$inferSelect;
export type NewSection = typeof sections.$inferInsert;
