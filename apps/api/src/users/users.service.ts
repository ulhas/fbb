import { Injectable, NotFoundException } from '@nestjs/common';
import { and, asc, desc, eq, isNull, sql } from 'drizzle-orm';

import { DatabaseService } from '../database/database.service';
import { tracks } from '../database/schema/tracks';
import { userTrackFollows } from '../database/schema/user-track-follows';
import { users } from '../database/schema/users';

export interface MeResponseRow {
  id: string;
  email: string | null;
  display_name: string | null;
  followed_track_codes: string[];
}

export interface TrackCatalogRow {
  id: string;
  code: string;
  family: string;
  cadence: string | null;
  display_name: string;
  short_name: string | null;
  description: string | null;
  required_equipment: string[];
  sort_order: number;
  is_followed: boolean;
}

export interface FollowEventRow {
  track_code: string;
  track_display_name: string;
  followed_at: string;
  unfollowed_at: string | null;
  is_active: boolean;
}

export interface AdminUserRow {
  id: string;
  email: string | null;
  display_name: string | null;
  active_follow_count: number;
  created_at: string;
  updated_at: string;
}

@Injectable()
export class UsersService {
  constructor(private readonly database: DatabaseService) {}

  async getMe(userId: string): Promise<MeResponseRow> {
    const [me] = await this.database.db
      .select()
      .from(users)
      .where(eq(users.id, userId))
      .limit(1);
    if (!me) {
      // Should be impossible — CurrentUserGuard upserts on every request.
      // Surface loudly if it ever happens.
      throw new NotFoundException(`user ${userId} not found`);
    }

    // Active follows only — `unfollowed_at IS NULL`. Past follows live in
    // the same table for history (`/me/tracks/history`).
    const followRows = await this.database.db
      .select({ code: tracks.code })
      .from(userTrackFollows)
      .innerJoin(tracks, eq(userTrackFollows.trackId, tracks.id))
      .where(
        and(
          eq(userTrackFollows.userId, userId),
          isNull(userTrackFollows.unfollowedAt),
        ),
      )
      .orderBy(asc(userTrackFollows.sortOrder), asc(userTrackFollows.followedAt));

    return {
      id: me.id,
      email: me.email,
      display_name: me.displayName,
      followed_track_codes: followRows.map((r) => r.code),
    };
  }

  // Active tracks only — archived/inactive tracks never make it to the
  // picker. `is_followed` reflects only currently-active follows; past
  // follows are surfaced via the history endpoint.
  async listTrackCatalog(userId: string): Promise<TrackCatalogRow[]> {
    const followed = await this.database.db
      .select({ trackId: userTrackFollows.trackId })
      .from(userTrackFollows)
      .where(
        and(
          eq(userTrackFollows.userId, userId),
          isNull(userTrackFollows.unfollowedAt),
        ),
      );
    const followedSet = new Set(followed.map((f) => f.trackId));

    const rows = await this.database.db
      .select()
      .from(tracks)
      .where(eq(tracks.active, true))
      .orderBy(asc(tracks.sortOrder), asc(tracks.displayName));

    return rows.map((t) => ({
      id: t.id,
      code: t.code,
      family: t.family,
      cadence: t.cadence,
      display_name: t.displayName,
      short_name: t.shortName,
      description: t.description,
      required_equipment: t.requiredEquipment,
      sort_order: t.sortOrder,
      is_followed: followedSet.has(t.id),
    }));
  }

  /// Idempotent — no-op when an active follow already exists. Otherwise
  /// inserts a fresh row; `followed_at` defaults to `now()` and
  /// `unfollowed_at` stays NULL until the user unfollows.
  async followTrack(userId: string, trackCode: string): Promise<void> {
    const [track] = await this.database.db
      .select({ id: tracks.id, active: tracks.active })
      .from(tracks)
      .where(eq(tracks.code, trackCode))
      .limit(1);
    if (!track) {
      throw new NotFoundException(`track "${trackCode}" not found`);
    }
    if (!track.active) {
      throw new NotFoundException(`track "${trackCode}" is not active`);
    }

    // Short-circuit if the user already follows this track. Cheaper than
    // catching the partial-unique-index conflict.
    const [existing] = await this.database.db
      .select({ followedAt: userTrackFollows.followedAt })
      .from(userTrackFollows)
      .where(
        and(
          eq(userTrackFollows.userId, userId),
          eq(userTrackFollows.trackId, track.id),
          isNull(userTrackFollows.unfollowedAt),
        ),
      )
      .limit(1);
    if (existing) return;

    await this.database.db
      .insert(userTrackFollows)
      .values({ userId, trackId: track.id });
  }

  /// Stamps the active follow's `unfollowed_at`. The row stays in the
  /// table — history is the whole point. No-op if there's no active
  /// follow.
  async unfollowTrack(userId: string, trackCode: string): Promise<void> {
    const [track] = await this.database.db
      .select({ id: tracks.id })
      .from(tracks)
      .where(eq(tracks.code, trackCode))
      .limit(1);
    if (!track) {
      throw new NotFoundException(`track "${trackCode}" not found`);
    }

    await this.database.db
      .update(userTrackFollows)
      .set({ unfollowedAt: sql`now()` })
      .where(
        and(
          eq(userTrackFollows.userId, userId),
          eq(userTrackFollows.trackId, track.id),
          isNull(userTrackFollows.unfollowedAt),
        ),
      );
  }

  /// Admin list: every user with their currently-active follow count. Newest
  /// users first so freshly registered accounts surface at the top of the
  /// admin table. Active-only count keeps it aligned with what the user sees
  /// in their picker; historical follows live in `getFollowHistory`.
  async listAll(limit = 200): Promise<AdminUserRow[]> {
    const activeFollowCount = sql<number>`coalesce(count(${userTrackFollows.userId}) filter (where ${userTrackFollows.unfollowedAt} is null), 0)::int`;
    const rows = await this.database.db
      .select({
        id: users.id,
        email: users.email,
        displayName: users.displayName,
        createdAt: users.createdAt,
        updatedAt: users.updatedAt,
        activeFollowCount,
      })
      .from(users)
      .leftJoin(userTrackFollows, eq(userTrackFollows.userId, users.id))
      .groupBy(users.id)
      .orderBy(desc(users.createdAt))
      .limit(limit);

    return rows.map((r) => ({
      id: r.id,
      email: r.email,
      display_name: r.displayName,
      active_follow_count: r.activeFollowCount,
      created_at: r.createdAt.toISOString(),
      updated_at: r.updatedAt.toISOString(),
    }));
  }

  /// Full audit: every (re-)follow this user has ever made, newest first.
  /// Each row resolves the track's display name and code so callers don't
  /// need to re-join. `is_active` is derived from `unfollowed_at IS NULL`.
  async getFollowHistory(userId: string): Promise<FollowEventRow[]> {
    const rows = await this.database.db
      .select({
        code: tracks.code,
        displayName: tracks.displayName,
        followedAt: userTrackFollows.followedAt,
        unfollowedAt: userTrackFollows.unfollowedAt,
      })
      .from(userTrackFollows)
      .innerJoin(tracks, eq(userTrackFollows.trackId, tracks.id))
      .where(eq(userTrackFollows.userId, userId))
      .orderBy(desc(userTrackFollows.followedAt));

    return rows.map((r) => ({
      track_code: r.code,
      track_display_name: r.displayName,
      followed_at: r.followedAt.toISOString(),
      unfollowed_at: r.unfollowedAt ? r.unfollowedAt.toISOString() : null,
      is_active: r.unfollowedAt == null,
    }));
  }
}
