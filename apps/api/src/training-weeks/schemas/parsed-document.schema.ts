import { z } from 'zod';

import {
  COACHING_NOTE_KINDS,
  DAY_KINDS,
  MICROCYCLE_KINDS,
  PER_SIDE_STARTS,
  PRESCRIPTION_MODES,
  REPS_KINDS,
  SCORING_KINDS,
  SECTION_KINDS,
  SET_KINDS,
  TRACK_CADENCES,
  TRACK_FAMILIES,
} from '../../database/schema/enums';
import { weightRefSchema } from './weight-ref.schema';

// All parser outputs use snake_case keys to match the SQL column names. Future
// Drizzle insert code can spread these objects into `db.insert(...)` calls
// without renaming. `*_text` fallbacks live alongside parsed numeric/enum
// fields so a low-confidence LLM output preserves the source for downstream
// review without crashing the response.

const isoDate = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, 'expected ISO YYYY-MM-DD');

export const parsedSetSchema = z
  .object({
    position: z.number().int().positive(),
    set_kind: z.enum(SET_KINDS),
    reps_kind: z.enum(REPS_KINDS),
    reps_min: z.number().int().positive().nullable(),
    reps_max: z.number().int().positive().nullable(),
    reps_text: z.string().nullable(),
    duration_seconds_min: z.number().int().positive().nullable(),
    duration_seconds_max: z.number().int().positive().nullable(),
    per_side: z.boolean(),
    // Tempo regex: 4 chars in [0-9XA] (matches the SQL CHECK in §4.9).
    tempo: z
      .string()
      .regex(/^[0-9XA]{4}$/)
      .nullable(),
    rpe_min: z.number().min(1).max(10).nullable(),
    rpe_max: z.number().min(1).max(10).nullable(),
    rpe_text: z.string().nullable(),
    weight_ref: weightRefSchema,
    rest_after_seconds_min: z.number().int().nonnegative().nullable(),
    rest_after_seconds_max: z.number().int().nonnegative().nullable(),
    rest_after_text: z.string().nullable(),
    has_drop_set: z.boolean(),
    drop_set_descriptor: z
      .object({
        drops: z.number().int().positive(),
        reduce_pct: z.array(z.number().nonnegative()).nullable(),
        notes: z.string().nullable(),
      })
      .nullable(),
    notes: z.string().nullable(),
  })
  .superRefine((s, ctx) => {
    if (s.reps_min != null && s.reps_max != null && s.reps_max < s.reps_min) {
      ctx.addIssue({
        code: 'custom',
        message: 'reps_max must be >= reps_min',
        path: ['reps_max'],
      });
    }
    if (
      s.duration_seconds_min != null &&
      s.duration_seconds_max != null &&
      s.duration_seconds_max < s.duration_seconds_min
    ) {
      ctx.addIssue({
        code: 'custom',
        message: 'duration_seconds_max must be >= duration_seconds_min',
        path: ['duration_seconds_max'],
      });
    }
    if (s.rpe_min != null && s.rpe_max != null && s.rpe_max < s.rpe_min) {
      ctx.addIssue({
        code: 'custom',
        message: 'rpe_max must be >= rpe_min',
        path: ['rpe_max'],
      });
    }
    if (
      s.rest_after_seconds_min != null &&
      s.rest_after_seconds_max != null &&
      s.rest_after_seconds_max < s.rest_after_seconds_min
    ) {
      ctx.addIssue({
        code: 'custom',
        message: 'rest_after_seconds_max must be >= rest_after_seconds_min',
        path: ['rest_after_seconds_max'],
      });
    }
  });

export type ParsedSet = z.infer<typeof parsedSetSchema>;

export const parsedExerciseSchema = z.object({
  position: z.number().int().positive(),
  // Verbatim PDF string — movement-id resolution is deferred (Schema-validity
  // Pass 3 #2). Insertion logic resolves to `movements.id` later.
  movement_display_name: z.string().min(1),
  // Reference to another exercise's `position` in the same group for "or"
  // alternates. `null` means this is the primary movement.
  alternate_of_position: z.number().int().positive().nullable(),
  chained_into_next: z.boolean(),
  rest_after_seconds_min: z.number().int().nonnegative().nullable(),
  rest_after_seconds_max: z.number().int().nonnegative().nullable(),
  rest_after_text: z.string().nullable(),
  is_unilateral: z.boolean(),
  per_side_starts: z.enum(PER_SIDE_STARTS).nullable(),
  notes: z.string().nullable(),
  sets: z.array(parsedSetSchema),
});

