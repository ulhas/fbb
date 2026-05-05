// Mirrors the API's parsed-document tree so the table and detail pages can
// render strongly-typed data without re-validating. Kept in one file because
// the surface is small and the API is the single source of truth — when the
// API schema changes, this file is the one place to update on the client.

export type TrackFamily =
  | 'pump_lift'
  | 'pump_condition'
  | 'perform'
  | 'minimalist'
  | 'hybrid_running'
  | 'workshop'
  | 'onramp';

export type TrackCadence = '3x' | '4x' | '5x' | 'custom';

export type DayKind = 'workout' | 'active_recovery' | 'rest' | 'lesson';

export type MicrocycleKind =
  | 'standard'
  | 'bridge_week'
  | 'deload'
  | 'orphan_bridge';

// Mirrors the §4.9 weight_ref discriminated union exactly. Each variant only
// declares the fields it carries — the formatter pattern-matches on `kind`
// and gets the right shape without unsafe casts.
export type WeightRef =
  | { kind: 'none' }
  | { kind: 'bodyweight' }
  | { kind: 'absolute'; load_kg_male?: number | null; load_kg_female?: number | null; raw?: string }
  | { kind: 'relative_to_set'; target_position: number }
  | { kind: 'percent_of_working'; percent: number }
  | {
      kind: 'delta_from_set';
      target_position: number;
      delta_percent: number;
      delta_percent_max?: number;
    }
  | { kind: 'assistance_match_rep_max'; rep_max: number };

export interface ParsedSet {
  position: number;
  set_kind: string;
  reps_kind: string;
  reps_min: number | null;
  reps_max: number | null;
  reps_text: string | null;
  duration_seconds_min: number | null;
  duration_seconds_max: number | null;
  per_side: boolean;
  tempo: string | null;
  rpe_min: number | null;
  rpe_max: number | null;
  rpe_text: string | null;
  weight_ref: WeightRef;
  rest_after_seconds_min: number | null;
  rest_after_seconds_max: number | null;
  rest_after_text: string | null;
  has_drop_set: boolean;
  drop_set_descriptor: { drops: number; reduce_pct?: number[] } | null;
  notes: string | null;
}

export interface ParsedExercise {
  position: number;
  movement_display_name: string;
  alternate_of_position: number | null;
  chained_into_next: boolean;
  rest_after_seconds_min: number | null;
  rest_after_seconds_max: number | null;
  rest_after_text: string | null;
  is_unilateral: boolean;
  per_side_starts: 'left' | 'right' | 'either' | null;
  notes: string | null;
  sets: ParsedSet[];
}

export interface ParsedGroup {
  position: number;
  prescription_mode: string;
  round_count_min: number | null;
  round_count_max: number | null;
  interval_seconds: number | null;
  cap_seconds: number | null;
  rest_between_rounds_seconds_min: number | null;
  rest_between_rounds_seconds_max: number | null;
  rest_between_rounds_text: string | null;
  loading_note: string | null;
  effort_note: string | null;
  short_on_time_remove: boolean;
  scoring: string | null;
  interval_pyramid_steps: Array<{
    duration_seconds: number;
    intensity_pct: number | null;
    notes: string | null;
  }> | null;
  progression_text: string | null;
  exercises: ParsedExercise[];
}

export interface ParsedSection {
  position: number;
  letter: string;
  kind: string;
  display_name: string;
  target_duration_min: number | null;
  target_duration_max: number | null;
  prescription_mode: string;
  daily_focus_note: string | null;
  effort_note: string | null;
  short_on_time_directive: string | null;
  groups: ParsedGroup[];
}

export interface ParsedCoachingNote {
  kind: string;
  title: string | null;
  body_markdown: string;
}

export interface ParsedDay {
  scheduled_on: string;
  position: number;
  display_name: string;
  kind: DayKind;
  is_optional: boolean;
  week_position: number | null;
  day_position: number | null;
  raw_text: string;
  cms_source_id: string;
  sections: ParsedSection[];
  coaching_notes: ParsedCoachingNote[];
}

export interface ParsedMicrocycleHint {
  kind: MicrocycleKind;
  starts_on: string;
  ends_on: string;
  mesocycle_position_hint: number | null;
  week_position: number | null;
}

export interface ParsedTrack {
  track_code: string;
  family: TrackFamily;
  cadence: TrackCadence | null;
  display_name: string;
  microcycle: ParsedMicrocycleHint;
  days: ParsedDay[];
}

export interface ParsedDocument {
  source_filename: string;
  week_starts_on: string;
  page_count: number;
  tracks: ParsedTrack[];
}

export interface ParseWarning {
  scope: string;
  locator: string;
  code: string;
  detail: string;
}

export interface ParseMetrics {
  model: string;
  temperature: number;
  extraction_ms: number;
  segmentation_ms: number;
  llm_total_ms: number;
  llm_calls: number;
  tokens_input_total: number;
  tokens_output_total: number;
  tokens_total: number;
  concurrency: number;
}

export interface UploadResponse {
  request_id: string;
  document: ParsedDocument | null;
  parse_warnings: ParseWarning[];
  parse_metrics: ParseMetrics;
  dry_run?: {
    week_starts_on: string | null;
    page_count: number;
    track_count: number;
    day_count: number;
    tracks: Array<{
      track_code: string;
      family: TrackFamily;
      cadence: TrackCadence | null;
      display_name: string;
      day_count: number;
    }>;
    chunks: Array<{
      track_code: string;
      scheduled_on: string;
      position: number;
      kind: DayKind;
      week_position: number | null;
      day_position: number | null;
      raw_text_preview: string;
    }>;
  };
}

// What we persist per upload. Wraps the API response with provenance so the
// list view can render "uploaded N hours ago" without an extra round-trip.
export interface TrainingWeekRecord {
  id: string; // request_id from API
  uploaded_at: string; // ISO timestamp at storage time
  source_filename: string;
  week_starts_on: string;
  document: ParsedDocument | null;
  parse_warnings: ParseWarning[];
  parse_metrics: ParseMetrics;
  dry_run_only: boolean;
}
