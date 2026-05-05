import { sql } from 'drizzle-orm';
import {
  check,
  date,
  index,
  integer,
  pgTable,
  text,
  timestamp,
  unique,
  uuid,
} from 'drizzle-orm/pg-core';

import { MESOCYCLE_INTENTS, inEnum } from './enums';
import { programs } from './programs';

export const mesocycles = pgTable(
  'mesocycles',
  {
    id: uuid('id').primaryKey().default(sql`uuidv7()`),
    programId: uuid('program_id')
      .notNull()
      .references(() => programs.id, { onDelete: 'cascade' }),
    position: integer('position').notNull(),
    displayName: text('display_name').notNull(),
    intent: text('intent'),
    startsOn: date('starts_on').notNull(),
    endsOn: date('ends_on').notNull(),
    cmsSourceId: text('cms_source_id'),
    cmsRevision: text('cms_revision'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    unique('mesocycles_program_position_unique').on(t.programId, t.position),
    check(
      'mesocycles_intent_check',
      sql`${t.intent} is null or ${inEnum(t.intent, MESOCYCLE_INTENTS)}`,
    ),
    check('mesocycles_dates_check', sql`${t.endsOn} >= ${t.startsOn}`),
    index('mesocycles_program_id_idx').on(t.programId),
    index('mesocycles_window_idx').on(t.startsOn, t.endsOn),
  ],
);

export type Mesocycle = typeof mesocycles.$inferSelect;
export type NewMesocycle = typeof mesocycles.$inferInsert;