export type ParsedExercise = z.infer<typeof parsedExerciseSchema>;

// One Group schema covers every prescription mode. Mode-specific required
// fields are enforced by the superRefine below — keeping a single object shape
// keeps `generateObject` happy (deeply nested discriminated unions can confuse
// the model) while still rejecting bad outputs at the gate.
export const parsedGroupSchema = z
  .object({
    position: z.number().int().positive(),
    prescription_mode: z.enum(PRESCRIPTION_MODES),
    round_count_min: z.number().int().positive().nullable(),
    round_count_max: z.number().int().positive().nullable(),
    interval_seconds: z.number().int().positive().nullable(),
    cap_seconds: z.number().int().positive().nullable(),
    rest_between_rounds_seconds_min: z.number().int().nonnegative().nullable(),
    rest_between_rounds_seconds_max: z.number().int().nonnegative().nullable(),
    rest_between_rounds_text: z.string().nullable(),
    loading_note: z.string().nullable(),
    effort_note: z.string().nullable(),
    short_on_time_remove: z.boolean(),
    scoring: z.enum(SCORING_KINDS).nullable(),
    interval_pyramid_steps: z
      .array(
        z.object({
          duration_seconds: z.number().int().positive(),
          intensity_pct: z.number().min(1).max(100).nullable(),
          notes: z.string().nullable(),
        }),
      )
      .nullable(),
    progression_text: z.string().nullable(),
    exercises: z.array(parsedExerciseSchema),
  })
  .superRefine((g, ctx) => {
    const requireInterval = ['every_x_minutes', 'emom', 'e2mom', 'e3mom'];
    if (
      requireInterval.includes(g.prescription_mode) &&
      g.interval_seconds == null
    ) {
      ctx.addIssue({
        code: 'custom',
        message: `prescription_mode=${g.prescription_mode} requires interval_seconds`,
        path: ['interval_seconds'],
      });
    }
    // AMRAP needs a cap (it's literally a time-boxed effort). `for_time`
    // is bounded by either a cap OR a fixed round count — many real-world
    // for-time prescriptions are open-ended ("complete 2 rounds, no cap")
    // and the engine has a default fallback when both are absent.
    if (g.prescription_mode === 'amrap' && g.cap_seconds == null) {
      ctx.addIssue({
        code: 'custom',
        message: 'prescription_mode=amrap requires cap_seconds',
        path: ['cap_seconds'],
      });
    }
    if (
      g.prescription_mode === 'for_time' &&
      g.cap_seconds == null &&
      g.round_count_min == null
    ) {
      ctx.addIssue({
        code: 'custom',
        message: 'prescription_mode=for_time requires cap_seconds or a round count',
        path: ['cap_seconds'],
      });
    }
    if (
      g.prescription_mode === 'interval_pyramid' &&
      (g.interval_pyramid_steps == null || g.interval_pyramid_steps.length === 0)
    ) {
      ctx.addIssue({
        code: 'custom',
        message: 'interval_pyramid requires interval_pyramid_steps[]',
        path: ['interval_pyramid_steps'],
      });
    }
    if (
      g.round_count_min != null &&
      g.round_count_max != null &&
      g.round_count_max < g.round_count_min
    ) {
      ctx.addIssue({
        code: 'custom',
        message: 'round_count_max must be >= round_count_min',
        path: ['round_count_max'],
      });
    }
  });

export type ParsedGroup = z.infer<typeof parsedGroupSchema>;

export const parsedSectionSchema = z
  .object({
    position: z.number().int().positive(),
    letter: z.string().regex(/^[A-Z]$/),
    kind: z.enum(SECTION_KINDS),
    display_name: z.string().min(1),
    target_duration_min: z.number().int().positive().nullable(),
    target_duration_max: z.number().int().positive().nullable(),
    prescription_mode: z.enum(PRESCRIPTION_MODES),
    daily_focus_note: z.string().nullable(),
    effort_note: z.string().nullable(),
    short_on_time_directive: z.string().nullable(),
    groups: z.array(parsedGroupSchema),
  })
  .superRefine((s, ctx) => {
    if (
      s.target_duration_min != null &&
      s.target_duration_max != null &&
      s.target_duration_max < s.target_duration_min
    ) {
      ctx.addIssue({
        code: 'custom',
        message: 'target_duration_max must be >= target_duration_min',
        path: ['target_duration_max'],
      });
    }
  });

