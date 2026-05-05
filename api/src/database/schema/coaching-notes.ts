import { sql } from 'drizzle-orm';
import {
  check,
  index,
  pgTable,
  text,
  timestamp,
  uuid,
} from 'drizzle-orm/pg-core';

import { COACHING_NOTE_KINDS, COACHING_NOTE_SCOPES, inEnum } from './enums';

export const coachingNotes = pgTable(
  'coaching_notes',
  {
    id: uuid('id').primaryKey().default(sql`uuid_generate_v7()`),
    scope: text('scope').notNull(),
    scopeId: uuid('scope_id').notNull(),
    kind: text('kind').notNull(),
    title: text('title'),
    bodyMarkdown: text('body_markdown').notNull(),
    cmsSourceId: text('cms_source_id'),
    cmsRevision: text('cms_revision'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    check('coaching_notes_scope_check', inEnum(t.scope, COACHING_NOTE_SCOPES)),
    check('coaching_notes_kind_check', inEnum(t.kind, COACHING_NOTE_KINDS)),
    index('coaching_notes_scope_idx').on(t.scope, t.scopeId),
  ],
);

export type CoachingNote = typeof coachingNotes.$inferSelect;
export type NewCoachingNote = typeof coachingNotes.$inferInsert;
