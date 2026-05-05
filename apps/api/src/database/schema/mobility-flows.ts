import { sql } from 'drizzle-orm';
import {
  boolean,
  index,
  integer,
  pgTable,
  text,
  timestamp,
  unique,
  uuid,
} from 'drizzle-orm/pg-core';

import { movements } from './movements';

export const mobilityFlows = pgTable('mobility_flows', {
  id: uuid('id').primaryKey().default(sql`uuidv7()`),
  code: text('code').notNull().unique(),
  displayName: text('display_name').notNull(),
  description: text('description'),
  targetDurationMin: integer('target_duration_min'),
  targetDurationMax: integer('target_duration_max'),
  active: boolean('active').notNull().default(true),
  cmsSourceId: text('cms_source_id'),
  cmsRevision: text('cms_revision'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export const mobilityFlowSteps = pgTable(
  'mobility_flow_steps',
  {
    id: uuid('id').primaryKey().default(sql`uuidv7()`),
    flowId: uuid('flow_id')
      .notNull()
      .references(() => mobilityFlows.id, { onDelete: 'cascade' }),
    position: integer('position').notNull(),
    movementId: uuid('movement_id').references(() => movements.id),
    displayText: text('display_text').notNull(),
    durationSecondsMin: integer('duration_seconds_min'),
    durationSecondsMax: integer('duration_seconds_max'),
    repsMin: integer('reps_min'),
    repsMax: integer('reps_max'),
    perSide: boolean('per_side').notNull().default(false),
    notes: text('notes'),
  },
  (t) => [
    unique('mobility_flow_steps_flow_position_unique').on(t.flowId, t.position),
    index('mobility_flow_steps_flow_id_idx').on(t.flowId),
    index('mobility_flow_steps_movement_id_idx').on(t.movementId),
  ],
);

export type MobilityFlow = typeof mobilityFlows.$inferSelect;
export type NewMobilityFlow = typeof mobilityFlows.$inferInsert;
export type MobilityFlowStep = typeof mobilityFlowSteps.$inferSelect;
export type NewMobilityFlowStep = typeof mobilityFlowSteps.$inferInsert;
