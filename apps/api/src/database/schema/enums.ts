// Single source of truth for every text+check enum in the content domain.
// Mirrors `docs/schema.md` §§4.1–4.11 + §5.1–5.2 verbatim. Re-used by Drizzle
// `check()` constraints (via `inEnum()` helper) and by Zod schemas in the
// admin parser, so SQL and application validation cannot drift.

import { sql, type SQL } from 'drizzle-orm';
import type { AnyPgColumn } from 'drizzle-orm/pg-core';

export const TRACK_FAMILIES = [
  'pump_lift',
  'pump_condition',
  'perform',
  'minimalist',
  'hybrid_running',
  'workshop',
  'onramp',
] as const;
export type TrackFamily = (typeof TRACK_FAMILIES)[number];

export const TRACK_CADENCES = ['3x', '4x', '5x', 'custom'] as const;
export type TrackCadence = (typeof TRACK_CADENCES)[number];

export const PROGRAM_STATES = ['draft', 'scheduled', 'live', 'archived'] as const;
export type ProgramState = (typeof PROGRAM_STATES)[number];

export const MESOCYCLE_INTENTS = [
  'hypertrophy',
  'strength',
  'conditioning',
  'mixed',
  'deload',
] as const;
export type MesocycleIntent = (typeof MESOCYCLE_INTENTS)[number];

export const MICROCYCLE_KINDS = [
  'standard',
  'bridge_week',
  'deload',
  'orphan_bridge',
] as const;
export type MicrocycleKind = (typeof MICROCYCLE_KINDS)[number];

export const DAY_KINDS = [
  'workout',
  'active_recovery',
  'mobility',
  'rest',
  'lesson',
] as const;
export type DayKind = (typeof DAY_KINDS)[number];

export const HK_ACTIVITY_TYPES = [
  'functional_strength_training',
  'traditional_strength_training',
  'high_intensity_interval_training',
  'cross_training',
  'cycling',
  'running',
  'rowing',
  'mind_and_body',
  'flexibility',
  'other',
] as const;
export type HKActivityType = (typeof HK_ACTIVITY_TYPES)[number];

export const SECTION_KINDS = [
  'focus_note',
  'warmup',
  'speed_strength',
  'strength_intensity',
  'strength_balance',
  'finisher',
  'conditioning',
  'intervals',
  'mobility',
  'cooldown',
  'active_recovery',
  'lesson',
  'engine_hot_start',
  'kettlebell_hot_start',
  'upper_couplets',
  'interval_pyramid',
  'high_turnover_cardio',
] as const;
export type SectionKind = (typeof SECTION_KINDS)[number];

export const PRESCRIPTION_MODES = [
  'straight_sets',
  'every_x_minutes',
  'emom',
  'e2mom',
  'e3mom',
  'amrap',
  'for_time',
  'tabata',
  'density',
  'rounds',
  'interval_pyramid',
  'continuous_effort',
  'free',
] as const;
export type PrescriptionMode = (typeof PRESCRIPTION_MODES)[number];

export const SCORING_KINDS = [
  'reps',
  'time',
  'rounds_plus_reps',
  'distance',
  'calories',
] as const;
export type ScoringKind = (typeof SCORING_KINDS)[number];

export const PER_SIDE_STARTS = ['left', 'right', 'either'] as const;
export type PerSideStart = (typeof PER_SIDE_STARTS)[number];

export const SET_KINDS = [
  'warmup',
  'working',
  'max_unbroken',
  'drop',
  'back_off',
  'isometric_hold',
  'complex',
  'primer',
] as const;
export type SetKind = (typeof SET_KINDS)[number];

export const REPS_KINDS = [
  'fixed',
  'range',
  'max_unbroken',
  'time',
  'per_side_fixed',
  'per_side_range',
  'per_side_time',
  'complex_unit',
] as const;
export type RepsKind = (typeof REPS_KINDS)[number];

export const COACHING_NOTE_SCOPES = [
  'day',
  'section',
  'group',
  'program',
  'lesson',
  'mesocycle',
  'block',
  'microcycle',
] as const;
export type CoachingNoteScope = (typeof COACHING_NOTE_SCOPES)[number];

export const COACHING_NOTE_KINDS = [
  'focus',
  'loading',
  'effort',
  'lesson',
  'short_on_time',
  'intro',
  'outro',
] as const;
export type CoachingNoteKind = (typeof COACHING_NOTE_KINDS)[number];

export const MOVEMENT_EQUIPMENT = [
  'barbell',
  'db',
  'kb',
  'bodyweight',
  'machine',
  'bands',
  'cable',
  'mixed',
  'sled',
  'plate',
  'rings',
  'specialty',
] as const;
export type MovementEquipment = (typeof MOVEMENT_EQUIPMENT)[number];

export const MOVEMENT_PATTERNS = [
  'squat',
  'hinge',
  'push_horizontal',
  'push_vertical',
  'pull_horizontal',
  'pull_vertical',
  'carry',
  'locomotion',
  'rotation',
  'isometric',
  'complex',
  'jump',
  'olympic',
  'accessory',
] as const;
export type MovementPattern = (typeof MOVEMENT_PATTERNS)[number];

export const MOVEMENT_PLANES = ['sagittal', 'frontal', 'transverse', 'multi'] as const;
export type MovementPlane = (typeof MOVEMENT_PLANES)[number];

export const MEDIA_KINDS = ['video', 'audio', 'image'] as const;
export type MediaKind = (typeof MEDIA_KINDS)[number];

export const MEDIA_PROVIDERS = ['bunny', 'mux', 'sanity'] as const;
export type MediaProvider = (typeof MEDIA_PROVIDERS)[number];

export const ASPECT_RATIOS = ['16:9', '9:16', '1:1', '4:3', '21:9'] as const;
export type AspectRatio = (typeof ASPECT_RATIOS)[number];

export const MOVEMENT_VIDEO_PROVIDERS = ['bunny', 'mux'] as const;
export type MovementVideoProvider = (typeof MOVEMENT_VIDEO_PROVIDERS)[number];

export const MOVEMENT_MEDIA_ROLES = [
  'primary_demo',
  'alternate_angle',
  'tutorial',
  'cue',
  'common_mistake',
  'setup',
  'coach_intro',
] as const;
export type MovementMediaRole = (typeof MOVEMENT_MEDIA_ROLES)[number];

/**
 * Build a SQL `col in ('a','b',...)` predicate suitable for `check()`.
 * Values are inlined as SQL string literals (not bound parameters) because
 * `CHECK` constraints inside `CREATE TABLE` cannot reference parameters when
 * the migration is executed; the Drizzle template tag would otherwise emit
 * `$1, $2, …` placeholders that the migration runner has no values for.
 */
export function inEnum(column: AnyPgColumn, values: readonly string[]): SQL {
  const literals = values.map((v) =>
    sql.raw(`'${v.replaceAll("'", "''")}'`),
  );
  return sql`${column} in (${sql.join(literals, sql`, `)})`;
}