export type ParsedSection = z.infer<typeof parsedSectionSchema>;

export const parsedCoachingNoteSchema = z.object({
  kind: z.enum(COACHING_NOTE_KINDS),
  title: z.string().nullable(),
  body_markdown: z.string().min(1),
});

export type ParsedCoachingNote = z.infer<typeof parsedCoachingNoteSchema>;

export const parsedDaySchema = z.object({
  scheduled_on: isoDate,
  position: z.number().int().min(1).max(7),
  display_name: z.string().min(1),
  kind: z.enum(DAY_KINDS),
  is_optional: z.boolean(),
  // Cross-check vs calendar-derived position; mismatches surface as warnings.
  week_position: z.number().int().min(1).max(12).nullable(),
  day_position: z.number().int().min(1).max(7).nullable(),
  raw_text: z.string(),
  cms_source_id: z.string(),
  sections: z.array(parsedSectionSchema),
  coaching_notes: z.array(parsedCoachingNoteSchema),
});

export type ParsedDay = z.infer<typeof parsedDaySchema>;

// Schema the LLM fills per-day. The orchestrator patches in everything the
// segmenter already knows (scheduled_on, position, display_name, kind,
// is_optional, week/day_position) so the LLM doesn't waste output tokens
// echoing back ground truth from the user prompt. Day-position mismatches
// are caught earlier in the segmenter, so the LLM has no cross-check role.
export const parsedDayLLMSchema = parsedDaySchema.omit({
  raw_text: true,
  cms_source_id: true,
  scheduled_on: true,
  position: true,
  display_name: true,
  kind: true,
  is_optional: true,
  week_position: true,
  day_position: true,
});

export type ParsedDayLLM = z.infer<typeof parsedDayLLMSchema>;

export const parsedMicrocycleHintSchema = z.object({
  kind: z.enum(MICROCYCLE_KINDS),
  starts_on: isoDate,
  ends_on: isoDate,
  // Hint, not authority — final placement decided at insert time across uploads.
  mesocycle_position_hint: z.number().int().nullable(),
  week_position: z.number().int().min(1).max(12).nullable(),
});

export type ParsedMicrocycleHint = z.infer<typeof parsedMicrocycleHintSchema>;

export const parsedTrackSchema = z.object({
  track_code: z.string().min(1),
  family: z.enum(TRACK_FAMILIES),
  cadence: z.enum(TRACK_CADENCES).nullable(),
  display_name: z.string().min(1),
  microcycle: parsedMicrocycleHintSchema,
  days: z.array(parsedDaySchema),
});

export type ParsedTrack = z.infer<typeof parsedTrackSchema>;

export const parsedDocumentSchema = z.object({
  source_filename: z.string(),
  week_starts_on: isoDate,
  page_count: z.number().int().nonnegative(),
  tracks: z.array(parsedTrackSchema),
});

export type ParsedDocument = z.infer<typeof parsedDocumentSchema>;

export const parseWarningSchema = z.object({
  scope: z.enum(['document', 'track', 'day', 'section', 'group', 'exercise', 'set']),
  locator: z.string(),
  code: z.string(),
  detail: z.string(),
});

export type ParseWarning = z.infer<typeof parseWarningSchema>;

export const modelSpecSchema = z.object({
  provider: z.enum(['openai', 'anthropic']),
  model: z.string(),
  reasoning_effort: z
    .enum(['minimal', 'low', 'medium', 'high'])
    .nullable()
    .optional(),
});

export type ModelSpec = z.infer<typeof modelSpecSchema>;

export const parseMetricsSchema = z.object({
  model: z.string(),
  // ModelSpec the run actually used. Optional for backwards compat with older
  // payloads (pre-multi-provider); new runs always populate it.
  model_spec: modelSpecSchema.optional(),
  temperature: z.number(),
  extraction_ms: z.number(),
  segmentation_ms: z.number(),
  llm_total_ms: z.number(),
  llm_calls: z.number().int().nonnegative(),
  tokens_input_total: z.number().int().nonnegative(),
  tokens_output_total: z.number().int().nonnegative(),
  tokens_total: z.number().int().nonnegative(),
  concurrency: z.number().int().positive(),
});

export type ParseMetrics = z.infer<typeof parseMetricsSchema>;
