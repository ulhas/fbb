import { sql } from 'drizzle-orm';
import {
  boolean,
  index,
  pgTable,
  text,
  timestamp,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';

// Editable system-prompt versions, surfaced by the admin console. Each row is
// a frozen version of the prompt body for some `slug` (e.g. 'parse-day');
// only one row per slug carries `is_active=true` at a time, enforced by the
// partial unique index. Inactivating + inserting happens in a single
// transaction in SystemPromptsService.create.
//
// Why versions instead of mutating the active row: the prompt is the core
// behaviour driver of the parse pipeline. Audit + rollback matter — if a new
// prompt makes Sonnet hallucinate, we want to see what changed and restore
// in one click.
export const systemPrompts = pgTable(
  'system_prompts',
  {
    id: uuid('id').primaryKey().default(sql`uuidv7()`),
    slug: text('slug').notNull(),
    bodyMarkdown: text('body_markdown').notNull(),
    isActive: boolean('is_active').notNull().default(false),
    createdAt: timestamp('created_at', { withTimezone: true })
      .notNull()
      .defaultNow(),
    // Free-text label so the editor can show "v3 — fixed Spoto press parsing"
    // in the version list. Optional; defaults to "" when the editor doesn't
    // ask for one.
    label: text('label').notNull().default(''),
  },
  (t) => [
    uniqueIndex('system_prompts_active_unique')
      .on(t.slug)
      .where(sql`${t.isActive} = true`),
    index('system_prompts_slug_created_idx').on(t.slug, t.createdAt),
  ],
);

export type SystemPrompt = typeof systemPrompts.$inferSelect;
export type NewSystemPrompt = typeof systemPrompts.$inferInsert;
