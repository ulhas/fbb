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
  uuid,
} from 'drizzle-orm/pg-core';

import {
  TRACK_CADENCES,
  TRACK_FAMILIES,
  inEnum,
} from './enums';

export const tracks = pgTable(
  'tracks',
  {
    id: uuid('id').primaryKey().default(sql`uuid_generate_v7()`),
    code: text('code').notNull().unique(),
    family: text('family').notNull(),
    cadence: text('cadence'),
    displayName: text('display_name').notNull(),
    shortName: text('short_name'),
    description: text('description'),
    requiredEquipment: text('required_equipment')
      .array()
      .notNull()
      .default(sql`'{}'::text[]`),
    defaultForQuiz: boolean('default_for_quiz').notNull().default(false),
    active: boolean('active').notNull().default(true),
    sortOrder: integer('sort_order').notNull().default(100),
    metadata: jsonb('metadata').notNull().default(sql`'{}'::jsonb`),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    check('tracks_family_check', inEnum(t.family, TRACK_FAMILIES)),
    check(
      'tracks_cadence_check',
      sql`${t.cadence} is null or ${inEnum(t.cadence, TRACK_CADENCES)}`,
    ),
    index('tracks_family_idx').on(t.family),
    index('tracks_active_idx')
      .on(t.sortOrder)
      .where(sql`${t.active} = true`),
  ],
);

export type Track = typeof tracks.$inferSelect;
export type NewTrack = typeof tracks.$inferInsert;
