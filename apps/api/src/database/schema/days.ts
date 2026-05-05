import { sql } from 'drizzle-orm';
import {
  boolean,
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

import { DAY_KINDS, HK_ACTIVITY_TYPES, inEnum } from './enums';
import { microcycles } from './microcycles';
import { movements } from './movements';

export const days = pgTable(
  'days',
  {
    id: uuid('id').primaryKey().default(sql`uuidv7()`),
    microcycleId: uuid('microcycle_id')
      .notNull()
      .references(() => microcycles.id, { onDelete: 'cascade' }),
    position: integer('position').notNull(),
    scheduledOn: date('scheduled_on').notNull(),
    displayName: text('display_name').notNull(),
    kind: text('kind').notNull().default('workout'),
    isOptional: boolean('is_optional').notNull().default(false),
    defaultActivityType: text('default_activity_type'),
    heroMovementId: uuid('hero_movement_id').references(() => movements.id, {
      onDelete: 'set null',
    }),
    cmsSourceId: text('cms_source_id'),
    cmsRevision: text('cms_revision'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    unique('days_microcycle_position_unique').on(t.microcycleId, t.position),
    check('days_kind_check', inEnum(t.kind, DAY_KINDS)),
    check('days_position_check', sql`${t.position} between 1 and 7`),
    check(
      'days_activity_type_check',
      sql`${t.defaultActivityType} is null or ${inEnum(t.defaultActivityType, HK_ACTIVITY_TYPES)}`,
    ),
    index('days_microcycle_id_idx').on(t.microcycleId),
    index('days_scheduled_on_idx').on(t.scheduledOn),
    index('days_hero_movement_id_idx')
      .on(t.heroMovementId)
      .where(sql`${t.heroMovementId} is not null`),
  ],
);

export type Day = typeof days.$inferSelect;
export type NewDay = typeof days.$inferInsert;
