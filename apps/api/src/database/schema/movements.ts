import { sql } from 'drizzle-orm';
import {
  boolean,
  check,
  index,
  integer,
  pgTable,
  primaryKey,
  text,
  timestamp,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';

import {
  MOVEMENT_EQUIPMENT,
  MOVEMENT_MEDIA_ROLES,
  MOVEMENT_PATTERNS,
  MOVEMENT_PLANES,
  MOVEMENT_VIDEO_PROVIDERS,
  inEnum,
} from './enums';
import { mediaAssets } from './media-assets';

export const movements = pgTable(
  'movements',
  {
    id: uuid('id').primaryKey().default(sql`uuidv7()`),
    cmsSourceId: text('cms_source_id'),
    cmsRevision: text('cms_revision'),
    name: text('name').notNull(),
    alternateNames: text('alternate_names')
      .array()
      .notNull()
      .default(sql`'{}'::text[]`),
    primaryMuscle: text('primary_muscle'),
    secondaryMuscles: text('secondary_muscles')
      .array()
      .notNull()
      .default(sql`'{}'::text[]`),
    equipment: text('equipment').notNull(),
    movementPattern: text('movement_pattern'),
    plane: text('plane'),
    jointAction: text('joint_action'),
    unilateral: boolean('unilateral').notNull().default(false),
    difficulty: integer('difficulty'),
    coachCues: text('coach_cues'),
    // Trigger-maintained denormalised pointers to the primary_demo asset.
    primaryVideoProvider: text('primary_video_provider'),
    primaryVideoId: text('primary_video_id'),
    primaryVideoPosterUrl: text('primary_video_poster_url'),
    primaryVideoDurationSeconds: integer('primary_video_duration_seconds'),
    active: boolean('active').notNull().default(true),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    check('movements_equipment_check', inEnum(t.equipment, MOVEMENT_EQUIPMENT)),
    check(
      'movements_pattern_check',
      sql`${t.movementPattern} is null or ${inEnum(t.movementPattern, MOVEMENT_PATTERNS)}`,
    ),
    check(
      'movements_plane_check',
      sql`${t.plane} is null or ${inEnum(t.plane, MOVEMENT_PLANES)}`,
    ),
    check(
      'movements_difficulty_check',
      sql`${t.difficulty} is null or ${t.difficulty} between 1 and 5`,
    ),
    check(
      'movements_video_provider_check',
      sql`${t.primaryVideoProvider} is null or ${inEnum(t.primaryVideoProvider, MOVEMENT_VIDEO_PROVIDERS)}`,
    ),
    index('movements_active_idx')
      .on(t.name)
      .where(sql`${t.active} = true`),
    index('movements_equipment_idx')
      .on(t.equipment)
      .where(sql`${t.active} = true`),
    index('movements_pattern_idx')
      .on(t.movementPattern)
      .where(sql`${t.active} = true`),
    index('movements_with_video_idx')
      .on(t.name)
      .where(sql`${t.active} = true and ${t.primaryVideoId} is not null`),
    index('movements_alt_names_idx').using('gin', t.alternateNames),
    index('movements_secondary_idx').using('gin', t.secondaryMuscles),
    index('movements_name_trgm_idx').using('gin', sql`${t.name} gin_trgm_ops`),
  ],
);

export const movementMedia = pgTable(
  'movement_media',
  {
    movementId: uuid('movement_id')
      .notNull()
      .references(() => movements.id, { onDelete: 'cascade' }),
    mediaAssetId: uuid('media_asset_id')
      .notNull()
      .references(() => mediaAssets.id, { onDelete: 'cascade' }),
    role: text('role').notNull().default('primary_demo'),
    position: integer('position').notNull().default(0),
    notes: text('notes'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    primaryKey({ columns: [t.movementId, t.mediaAssetId, t.role] }),
    check('movement_media_role_check', inEnum(t.role, MOVEMENT_MEDIA_ROLES)),
    index('movement_media_movement_idx').on(t.movementId, t.role, t.position),
    index('movement_media_asset_idx').on(t.mediaAssetId),
    uniqueIndex('movement_media_one_primary')
      .on(t.movementId)
      .where(sql`role = 'primary_demo'`),
  ],
);

export type Movement = typeof movements.$inferSelect;
export type NewMovement = typeof movements.$inferInsert;
export type MovementMedia = typeof movementMedia.$inferSelect;
export type NewMovementMedia = typeof movementMedia.$inferInsert;
