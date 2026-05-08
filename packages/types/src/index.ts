// Single source of truth for the API contract shared by `apps/api` and
// `apps/admin-web`. Type-only — no runtime exports — so consumers of either
// app can depend on this package without pulling in zod, the Nest runtime,
// or any of the parser internals.
//
// Whenever the API's parsed-document Zod schema changes, mirror the change
// here. Aligning by hand (rather than `z.infer`) keeps this package free of a
// runtime dep on zod and lets non-API consumers (mobile apps, dashboards) use
// it without polyfills.

export type TrackFamily =
  | 'pump_lift'
  | 'pump_condition'
  | 'perform'
  | 'minimalist'
  | 'hybrid_running'
  | 'workshop'
  | 'onramp';

export type TrackCadence = '3x' | '4x' | '5x' | 'custom';

export type DayKind =
  | 'workout'
  | 'active_recovery'
  | 'mobility'
  | 'rest'
  | 'lesson';

export type MicrocycleKind =
  | 'standard'
  | 'bridge_week'
  | 'deload'
  | 'orphan_bridge';

// Mirrors §4.9 weight_ref. Each variant declares only the fields it carries —
// formatters pattern-match on `kind`.
export type WeightRef =
  | { kind: 'none' }
  | { kind: 'bodyweight' }
  | {
      kind: 'absolute';
      load_kg_male?: number | null;
      load_kg_female?: number | null;
      raw?: string | null;
    }
  | { kind: 'relative_to_set'; target_position: number }
  | { kind: 'percent_of_working'; percent: number }
  | {
      kind: 'delta_from_set';
      target_position: number;
      delta_percent: number;
      delta_percent_max?: number | null;
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
  drop_set_descriptor: {
    drops: number;
    reduce_pct: number[] | null;
    notes: string | null;
  } | null;
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
  // The full ModelSpec the run actually used (provider + model + effort).
  // Optional so older payloads (pre-multi-provider) still validate.
  model_spec?: ModelSpec;
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

// Async upload envelope — POST /upload returns this immediately, then the
// client long-polls the GET endpoint until `status` reaches a terminal value.
export type UploadJobStatus = 'queued' | 'running' | 'succeeded' | 'failed';

export interface UploadAcceptedResponse {
  job_id: string;
  status: UploadJobStatus;
}

export interface UploadStatusResponse {
  job_id: string;
  status: UploadJobStatus;
  result: UploadResponse | null;
  error: string | null;
  created_at: string;
  started_at: string | null;
  finished_at: string | null;
}

// One row per ISO `week_starts_on` — the natural primary key for a training
// week now that the relational tables are the source of truth. Counts come
// from joining microcycles → days; `last_persisted_at` is the most recent
// `microcycles.updated_at` for the week and tells the UI when this week last
// changed.
export interface UnderparsedDayRef {
  track_code: string;
  scheduled_on: string;
  display_name: string;
}

export interface TrainingWeekSummary {
  week_starts_on: string;
  week_ends_on: string;
  track_count: number;
  day_count: number;
  // Days with at least one prescribed exercise — the numerator of "coverage".
  parsed_day_count: number;
  // Days that should have exercises (workout / active_recovery) but came back
  // empty. The actionable count for the admin's "needs reparse" stripe.
  underparsed_day_count: number;
  // The actual underparsed days (track + date), so the admin "what's broken"
  // popover can list them with one-click navigation. Empty when count == 0.
  underparsed_days: UnderparsedDayRef[];
  // Week position within its mesocycle (1..N). Tracks share this within a
  // calendar week, so it's a single number per row.
  week_position: number | null;
  // 'standard' | 'bridge_week' | 'deload' | 'orphan_bridge' (typed loosely
  // here; the renderer humanizes).
  microcycle_kind: string | null;
  last_persisted_at: string;
}

// Per-day metadata for the week index. Carries `section_count` and
// `exercise_count` so the matrix / day-strip / day-pill renderers can show
// kind chips, counts, and the underparsed indicator without having to fetch
// the day's full content.
export interface TrainingWeekDayMeta {
  scheduled_on: string;
  position: number;
  display_name: string;
  kind: DayKind;
  is_optional: boolean;
  section_count: number;
  exercise_count: number;
}

// Track row in the week index — full microcycle metadata (chips render
// without an extra fetch), lightweight days. Mirrors `ParsedTrack` shape but
// with `TrainingWeekDayMeta[]` instead of `ParsedDay[]`.
export interface TrainingWeekTrackIndex {
  track_code: string;
  family: TrackFamily;
  cadence: TrackCadence | null;
  display_name: string;
  microcycle: ParsedMicrocycleHint;
  days: TrainingWeekDayMeta[];
}

// What `GET /training-weeks/:date` returns. SLIM index — no sections /
// groups / exercises / sets. Day bodies are fetched on-demand via
// `GET /training-weeks/:date/days/:scheduledOn` so this navigation/index
// payload stays small (a few KB) regardless of how many exercises the week
// contains.
export interface TrainingWeekDetail {
  week_starts_on: string;
  week_ends_on: string;
  tracks: TrainingWeekTrackIndex[];
  last_persisted_at: string;
  // Latest succeeded upload-job whose parsed document covers this week.
  // Null when no upload-job is still recoverable. Drives per-day reparse
  // from the admin UI.
  last_upload_job_id: string | null;
}

// One track's day for a given calendar date, with the full
// sections/groups/exercises/sets tree.
export interface TrainingWeekDayCell {
  track: {
    track_code: string;
    family: TrackFamily;
    cadence: TrackCadence | null;
    display_name: string;
    microcycle: ParsedMicrocycleHint;
  };
  day: ParsedDay;
}

// What `GET /training-weeks/:date/days/:scheduledOn` returns — every track's
// day for that calendar date with full content. Track view filters to the
// matching cell; Day view renders them all.
export interface TrainingWeekDayDetail {
  scheduled_on: string;
  cells: TrainingWeekDayCell[];
}

// Upload-job list/detail shapes. These were previously conflated with the
// training-week shapes — they're now their own resource at /upload-jobs.
export interface UploadJobSummary {
  id: string;
  source_filename: string;
  status: UploadJobStatus;
  week_starts_on: string | null;
  track_count: number;
  day_count: number;
  warning_count: number;
  tokens_total: number;
  tokens_input_total: number;
  tokens_output_total: number;
  // ModelSpec the run actually used. Null for older jobs (pre-multi-provider).
  model_spec: ModelSpec | null;
  uploaded_at: string;
  finished_at: string | null;
  error: string | null;
}

export interface UploadJobDetail {
  id: string;
  source_filename: string;
  status: UploadJobStatus;
  uploaded_at: string;
  started_at: string | null;
  finished_at: string | null;
  error: string | null;
  document: ParsedDocument | null;
  parse_warnings: ParseWarning[];
  parse_metrics: ParseMetrics | null;
  dry_run_only: boolean;
}

// Identifies which model to use for the day-parser. Provider determines the
// SDK adapter (openai/anthropic), `model` is the provider-specific model id
// ("gpt-5.5-2026-04-23", "claude-sonnet-4-6", etc.), and reasoning_effort
// only applies to OpenAI's reasoning models (gpt-5/o-series); ignored
// elsewhere. Persisted on each upload-job's parse_metrics so reparse runs
// can be compared.
export type ModelProvider = 'openai' | 'anthropic';

export type ReasoningEffort = 'minimal' | 'low' | 'medium' | 'high';

export interface ModelSpec {
  provider: ModelProvider;
  model: string;
  reasoning_effort?: ReasoningEffort | null;
}

// One row per registered user, surfaced to the admin console at GET /users.
// `active_follow_count` is the number of currently-followed tracks (rows in
// user_track_follows with `unfollowed_at IS NULL`); historical follows are
// reachable via /me/tracks/history but excluded here.
export interface AdminUserRow {
  id: string;
  email: string | null;
  display_name: string | null;
  active_follow_count: number;
  created_at: string;
  updated_at: string;
}
