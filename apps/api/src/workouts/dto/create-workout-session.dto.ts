import { z } from 'zod';

import { PRESCRIPTION_MODES } from '../../database/schema/enums';

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

const setLogSchema = z.object({
  section_position: z.number().int().min(1),
  group_position: z.number().int().min(1),
  exercise_position: z.number().int().min(1),
  set_position: z.number().int().min(1),
  per_side: z.enum(['first', 'second', 'done']).nullable().optional(),
  outcome: z.enum(['completed', 'skipped', 'partial']),
  actual_reps: z.number().int().min(0).nullable().optional(),
  actual_weight_kg: z.number().min(0).nullable().optional(),
  actual_rpe: z.number().min(1).max(10).nullable().optional(),
  rest_taken_seconds: z.number().int().min(0).nullable().optional(),
  completed_at: z.iso.datetime(),
});

const groupScoreSchema = z.object({
  section_position: z.number().int().min(1),
  group_position: z.number().int().min(1),
  prescription_mode: z.enum(PRESCRIPTION_MODES),
  rounds: z.number().int().min(0).nullable().optional(),
  partial_reps: z.number().int().min(0).nullable().optional(),
  finish_seconds: z.number().int().min(0).nullable().optional(),
  total_reps: z.number().int().min(0).nullable().optional(),
});

// Payload for POST /workouts/sessions. iOS assembles the entire session in
// one shot at workout end and posts it; the server upserts on
// `client_session_id` so a network retry produces no duplicates. Set logs
// and group scores are sent inline — there is no separate endpoint.
export const createWorkoutSessionSchema = z.object({
  client_session_id: z.uuid(),
  track_code: z.string().min(1).max(64),
  scheduled_on: z.string().regex(ISO_DATE),
  day_id: z.uuid().nullable().optional(),
  started_at: z.iso.datetime(),
  ended_at: z.iso.datetime().nullable().optional(),
  total_elapsed_seconds: z.number().int().min(0),
  status: z.enum(['completed', 'abandoned']),
  notes: z.string().max(4_000).nullable().optional(),
  weight_unit: z.enum(['kg', 'lb']).default('kg'),
  set_logs: z.array(setLogSchema).max(2_000),
  group_scores: z.array(groupScoreSchema).max(200),
});

export type CreateWorkoutSessionDto = z.infer<typeof createWorkoutSessionSchema>;
export type SetLogDto = z.infer<typeof setLogSchema>;
export type GroupScoreDto = z.infer<typeof groupScoreSchema>;
