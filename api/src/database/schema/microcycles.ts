import { sql } from 'drizzle-orm';
import {
  check,
  date,
  index,
  integer,
  pgTable,
  text,
  timestamp,
  uuid,
} from 'drizzle-orm/pg-core';

import { MICROCYCLE_KINDS, inEnum } from './enums';
import { mesocycles } from './mesocycles';
import { programs } from './programs';

export const microcycles = pgTable(
  'microcycles',
  {
    id: uuid('id').primaryKey().default(sql`uuid_generate_v7()`),
    programId: uuid('program_id')
      .notNull()
      .references(() => programs.id, { onDelete: 'cascade' }),
    mesocycleId: uuid('mesocycle_id').references(() => mesocycles.id, {
      onDelete: 'set null',
    }),
    position: integer('position').notNull(),
    kind: text('kind').notNull().default('standard'),
    displayName: text('display_name').notNull(),
    startsOn: date('starts_on').notNull(),
    endsOn: date('ends_on').notNull(),
    deloadIntensityPct: integer('deload_intensity_pct'),
    cmsSourceId: text('cms_source_id'),
    cmsRevision: text('cms_revision'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    check('microcycles_kind_check', inEnum(t.kind, MICROCYCLE_KINDS)),
    check(
      'microcycles_dates_check',
      sql`${t.endsOn} = ${t.startsOn} + interval '6 days'`,
    ),
    check(
      'microcycles_deload_pct_check',
      sql`${t.deloadIntensityPct} is null or ${t.deloadIntensityPct} between 40 and 100`,
    ),
    check(
      'microcycles_standard_requires_meso_check',
      sql`(${t.kind} = 'standard' and ${t.mesocycleId} is not null) or (${t.kind} <> 'standard')`,
    ),
    index('microcycles_program_id_idx').on(t.programId),
    index('microcycles_mesocycle_id_idx').on(t.mesocycleId),
    index('microcycles_window_idx').on(t.startsOn, t.endsOn),
    index('microcycles_bridge_idx')
      .on(t.programId, t.startsOn)
      .where(sql`${t.kind} <> 'standard'`),
  ],
);

export type Microcycle = typeof microcycles.$inferSelect;
export type NewMicrocycle = typeof microcycles.$inferInsert;
