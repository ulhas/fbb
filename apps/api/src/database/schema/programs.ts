import { sql } from 'drizzle-orm';
import {
  check,
  date,
  index,
  jsonb,
  pgTable,
  text,
  timestamp,
  unique,
  uuid,
} from 'drizzle-orm/pg-core';

import { PROGRAM_STATES, inEnum } from './enums';
import { tracks } from './tracks';

export const programs = pgTable(
  'programs',
  {
    id: uuid('id').primaryKey().default(sql`uuidv7()`),
    trackId: uuid('track_id')
      .notNull()
      .references(() => tracks.id, { onDelete: 'restrict' }),
    code: text('code').notNull(),
    displayName: text('display_name').notNull(),
    startsOn: date('starts_on').notNull(),
    endsOn: date('ends_on').notNull(),
    state: text('state').notNull().default('draft'),
    cmsSourceId: text('cms_source_id'),
    cmsRevision: text('cms_revision'),
    metadata: jsonb('metadata').notNull().default(sql`'{}'::jsonb`),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    unique('programs_track_code_unique').on(t.trackId, t.code),
    check('programs_state_check', inEnum(t.state, PROGRAM_STATES)),
    check('programs_dates_check', sql`${t.endsOn} >= ${t.startsOn}`),
    index('programs_track_id_idx').on(t.trackId),
    index('programs_live_window_idx')
      .on(t.startsOn, t.endsOn)
      .where(sql`${t.state} = 'live'`),
    index('programs_cms_source_idx')
      .on(t.cmsSourceId)
      .where(sql`${t.cmsSourceId} is not null`),
  ],
);

export type Program = typeof programs.$inferSelect;
export type NewProgram = typeof programs.$inferInsert;
