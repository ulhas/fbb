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

import { days } from './days';
import { users } from './users';

// One row per started workout. Created on workout end (single-shot upsert),
// keyed by `client_session_id` so a network retry from iOS is idempotent.
// `track_code` is denormalized (not FK) so a track rename in `tracks` doesn't
// orphan history; `day_id` is best-effort linkage for queries that want to
// join the prescribed plan, but it is nullable because the plan can be
// re-parsed and the row may shift — `(track_code, scheduled_on)` is the
// durable identity.
export const workoutSessions = pgTable(
  'workout_sessions',
  {
    id: uuid('id').primaryKey().default(sql`uuidv7()`),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    trackCode: text('track_code').notNull(),
    scheduledOn: text('scheduled_on').notNull(),
    dayId: uuid('day_id').references(() => days.id, { onDelete: 'set null' }),
    clientSessionId: uuid('client_session_id').notNull(),
    startedAt: timestamp('started_at', { withTimezone: true }).notNull(),
    endedAt: timestamp('ended_at', { withTimezone: true }),
    totalElapsedSeconds: integer('total_elapsed_seconds').notNull().default(0),
    status: text('status').notNull().default('completed'),
    notes: text('notes'),
    weightUnit: text('weight_unit').notNull().default('kg'),
    createdAt: timestamp('created_at', { withTimezone: true })
      .notNull()
      .defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (t) => [
    unique('workout_sessions_client_session_id_unique').on(t.clientSessionId),
    check(
      'workout_sessions_status_check',
      sql`${t.status} in ('completed', 'abandoned')`,
    ),
    check(
      'workout_sessions_weight_unit_check',
      sql`${t.weightUnit} in ('kg', 'lb')`,
    ),
    check(
      'workout_sessions_total_elapsed_check',
      sql`${t.totalElapsedSeconds} >= 0`,
    ),
    check(
      'workout_sessions_scheduled_on_check',
      sql`${t.scheduledOn} ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'`,
    ),
    index('workout_sessions_user_scheduled_idx').on(
      t.userId,
      t.scheduledOn,
    ),
    index('workout_sessions_user_started_idx').on(t.userId, t.startedAt),
  ],
);

export type WorkoutSession = typeof workoutSessions.$inferSelect;
export type NewWorkoutSession = typeof workoutSessions.$inferInsert;
