import { z } from 'zod';

// Mirrors `docs/schema.md` §4.9 weight_ref shapes one-to-one. Keep names and
// fields identical so future Drizzle inserts can `INSERT … (weight_ref) VALUES
// ($1::jsonb)` without a translation step. New shapes added here must also be
// added to the enum used by the parser prompt.

export const weightRefAbsoluteSchema = z.object({
  kind: z.literal('absolute'),
  // FBB authors absolute loads in lb pairs ("53/35# Male/Female"). The parser
  // normalises to kg here so the canonical column matches §1's numeric(7,3).
  load_kg_male: z.number().positive().nullable().optional(),
  load_kg_female: z.number().positive().nullable().optional(),
  raw: z.string().optional(),
});

export const weightRefRelativeToSetSchema = z.object({
  kind: z.literal('relative_to_set'),
  target_position: z.number().int().positive(),
});

export const weightRefPercentOfWorkingSchema = z.object({
  kind: z.literal('percent_of_working'),
  percent: z.number().min(1).max(200),
});

export const weightRefDeltaFromSetSchema = z.object({
  kind: z.literal('delta_from_set'),
  target_position: z.number().int().positive(),
  delta_percent: z.number(),
  delta_percent_max: z.number().optional(),
});

export const weightRefBodyweightSchema = z.object({
  kind: z.literal('bodyweight'),
});

export const weightRefAssistanceMatchSchema = z.object({
  kind: z.literal('assistance_match_rep_max'),
  rep_max: z.number().int().positive(),
});

// Always-allowed empty placeholder — the SQL column defaults to '{}'::jsonb,
// so the parser can emit this when no weight prescription is present (e.g.,
// warmup mobility movements).
export const weightRefEmptySchema = z.object({
  kind: z.literal('none'),
});

export const weightRefSchema = z.discriminatedUnion('kind', [
  weightRefAbsoluteSchema,
  weightRefRelativeToSetSchema,
  weightRefPercentOfWorkingSchema,
  weightRefDeltaFromSetSchema,
  weightRefBodyweightSchema,
  weightRefAssistanceMatchSchema,
  weightRefEmptySchema,
]);

export type WeightRef = z.infer<typeof weightRefSchema>;
