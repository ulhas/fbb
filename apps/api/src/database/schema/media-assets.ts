import { sql } from 'drizzle-orm';
import {
  boolean,
  check,
  index,
  integer,
  pgTable,
  text,
  timestamp,
  unique,
  uuid,
} from 'drizzle-orm/pg-core';

import {
  ASPECT_RATIOS,
  MEDIA_KINDS,
  MEDIA_PROVIDERS,
  inEnum,
} from './enums';

export const mediaAssets = pgTable(
  'media_assets',
  {
    id: uuid('id').primaryKey().default(sql`uuidv7()`),
    kind: text('kind').notNull(),
    provider: text('provider').notNull(),
    providerAssetId: text('provider_asset_id').notNull(),
    bunnyLibraryId: text('bunny_library_id'),
    posterUrl: text('poster_url'),
    durationSeconds: integer('duration_seconds'),
    aspectRatio: text('aspect_ratio'),
    widthPx: integer('width_px'),
    heightPx: integer('height_px'),
    language: text('language').notNull().default('en'),
    caption: text('caption'),
    transcript: text('transcript'),
    active: boolean('active').notNull().default(true),
    cmsSourceId: text('cms_source_id'),
    cmsRevision: text('cms_revision'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    unique('media_assets_provider_asset_unique').on(t.provider, t.providerAssetId),
    check('media_assets_kind_check', inEnum(t.kind, MEDIA_KINDS)),
    check('media_assets_provider_check', inEnum(t.provider, MEDIA_PROVIDERS)),
    check(
      'media_assets_aspect_check',
      sql`${t.aspectRatio} is null or ${inEnum(t.aspectRatio, ASPECT_RATIOS)}`,
    ),
    check(
      'media_assets_bunny_lib_check',
      sql`(${t.provider} = 'bunny') = (${t.bunnyLibraryId} is not null)`,
    ),
    index('media_assets_kind_active_idx')
      .on(t.kind)
      .where(sql`${t.active} = true`),
    index('media_assets_cms_source_idx')
      .on(t.cmsSourceId)
      .where(sql`${t.cmsSourceId} is not null`),
  ],
);

export type MediaAsset = typeof mediaAssets.$inferSelect;
export type NewMediaAsset = typeof mediaAssets.$inferInsert;
