import { sql } from 'drizzle-orm';
import {
  jsonb,
  pgTable,
  text,
  timestamp,
  uuid,
} from 'drizzle-orm/pg-core';

// One row per app user. Phase 1 keeps the row deliberately thin: identity is
// resolved from the `X-User-Id` header (a UUID minted on the device keychain),
// and the row is upserted on first request. Email lands when Supabase auth
// ships; until then it stays null and the unique index permits multiple nulls
// (Postgres semantics).
export const users = pgTable('users', {
  id: uuid('id').primaryKey().default(sql`uuidv7()`),
  email: text('email').unique(),
  displayName: text('display_name'),
  metadata: jsonb('metadata').notNull().default(sql`'{}'::jsonb`),
  createdAt: timestamp('created_at', { withTimezone: true })
    .notNull()
    .defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true })
    .notNull()
    .defaultNow(),
});

export type User = typeof users.$inferSelect;
export type NewUser = typeof users.$inferInsert;
