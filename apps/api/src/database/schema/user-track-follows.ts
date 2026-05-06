import { sql } from 'drizzle-orm';
import {
  index,
  integer,
  pgTable,
  primaryKey,
  timestamp,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';

import { tracks } from './tracks';
import { users } from './users';

// Audit log for which tracks a user has followed and when. The composite PK
// `(user_id, track_id, followed_at)` allows the same user to re-follow a
// track they previously left — every (re-)follow gets its own row, every
// unfollow stamps `unfollowed_at`. The partial unique index ensures only
// one *active* follow exists per (user, track) at a time. Both sides
// cascade on delete: removing a user purges their history; archiving a
// track row removes dangling follows. This is a *follow* relationship,
// not an entitlement — billing/subscription state lives in a separate
// table when it ships.
export const userTrackFollows = pgTable(
  'user_track_follows',
  {
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    trackId: uuid('track_id')
      .notNull()
      .references(() => tracks.id, { onDelete: 'cascade' }),
    followedAt: timestamp('followed_at', { withTimezone: true })
      .notNull()
      .defaultNow(),
    /// When set, the follow ended on this timestamp. NULL means the follow
    /// is currently active. We never delete a row — history is the point.
    unfollowedAt: timestamp('unfollowed_at', { withTimezone: true }),
    sortOrder: integer('sort_order').notNull().default(100),
  },
  (t) => [
    primaryKey({ columns: [t.userId, t.trackId, t.followedAt] }),
    index('user_track_follows_user_id_idx').on(t.userId),
    uniqueIndex('user_track_follows_active_unique')
      .on(t.userId, t.trackId)
      .where(sql`${t.unfollowedAt} is null`),
  ],
);

export type UserTrackFollow = typeof userTrackFollows.$inferSelect;
export type NewUserTrackFollow = typeof userTrackFollows.$inferInsert;
