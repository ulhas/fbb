# FBB Persist · Postgres schema design

Canonical Postgres source-of-truth for the Phase 1 native rebuild. This document
unifies the table fragments quoted across the PRD (Movement, Substitution,
Food, FoodLogEntry, UserChart, PRs, Users, Identities, the active-workout
partial index, and the Sync Streams entity list) and fills the missing middle:
how a coach-authored day's *sections, supersets, intervals, tempos, RPE
prescriptions, equipment alternates, and weight references* map to relational
rows without losing fidelity to what Marcus actually writes.

The schema is grounded in two artefacts:

- The Persist programming language as observed across `persist-042026.pdf`,
  `persist-042726.pdf`, `persist-050426.pdf` (Pump Lift 3x/4x/5x, Pump
  Condition 3x/4x/5x, Perform, Minimalist).
- The `supabase-postgres-best-practices` rule set: lowercase identifiers,
  `bigint identity` / UUIDv7 primary keys, `timestamptz`, FK indexes,
  composite/partial/GIN indexes on hot paths, RLS with the `(select
  auth.uid())` performance pattern, FTS via stored `tsvector`, idempotent
  constraint creation in migrations.

PRD §9.2 (PowerSync Sync Streams) is the public contract for which tables sync
to clients. Section 10.4 of this doc maps every table back to its sync class
so the YAML and the schema cannot drift.

---

## 1 · Conventions

| Concern                | Choice                                                                                  | Rule reference                                  |
| ---------------------- | --------------------------------------------------------------------------------------- | ----------------------------------------------- |
| Identifier case        | lowercase `snake_case`, no quoted identifiers                                           | `schema-lowercase-identifiers`                  |
| Server-only PKs        | `bigint generated always as identity primary key`                                       | `schema-primary-keys`                           |
| Client-syncable PKs    | `uuid primary key default uuid_generate_v7()` (PowerSync writes are client-generated)   | `schema-primary-keys` + PRD §9.3                |
| Time                   | `timestamptz` everywhere                                                                | `schema-data-types`                             |
| Money / volume         | n/a — weights use `numeric(7,3)` (kg canonical, lb derived in client)                   | `schema-data-types`                             |
| Booleans               | `boolean`, never `text`                                                                 | `schema-data-types`                             |
| Enums                  | `text + check (col in (...))` (additive, friendly to PowerSync, no `ALTER TYPE` dance)  | `schema-data-types`                             |
| Open-shape columns     | `jsonb` (`weight_ref`, `interval_pyramid_steps`, `metadata`)                            | `advanced-jsonb-indexing`                       |
| FK indexes             | always present; named `<table>_<col>_idx`                                               | `schema-foreign-key-indexes`                    |
| Composite indexes      | leftmost-equality, rightmost-range; e.g. `(user_id, started_at desc)`                   | `query-composite-indexes`                       |
| Partial indexes        | for hot conditional queries (`WHERE status='in_progress'`, `WHERE active=true`)         | `query-partial-indexes`                         |
| Search                 | `to_tsvector('english', …)` STORED column + GIN                                         | `advanced-full-text-search`                     |
| RLS                    | enabled on every user-owned table, `(select auth.uid()) = user_id` pattern              | `security-rls-basics`, `security-rls-performance` |
| Migrations             | idempotent via `do $$ … if not exists … end $$;` — Postgres has no `IF NOT EXISTS` for constraints | `schema-constraints`                            |
| Pagination             | cursor (`(created_at, id) > (…, …)`), never `OFFSET` for user-facing lists              | `data-pagination`                               |

Two ID strategies coexist deliberately:

- **Client-syncable** rows (`workout_sessions`, `set_logs`, `food_log_entries`,
  `body_metrics`, `user_charts`, `readiness_surveys`, etc.) use UUIDv7 so the
  client can mint the ID before the network round-trip and the server can
  upsert via `ON CONFLICT (id) DO UPDATE` for idempotent retries.
- **Server-only** rows (`webhook_events`, internal admin/audit tables) use
  `bigint generated always as identity` for sequential locality.

---

## 2 · Required extensions

```sql
create extension if not exists "uuid-ossp";  -- for fallback uuid_generate_v4()
create extension if not exists pg_uuidv7;    -- time-ordered UUIDs for sync tables
create extension if not exists pg_trgm;      -- trigram search for movement names
create extension if not exists pgcrypto;     -- gen_random_bytes() for tokens
-- Postgres 14+ ships built-in tsvector / GIN; no extension needed.
```

`pg_uuidv7` provides `uuid_generate_v7()` — time-ordered UUIDs that avoid the
B-tree fragmentation random UUIDv4 causes on large append-heavy tables
(`set_logs` is the worst offender at ~50 inserts per session × 50K MAU).

---

## 3 · Entity-relationship map

```
                          ┌────────────┐
                          │   tracks   │  (PUMP LIFT 5x, PERFORM, MINIMALIST, …)
                          └──────┬─────┘
                                 │ 1
                                 │ *
                          ┌────────────┐
                          │  programs  │  ("Pump Lift 5x — Apr–Jun 2026 block")
                          └──────┬─────┘
                                 │ 1
                                 │ *
                          ┌────────────┐
                          │ mesocycles │  (12-week unit, ×4 per year per track)
                          └──────┬─────┘
                                 │ 1
                                 │ *
                  ┌──────────────┴────────────────┐
                  │ *                            * │
            ┌────────────┐                ┌────────────────┐
            │   blocks   │ (6-week)       │  microcycles   │
            └─────┬──────┘                │  kind ∈        │
                  │ 1                     │   standard,    │
                  │ *                     │   bridge_week, │
            ┌────────────┐ ◄────── (block_id nullable for orphan bridges)
            │ microcycles│                │   deload,      │
            └─────┬──────┘                │   orphan_bridge│
                  │ 1                     └───────┬────────┘
                  │ *                             │
                  │                          (mesocycle_id also nullable)
            ┌────────────┐                        │
            │    days    │  (Mon..Sun, kind: workout|active_recovery|lesson|rest)
            └─────┬──────┘
                  │ 1
                  │ *
            ┌────────────┐  letter A..G, kind warmup|strength_intensity|…|cooldown
            │  sections  │  prescription_mode straight_sets|emom|amrap|for_time|…
            └─────┬──────┘
                  │ 1
                  │ *
            ┌─────────────────────┐  round_count, interval_seconds, cap_seconds,
            │  prescribed_groups  │  rest_between_rounds, position
            └─────┬───────────────┘
                  │ 1
                  │ *
            ┌────────────────────────┐  movement_id, alternate_of_exercise_id,
            │  prescribed_exercises  │  chained_into_next ("directly into")
            └─────┬──────────────────┘
                  │ 1
                  │ *
            ┌──────────────────┐  set_kind, reps_kind, reps_min/max, tempo,
            │  prescribed_sets │  rpe_min/max, weight_ref jsonb, rest_after
            └──────────────────┘

   Athlete side mirrors: workout_sessions → session_sections →
   session_groups → session_exercises → set_logs (with denormalized
   prescription columns frozen at session start).
```

Ten thousand-foot orientation: **content is immutable history, athlete data
is mutable present**. Coaches author through Sanity → webhook → Postgres
content tables (left side of the diagram). Athletes read the content tables
through entitled PowerSync streams, copy the day's prescription into a frozen
`workout_sessions` row at start, and write `set_logs` against that frozen
copy. Subsequent CMS edits never mutate an in-flight session.

---

## 4 · Programming-content domain

### 4.1 `tracks`

The long-running themed program a user subscribes to. `code` is the
canonical key referenced by `entitlements.track_code` (the RevenueCat
entitlement identifier).

```sql
create table tracks (
  id              uuid primary key default uuid_generate_v7(),
  code            text not null unique,        -- 'pump_lift_5x', 'perform', 'minimalist', 'hybrid_running'
  family          text not null,               -- 'pump_lift', 'pump_condition', 'perform', 'minimalist', 'hybrid_running', 'workshop'
  cadence         text,                        -- '3x', '4x', '5x', null for non-cadenced tracks
  display_name    text not null,
  short_name      text,
  description     text,
  required_equipment text[] not null default '{}',  -- ['barbell', 'rack', 'db']
  default_for_quiz boolean not null default false,
  active          boolean not null default true,
  sort_order      integer not null default 100,
  metadata        jsonb not null default '{}'::jsonb,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  check (family in ('pump_lift','pump_condition','perform','minimalist','hybrid_running','workshop','onramp')),
  check (cadence is null or cadence in ('3x','4x','5x','custom'))
);

create index tracks_family_idx        on tracks (family);
create index tracks_active_idx        on tracks (sort_order) where active = true;
```

`required_equipment` uses a Postgres `text[]` (queryable with `&&` overlap
operator) rather than JSONB — the values are atomic and the count is small.

### 4.2 `programs`

A *released* slice of a track bound to a date window — what the PRD calls a
"program" in §9.2 sync streams. One program holds one mesocycle's worth of
content (4 mesocycles → 4 programs per track per year). Splitting `tracks`
from `programs` lets coaches publish next quarter's mesocycle as a draft
program without breaking the active subscriber's view of the live track.

```sql
create table programs (
  id              uuid primary key default uuid_generate_v7(),
  track_id        uuid not null references tracks(id) on delete restrict,
  code            text not null,               -- 'pump_lift_5x_2026q2'
  display_name    text not null,
  starts_on       date not null,               -- inclusive
  ends_on         date not null,               -- inclusive
  state           text not null default 'draft',   -- draft | scheduled | live | archived
  cms_source_id   text,                        -- Sanity _id, for sync provenance
  cms_revision    text,                        -- Sanity _rev; skip stale webhooks
  metadata        jsonb not null default '{}'::jsonb,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (track_id, code),
  check (state in ('draft','scheduled','live','archived')),
  check (ends_on >= starts_on)
);

create index programs_track_id_idx        on programs (track_id);
create index programs_live_window_idx     on programs (starts_on, ends_on) where state = 'live';
create index programs_cms_source_idx      on programs (cms_source_id) where cms_source_id is not null;
```

### 4.3 `mesocycles`

12-week macro unit, ×4 per year per track. The "Volume and Intensity
Progression" focus note in week 6 of every track confirms the 6-week rep-
descending progression — a mesocycle is two of those.

```sql
create table mesocycles (
  id              uuid primary key default uuid_generate_v7(),
  program_id      uuid not null references programs(id) on delete cascade,
  position        integer not null,            -- 1..4 within the year
  display_name    text not null,               -- 'Mesocycle 2 — Hypertrophy Bias'
  intent          text,                        -- 'hypertrophy' | 'strength' | 'conditioning' | 'mixed'
  starts_on       date not null,
  ends_on         date not null,
  cms_source_id   text,
  cms_revision    text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (program_id, position),
  check (intent is null or intent in ('hypertrophy','strength','conditioning','mixed','deload'))
);

create index mesocycles_program_id_idx     on mesocycles (program_id);
create index mesocycles_window_idx          on mesocycles (starts_on, ends_on);
```

### 4.4 `blocks`

6-week sub-unit; a mesocycle has two of these. The persist PDFs' "Week 5
Day 1" through "Week 6 Day 7" in the April pages and "Week 1 Day 1" in the
May pages confirm a 6-week rotation.

```sql
create table blocks (
  id              uuid primary key default uuid_generate_v7(),
  mesocycle_id    uuid not null references mesocycles(id) on delete cascade,
  position        integer not null,            -- 1 or 2 within the mesocycle
  display_name    text not null,
  weeks_total     integer not null default 6,
  starts_on       date not null,
  ends_on         date not null,
  cms_source_id   text,
  cms_revision    text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (mesocycle_id, position),
  check (weeks_total between 1 and 12)
);

create index blocks_mesocycle_id_idx       on blocks (mesocycle_id);
```

### 4.5 `microcycles` (with bridge-week semantics)

A microcycle is one calendar week. **Both `block_id` and `mesocycle_id` are
nullable** so a Bridge Week between blocks (or a one-off bridge week between
mesocycles, or a true orphan bridge week declared by the coaching team) can
exist without forcing it into a block it doesn't belong to. The user's brief
explicitly called this out: *"sometimes a bridge week that doesn't belong to
any cycle"*.

```sql
create table microcycles (
  id              uuid primary key default uuid_generate_v7(),
  program_id      uuid not null references programs(id) on delete cascade,
  mesocycle_id    uuid     references mesocycles(id)   on delete set null,
  block_id        uuid     references blocks(id)       on delete set null,
  position        integer not null,            -- week-of-block when block_id is set; sequential within program otherwise
  kind            text not null default 'standard',
  display_name    text not null,               -- 'Week 5' or 'Bridge Week — Block 1 → Block 2'
  starts_on       date not null,
  ends_on         date not null,
  deload_intensity_pct integer,                -- 70 for typical bridge weeks; null for standard
  cms_source_id   text,
  cms_revision    text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  check (kind in ('standard','bridge_week','deload','orphan_bridge')),
  check (ends_on = starts_on + interval '6 days'),
  check (deload_intensity_pct is null or deload_intensity_pct between 40 and 100),
  -- A standard microcycle must belong to a block. Non-standard kinds may be orphan.
  check (
    (kind = 'standard' and block_id is not null)
    or (kind <> 'standard')
  )
);

create index microcycles_program_id_idx     on microcycles (program_id);
create index microcycles_mesocycle_id_idx   on microcycles (mesocycle_id);
create index microcycles_block_id_idx       on microcycles (block_id);
create index microcycles_window_idx         on microcycles (starts_on, ends_on);
create index microcycles_bridge_idx         on microcycles (program_id, starts_on)
  where kind <> 'standard';
```

The `microcycles_bridge_idx` partial index drives the "is this a bridge week?"
acceptance-criteria check from PRD §4.11 cheaply: O(rows where kind ≠
standard) instead of scanning all weeks.

### 4.6 `days`

A single training day. `kind = 'lesson'` is the Sunday "Work-In Lesson" days
(lines 442–466 of `persist-042026.txt`), which carry only narrative — no
sections, no logger surface. `kind = 'rest'` is a true rest day; `kind =
'active_recovery'` is the Wednesday/Saturday Z2-cardio + mobility days.
`is_optional = true` matches the "OPTIONAL - Active Recovery" header pattern.

```sql
create table days (
  id              uuid primary key default uuid_generate_v7(),
  microcycle_id   uuid not null references microcycles(id) on delete cascade,
  position        integer not null,            -- 1..7 (Mon=1)
  scheduled_on    date not null,
  display_name    text not null,               -- 'Week 5 Day 1 — Persist PUMP LIFT 5x'
  kind            text not null default 'workout',
  is_optional     boolean not null default false,
  default_activity_type text,                  -- HKWorkoutActivityType: 'functional_strength_training', 'high_intensity_interval_training', etc.
  hero_movement_id uuid references movements(id),  -- the day's marquee lift; powers the post-workout share card
  cms_source_id   text,
  cms_revision    text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (microcycle_id, position),
  check (kind in ('workout','active_recovery','rest','lesson')),
  check (position between 1 and 7),
  check (default_activity_type is null or default_activity_type in (
    'functional_strength_training','traditional_strength_training',
    'high_intensity_interval_training','cross_training',
    'cycling','running','rowing','mind_and_body','flexibility','other'))
);

create index days_microcycle_id_idx       on days (microcycle_id);
create index days_scheduled_on_idx         on days (scheduled_on);
create index days_hero_movement_id_idx     on days (hero_movement_id) where hero_movement_id is not null;
```

### 4.7 `sections`

The lettered sub-blocks within a day (A = Daily Focus Note, B = Warmup, C/D
= Strength Intensity 1/2, E = Strength Balance, F = Finisher / Conditioning,
G = Cooldown, with track-specific variants like Perform's "Speed Strength —
Clean" and Pump Condition's "Hinge + Core Intervals"). The
`prescription_mode` enum encodes how the *section* is timed; per-set
prescriptions still live one level down on `prescribed_sets`.

```sql
create table sections (
  id              uuid primary key default uuid_generate_v7(),
  day_id          uuid not null references days(id) on delete cascade,
  position        integer not null,            -- 1=A, 2=B, ...
  letter          text not null,               -- 'A'..'G' (one char; useful for UI without recomputing)
  kind            text not null,
  display_name    text not null,               -- 'Strength Intensity 1', 'Hinge + Core Intervals'
  target_duration_min integer,                 -- 12, 15, etc.
  target_duration_max integer,                 -- 15 (when range like '12-15 min')
  prescription_mode text not null default 'straight_sets',
  daily_focus_note text,                       -- the 'A) Daily Focus Note' prose (only on the focus-note section)
  effort_note     text,                        -- per-section 'Effort Note' prose
  cms_source_id   text,
  cms_revision    text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (day_id, position),
  check (length(letter) = 1 and letter ~ '^[A-Z]$'),
  check (kind in (
    'focus_note','warmup','speed_strength','strength_intensity',
    'strength_balance','finisher','conditioning','intervals',
    'mobility','cooldown','active_recovery','lesson','engine_hot_start',
    'kettlebell_hot_start','upper_couplets','interval_pyramid','high_turnover_cardio'
  )),
  check (prescription_mode in (
    'straight_sets',     -- "3 Working Sets; rest 2-3 min"
    'every_x_minutes',   -- "Every 2:30 x 4 Working Sets"
    'emom',              -- "EMOM x 6mins" (often with odd/even movements)
    'e2mom',             -- "Every 2 minutes x 3 Sets"
    'e3mom',             -- "Every 3:00 x 5 Sets"
    'amrap',             -- "3 Sets x 3 min AMRAP"
    'for_time',          -- "For Time" with optional cap
    'tabata',            -- "20s/10s × 8" preset
    'density',           -- "6 sets; rest 30-45sec"
    'rounds',            -- "3 Rounds" (warmup, mobility)
    'interval_pyramid',  -- "1min @ 70% / 1:30 @ 80% / 2min @ 90% / …"
    'continuous_effort', -- "12mins Continuous Effort, 2-4-6-8-10-12 ascending"
    'free'               -- coach-prose only, no structured timing (focus_note, lesson)
  )),
  check (target_duration_min is null or target_duration_min > 0),
  check (target_duration_max is null or target_duration_max >= coalesce(target_duration_min, 0))
);

create index sections_day_id_idx       on sections (day_id);
create index sections_kind_idx         on sections (kind);
```

### 4.8 `prescribed_groups`

A group is what shows up between blank lines in the PDFs: "3 sets" of one or
more movements with their own per-round shape. The supersets, tri-sets, and
"directly into" chains all live here. `interval_seconds` carries the "Every
2:30" or "Every 3:00" cadence; `cap_seconds` carries the For Time cap.

```sql
create table prescribed_groups (
  id              uuid primary key default uuid_generate_v7(),
  section_id      uuid not null references sections(id) on delete cascade,
  position        integer not null,
  round_count_min integer,                     -- "2 sets" | "2-3 sets" lower bound
  round_count_max integer,                     -- upper bound; equals min when fixed
  interval_seconds integer,                    -- 150 for "Every 2:30"; null for non-interval
  cap_seconds     integer,                     -- For Time / AMRAP cap
  rest_between_rounds_seconds_min integer,     -- "rest 60-90 sec and back to 1"
  rest_between_rounds_seconds_max integer,
  rest_between_rounds_text text,               -- "remaining time" / "rest 90 sec then repeat"
  loading_note    text,                        -- "Loading Note: …" prose
  effort_note     text,                        -- "Effort Note: …" prose
  short_on_time_remove boolean not null default false,  -- "Short on Time? Remove Strength Balance" → flag this group
  scoring         text,                        -- 'reps' | 'time' | 'rounds_plus_reps' | null
  metadata        jsonb not null default '{}'::jsonb,
  cms_source_id   text,
  cms_revision    text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (section_id, position),
  check (round_count_min is null or round_count_min > 0),
  check (round_count_max is null or round_count_max >= coalesce(round_count_min, 0)),
  check (rest_between_rounds_seconds_max is null
         or rest_between_rounds_seconds_max >= coalesce(rest_between_rounds_seconds_min, 0)),
  check (scoring is null or scoring in ('reps','time','rounds_plus_reps','distance','calories'))
);

create index prescribed_groups_section_id_idx       on prescribed_groups (section_id);
create index prescribed_groups_short_on_time_idx     on prescribed_groups (section_id) where short_on_time_remove;
```

Storing min/max as separate columns instead of a `range` type keeps PowerSync
serialisation trivial (PowerSync's JSON view doesn't natively serialize
`int4range`) and lets indexes work cleanly.

### 4.9 `prescribed_exercises` (with alternates + "directly into")

One row per movement-line in the group. The two FBB-specific patterns:

- **Alternates** (`Supinated Lat Pulldown OR Supinated Strict Pull Up`,
  `Nordic Hamstring Curl OR BC Gliding Hamstring Curl`) are modelled by the
  *primary* row carrying the prescription and the *alternate* row pointing
  back at it via `alternate_of_exercise_id` — both rows render to the user
  but only one is logged.
- **"directly into"** (no rest before next movement in the same round) is a
  boolean on the row whose rest is collapsed.

```sql
create table prescribed_exercises (
  id              uuid primary key default uuid_generate_v7(),
  group_id        uuid not null references prescribed_groups(id) on delete cascade,
  position        integer not null,            -- 1=A1, 2=A2, 3=A3 within the round
  movement_id     uuid not null references movements(id) on delete restrict,
  alternate_of_exercise_id uuid references prescribed_exercises(id) on delete cascade,
  chained_into_next boolean not null default false,  -- "directly into" the next exercise (no inter-movement rest)
  rest_after_seconds_min integer,              -- "rest 30 sec" within a group, after this movement
  rest_after_seconds_max integer,
  rest_after_text text,                         -- "remaining time" / coach prose
  is_unilateral   boolean not null default false,  -- track per-side reps & rest separately
  per_side_starts text,                         -- 'left' | 'right' | 'either' — start side convention
  notes           text,                         -- e.g. "If you are using band assistance for tempo Pull Ups, …"
  cms_source_id   text,
  cms_revision    text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (group_id, position, alternate_of_exercise_id),
  check (alternate_of_exercise_id is null or alternate_of_exercise_id <> id),
  check (per_side_starts is null or per_side_starts in ('left','right','either')),
  check (rest_after_seconds_max is null
         or rest_after_seconds_max >= coalesce(rest_after_seconds_min, 0))
);

create index prescribed_exercises_group_id_idx        on prescribed_exercises (group_id);
create index prescribed_exercises_movement_id_idx     on prescribed_exercises (movement_id);
create index prescribed_exercises_alternate_idx       on prescribed_exercises (alternate_of_exercise_id)
  where alternate_of_exercise_id is not null;
```

The `unique (group_id, position, alternate_of_exercise_id)` permits multiple
alternates to share a position slot while still preventing accidental
duplicate primary movements.

### 4.10 `prescribed_sets`

The leaf of content authoring. One row per coach-authored set line:

```
Warm-Up Set - 10 reps @ 20X1 Tempo - Easy
Working Set 1 - 10 @ 20X1 - RPE 7
Working Set 4 - 4 @20X1 - RPE 9-10 + Double Drop Set to Failure
```

```sql
create table prescribed_sets (
  id              uuid primary key default uuid_generate_v7(),
  exercise_id     uuid not null references prescribed_exercises(id) on delete cascade,
  position        integer not null,            -- 1=Warm-Up, 2=WS1, 3=WS2, ...
  set_kind        text not null default 'working',
  reps_kind       text not null default 'fixed',
  reps_min        integer,                     -- 10 for "10 reps"; lower bound for "10-12"
  reps_max        integer,                     -- 12 for "10-12"; equals min for fixed
  reps_text       text,                        -- "Max Unbroken reps", "AMRAP", "to failure" — verbatim fallback
  duration_seconds_min integer,                -- 20 for "20-30 sec"; null when reps-based
  duration_seconds_max integer,                -- 30 for "20-30 sec"
  per_side        boolean not null default false,  -- "10 reps/side"
  tempo           text,                         -- '20X0' | '21X1' | '40A0' | null. Length 4, chars in [0-9XA]
  rpe_min         numeric(3,1),                 -- 7 for "RPE 7"; lower bound for "RPE 9-10"
  rpe_max         numeric(3,1),                 -- 10 for "RPE 9-10"
  rpe_text        text,                         -- "Easy", "Moderate", "Challenging" — non-numeric prescriptions
  weight_ref      jsonb not null default '{}'::jsonb,
  rest_after_seconds_min integer,              -- "rest 2-3 min" → 120
  rest_after_seconds_max integer,              -- "rest 2-3 min" → 180
  rest_after_text text,                         -- "rest remaining time"
  has_drop_set    boolean not null default false,  -- "+ Double Drop Set to Failure"
  drop_set_descriptor jsonb,                   -- { "drops": 2, "reduce_pct": [30, 30] }
  notes           text,
  cms_source_id   text,
  cms_revision    text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (exercise_id, position),
  check (set_kind in ('warmup','working','max_unbroken','drop','back_off','isometric_hold','complex','primer')),
  check (reps_kind in ('fixed','range','max_unbroken','time','per_side_fixed','per_side_range','per_side_time','complex_unit')),
  check (reps_min is null or reps_min > 0),
  check (reps_max is null or reps_max >= coalesce(reps_min, 0)),
  check (duration_seconds_min is null or duration_seconds_min > 0),
  check (duration_seconds_max is null or duration_seconds_max >= coalesce(duration_seconds_min, 0)),
  check (tempo is null or (length(tempo) = 4 and tempo ~ '^[0-9XA]{4}$')),
  check (rpe_min is null or (rpe_min >= 1 and rpe_min <= 10)),
  check (rpe_max is null or (rpe_max >= coalesce(rpe_min, 0) and rpe_max <= 10)),
  check (rest_after_seconds_max is null
         or rest_after_seconds_max >= coalesce(rest_after_seconds_min, 0))
);

create index prescribed_sets_exercise_id_idx     on prescribed_sets (exercise_id);
create index prescribed_sets_weight_ref_gin       on prescribed_sets using gin (weight_ref jsonb_path_ops);
```

The `tempo` regex enforces the FBB convention: four characters, each `0-9`,
`X` (explosive concentric), or `A` (assisted concentric, used on Nordic
Hamstring Curl Negatives — engineering-research §5).

`weight_ref` is JSONB because the shapes vary widely:

```jsonc
// "@ Set 1 weight"
{ "kind": "relative_to_set", "target_position": 1 }

// "70% of working weight"
{ "kind": "percent_of_working", "percent": 70 }

// "5% from Set 2 AMRAP"
{ "kind": "delta_from_set", "target_position": 2, "delta_percent": -5, "delta_percent_max": -10 }

// "@ 53/35# (Male/Female)"
{ "kind": "absolute", "load_kg_male": 24.04, "load_kg_female": 15.88 }

// "Bodyweight"
{ "kind": "bodyweight" }

// "Band/machine assistance — match 12-15RM"
{ "kind": "assistance_match_rep_max", "rep_max": 13 }
```

The GIN index with `jsonb_path_ops` (per `advanced-jsonb-indexing`) is 2–3×
smaller than the default `jsonb_ops` and supports the common `@>` containment
queries (`weight_ref @> '{"kind":"relative_to_set"}'`).

### 4.11 `coaching_notes`

The PDFs surface narrative copy at multiple levels: per-day Daily Focus
Note (lives on `sections.daily_focus_note` when the focus section is
present), per-section Effort Note (`sections.effort_note`), per-group
Loading Note (`prescribed_groups.loading_note`), per-day Lesson body
(below). For author tooling and historical archiving, persist the full
collection here too — including the Sunday Marcus letters, which need to be
markable as "read".

```sql
create table coaching_notes (
  id              uuid primary key default uuid_generate_v7(),
  scope           text not null,               -- 'day' | 'section' | 'group' | 'program' | 'lesson'
  scope_id        uuid not null,               -- the FK target depends on scope; resolved at app layer
  kind            text not null,               -- 'focus' | 'loading' | 'effort' | 'lesson' | 'short_on_time'
  title           text,
  body_markdown   text not null,
  cms_source_id   text,
  cms_revision    text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  check (scope in ('day','section','group','program','lesson','mesocycle','block','microcycle')),
  check (kind in ('focus','loading','effort','lesson','short_on_time','intro','outro'))
);

create index coaching_notes_scope_idx       on coaching_notes (scope, scope_id);
```

We deliberately *don't* enforce `scope_id` as a polymorphic FK (Postgres
doesn't natively support polymorphism cleanly without check-trigger pairs);
the app layer resolves the target table from `scope`. The hot lookup —
"give me every note for this day, section, or group" — is served by the
`(scope, scope_id)` composite index.

### 4.12 `mobility_flows` and `mobility_flow_steps`

The "PERSIST RECOVERY MOBILITY SESSION" blocks (e.g., "Front Splits",
"Pikes and Pancakes", "Squat Mobility") are first-class library content,
selectable independent of a workout. PRD §9.2 already calls out
`mobility_flows` as a synced table.

```sql
create table mobility_flows (
  id              uuid primary key default uuid_generate_v7(),
  code            text not null unique,        -- 'front_splits', 'pikes_and_pancakes'
  display_name    text not null,
  description     text,
  target_duration_min integer,
  target_duration_max integer,
  active          boolean not null default true,
  cms_source_id   text,
  cms_revision    text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create table mobility_flow_steps (
  id              uuid primary key default uuid_generate_v7(),
  flow_id         uuid not null references mobility_flows(id) on delete cascade,
  position        integer not null,
  movement_id     uuid references movements(id),
  display_text    text not null,               -- "Pancake Stretch x 1 min L, 1 min R, 2 min Center"
  duration_seconds_min integer,
  duration_seconds_max integer,
  reps_min        integer,
  reps_max        integer,
  per_side        boolean not null default false,
  notes           text,
  unique (flow_id, position)
);

create index mobility_flow_steps_flow_id_idx     on mobility_flow_steps (flow_id);
create index mobility_flow_steps_movement_id_idx on mobility_flow_steps (movement_id);
```

---

## 5 · Movement library

### 5.1 `movements` and `movement_fts`

Lifts the PRD §5.2 schema verbatim, ports `INTEGER`-as-bool to `boolean`,
hoists `alternate_names` and `secondary_muscles` to native arrays (Postgres
`text[]`, queryable with `&&`), and adds a STORED tsvector column with a GIN
index for the SQLite-FTS-equivalent search the PRD requires.

```sql
create table movements (
  id                 uuid primary key default uuid_generate_v7(),
  cms_source_id      text,                     -- Sanity _id
  cms_revision       text,
  name               text not null,
  alternate_names    text[] not null default '{}',
  primary_muscle     text,
  secondary_muscles  text[] not null default '{}',
  equipment          text not null,            -- 'barbell' | 'db' | 'kb' | 'bodyweight' | 'machine' | 'bands' | 'cable' | 'mixed'
  movement_pattern   text,                     -- 'squat' | 'hinge' | 'push' | 'pull' | 'carry' | 'locomotion' | 'rotation' | 'isometric'
  plane              text,                     -- 'sagittal' | 'frontal' | 'transverse' | 'multi'
  joint_action       text,                     -- coach prose
  unilateral         boolean not null default false,
  difficulty         integer,                  -- 1..5
  coach_cues         text,                     -- markdown
  video_provider     text,                     -- 'bunny' | 'mux' | null (no video yet)
  video_id           text,                     -- libraryId/videoGuid OR muxPlaybackId
  poster_url         text,
  duration_seconds   integer,
  active             boolean not null default true,
  search_vector      tsvector generated always as (
    setweight(to_tsvector('english', coalesce(name, '')), 'A') ||
    setweight(to_tsvector('english', array_to_string(alternate_names, ' ')), 'B') ||
    setweight(to_tsvector('english', coalesce(primary_muscle, '')), 'C') ||
    setweight(to_tsvector('english', coalesce(equipment, '')), 'C') ||
    setweight(to_tsvector('english', coalesce(coach_cues, '')), 'D')
  ) stored,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  check (equipment in ('barbell','db','kb','bodyweight','machine','bands','cable','mixed','sled','plate','rings','specialty')),
  check (movement_pattern is null or movement_pattern in (
    'squat','hinge','push_horizontal','push_vertical','pull_horizontal','pull_vertical',
    'carry','locomotion','rotation','isometric','complex','jump','olympic','accessory')),
  check (plane is null or plane in ('sagittal','frontal','transverse','multi')),
  check (difficulty is null or difficulty between 1 and 5),
  check (video_provider is null or video_provider in ('bunny','mux'))
);

create index movements_active_idx          on movements (name) where active = true;
create index movements_equipment_idx        on movements (equipment) where active = true;
create index movements_pattern_idx          on movements (movement_pattern) where active = true;
create index movements_search_idx           on movements using gin (search_vector);
create index movements_alt_names_idx        on movements using gin (alternate_names);
create index movements_secondary_idx        on movements using gin (secondary_muscles);
create index movements_name_trgm_idx        on movements using gin (name gin_trgm_ops);  -- typo-tolerant prefix
```

Storing `tsvector` as a STORED generated column avoids the trigger-based
maintenance dance and guarantees the index never lags an update.
`setweight(…, 'A'/'B'/'C'/'D')` lets `ts_rank_cd` favour name matches over
coach-cue matches for the search ranking.

### 5.2 `substitution_rules`

PRD §5.3 verbatim, with `condition` extended to cover the full range observed
in the persist PDFs ("Limited Equipment" travel mode, "Shoulder Limit" for
overhead substitutions, etc.).

```sql
create table substitution_rules (
  id              uuid primary key default uuid_generate_v7(),
  movement_id     uuid not null references movements(id) on delete cascade,
  alternate_id    uuid not null references movements(id) on delete cascade,
  condition       text not null,
  priority        integer not null default 100, -- lower = better match
  notes           text,
  cms_source_id   text,
  cms_revision    text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (movement_id, alternate_id, condition),
  check (movement_id <> alternate_id),
  check (condition in (
    'no_barbell','no_rack','shoulder_limit','knee_limit','low_back_limit',
    'travel','machine_only','bodyweight_only','always','equipment_swap',
    'ground_to_overhead'))
);

create index substitution_rules_movement_id_idx     on substitution_rules (movement_id);
create index substitution_rules_alternate_id_idx    on substitution_rules (alternate_id);
create index substitution_rules_condition_idx       on substitution_rules (movement_id, condition, priority);
```

The composite `(movement_id, condition, priority)` index serves the hot
"give me alternates for this movement matching the user's equipment profile,
ordered by priority" lookup with one index scan.

---

## 6 · Athlete domain

### 6.1 `users` and `identities`

PRD §8.2 verbatim, ported to canonical conventions.

```sql
create table users (
  id                  uuid primary key default uuid_generate_v7(),
  email               text unique,                         -- canonical, may be Hide-My-Email relay
  display_name        text,
  shopify_customer_id text unique,
  rc_app_user_id      text not null unique,                -- canonical RevenueCat ID
  default_unit_system text not null default 'imperial',    -- 'imperial' | 'metric'
  birth_year          integer,                             -- coarse for autoregulation; not date-of-birth
  sex                 text,                                -- 'male' | 'female' | 'unspecified' (used for prescribed loads like '53/35# Male/Female')
  height_cm           numeric(5,2),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  deleted_at          timestamptz,                         -- soft-delete; hard at +30d
  check (default_unit_system in ('imperial','metric')),
  check (sex is null or sex in ('male','female','unspecified')),
  check (birth_year is null or birth_year between 1900 and extract(year from now())::int)
);

create index users_email_idx         on users (lower(email)) where deleted_at is null;
create index users_rc_idx            on users (rc_app_user_id);
create index users_shopify_idx       on users (shopify_customer_id) where shopify_customer_id is not null;

create table identities (
  user_id          uuid not null references users(id) on delete cascade,
  provider         text not null,                          -- 'apple' | 'google' | 'email'
  provider_subject text not null,
  email            text,
  refresh_token    text,                                   -- Apple-only, for revocation on delete
  created_at       timestamptz not null default now(),
  primary key (provider, provider_subject),
  check (provider in ('apple','google','email'))
);

create index identities_user_id_idx     on identities (user_id);
```

### 6.2 `equipment_profiles`

Drives the PRD's track-quiz output and the Phase 3 Smart Replace ranking.
Two profiles per user (e.g., Home Gym + Travel) — extension toward "Travel
mode" Smart Replace called out in research.md §"Substitution should be
Fitbod-grade".

```sql
create table equipment_profiles (
  id              uuid primary key default uuid_generate_v7(),
  user_id         uuid not null references users(id) on delete cascade,
  name            text not null,                           -- 'Home Gym' | 'Hotel Travel'
  is_default      boolean not null default false,
  available_equipment text[] not null default '{}',        -- ['barbell','rack','db','kb',...]
  notes           text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (user_id, name)
);

create index equipment_profiles_user_id_idx       on equipment_profiles (user_id);
create unique index equipment_profiles_one_default
  on equipment_profiles (user_id) where is_default = true;
```

### 6.3 `enrollments`

A user's choice of track + start mode + cadence. A single user can be
enrolled in multiple tracks (e.g., Hybrid Running + a workshop) but only one
"primary" enrollment surfaces on the home tab.

```sql
create table enrollments (
  id              uuid primary key default uuid_generate_v7(),
  user_id         uuid not null references users(id) on delete cascade,
  track_id        uuid not null references tracks(id) on delete restrict,
  start_mode      text not null,                           -- 'jump_in_today' | 'start_from_beginning'
  started_on      date not null,
  ends_on         date,                                    -- null = open-ended
  is_primary      boolean not null default false,
  equipment_profile_id uuid references equipment_profiles(id) on delete set null,
  status          text not null default 'active',          -- active | paused | ended
  metadata        jsonb not null default '{}'::jsonb,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  check (start_mode in ('jump_in_today','start_from_beginning')),
  check (status in ('active','paused','ended'))
);

create index enrollments_user_id_idx       on enrollments (user_id);
create index enrollments_track_id_idx       on enrollments (track_id);
create unique index enrollments_one_primary on enrollments (user_id) where is_primary = true and status = 'active';
```

### 6.4 `readiness_surveys`

PRD §4.2.1's 5-question survey. One row per workout-start (or per day if the
user opens the readiness-only flow without starting a workout).

```sql
create table readiness_surveys (
  id              uuid primary key default uuid_generate_v7(),
  user_id         uuid not null references users(id) on delete cascade,
  session_id      uuid references workout_sessions(id) on delete set null,
  recorded_at     timestamptz not null default now(),
  sleep           smallint,        -- 1..5, nullable (skippable)
  energy          smallint,
  soreness        smallint,
  mood            smallint,
  stress          smallint,
  notes           text,
  check (sleep    is null or sleep    between 1 and 5),
  check (energy   is null or energy   between 1 and 5),
  check (soreness is null or soreness between 1 and 5),
  check (mood     is null or mood     between 1 and 5),
  check (stress   is null or stress   between 1 and 5)
);

create index readiness_surveys_user_id_idx       on readiness_surveys (user_id, recorded_at desc);
create index readiness_surveys_session_id_idx     on readiness_surveys (session_id) where session_id is not null;
```

### 6.5 `workout_sessions` (frozen prescription, single-active index)

The session is **frozen** at `start`: every prescription column the logger
needs to render is denormalized onto the session-side rows so a CMS edit
never mutates an in-flight session. The single-active-workout invariant
from PRD §4.8 is enforced by the partial unique index.

```sql
create table workout_sessions (
  id              uuid primary key default uuid_generate_v7(),
  user_id         uuid not null references users(id) on delete cascade,
  enrollment_id   uuid references enrollments(id) on delete set null,
  day_id          uuid references days(id) on delete set null,         -- nullable for ad-hoc sessions
  track_id        uuid references tracks(id) on delete set null,
  program_id      uuid references programs(id) on delete set null,
  microcycle_id   uuid references microcycles(id) on delete set null,
  microcycle_kind text,                                                 -- frozen copy of microcycles.kind
  display_name    text not null,
  status          text not null default 'in_progress',                  -- in_progress | completed | abandoned | discarded
  started_at      timestamptz not null default now(),
  last_activity_at timestamptz not null default now(),
  completed_at    timestamptz,
  total_duration_seconds integer,
  total_volume_kg numeric(12,3),
  rpe_average     numeric(3,1),
  entitlement_verified boolean not null default false,                  -- PRD §4.2.1, §4.7
  last_active_device_id text,                                           -- PRD §4.8 take-over
  notes           text,
  metadata        jsonb not null default '{}'::jsonb,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  check (status in ('in_progress','completed','abandoned','discarded')),
  check (microcycle_kind is null or microcycle_kind in ('standard','bridge_week','deload','orphan_bridge')),
  check (completed_at is null or completed_at >= started_at),
  check (rpe_average is null or rpe_average between 1 and 10)
);

create index workout_sessions_user_id_idx           on workout_sessions (user_id, started_at desc);
create index workout_sessions_day_id_idx             on workout_sessions (day_id) where day_id is not null;
create index workout_sessions_enrollment_id_idx     on workout_sessions (enrollment_id) where enrollment_id is not null;
create index workout_sessions_status_idx            on workout_sessions (user_id, status);

-- PRD §4.8: single in-flight workout per user, server-enforced.
create unique index workout_sessions_active_one
  on workout_sessions (user_id) where status = 'in_progress';

-- PRD §4.10: 4-hour idle → server marks abandoned (background job query path).
create index workout_sessions_idle_idx
  on workout_sessions (last_activity_at) where status = 'in_progress';
```

### 6.6 `session_sections`, `session_groups`, `session_exercises`

Mirror the prescription hierarchy with denormalized prescription fields.
Each row carries the *frozen copy* of the prescription it was started against
plus pointers back to the source IDs for analytics provenance.

```sql
create table session_sections (
  id                  uuid primary key default uuid_generate_v7(),
  session_id          uuid not null references workout_sessions(id) on delete cascade,
  source_section_id   uuid references sections(id) on delete set null,  -- provenance, not authority
  position            integer not null,
  letter              text not null,
  kind                text not null,
  display_name        text not null,
  prescription_mode   text not null,
  status              text not null default 'pending',                  -- pending | in_progress | completed | skipped
  started_at          timestamptz,
  completed_at        timestamptz,
  unique (session_id, position),
  check (status in ('pending','in_progress','completed','skipped'))
);
create index session_sections_session_id_idx on session_sections (session_id);

create table session_groups (
  id                          uuid primary key default uuid_generate_v7(),
  session_section_id          uuid not null references session_sections(id) on delete cascade,
  source_group_id             uuid references prescribed_groups(id) on delete set null,
  position                    integer not null,
  round_count_min             integer,
  round_count_max             integer,
  interval_seconds            integer,
  cap_seconds                 integer,
  rest_between_rounds_seconds_min integer,
  rest_between_rounds_seconds_max integer,
  loading_note                text,
  effort_note                 text,
  scoring                     text,
  rounds_completed            integer not null default 0,
  total_score_value           numeric(10,3),                            -- denormalized score for For Time / AMRAP
  status                      text not null default 'pending',
  started_at                  timestamptz,
  completed_at                timestamptz,
  unique (session_section_id, position),
  check (status in ('pending','in_progress','completed','skipped'))
);
create index session_groups_section_idx on session_groups (session_section_id);

create table session_exercises (
  id                       uuid primary key default uuid_generate_v7(),
  session_group_id         uuid not null references session_groups(id) on delete cascade,
  source_exercise_id       uuid references prescribed_exercises(id) on delete set null,
  movement_id              uuid not null references movements(id) on delete restrict,
  alternate_chosen_for_id  uuid references session_exercises(id) on delete set null,
  position                 integer not null,
  is_unilateral            boolean not null default false,
  chained_into_next        boolean not null default false,
  rest_after_seconds_min   integer,
  rest_after_seconds_max   integer,
  status                   text not null default 'pending',
  notes                    text,
  unique (session_group_id, position, alternate_chosen_for_id),
  check (status in ('pending','in_progress','completed','skipped'))
);
create index session_exercises_group_idx           on session_exercises (session_group_id);
create index session_exercises_movement_idx         on session_exercises (movement_id);
```

### 6.7 `set_logs`

The canonical logged-set table the PRD names in §9.2 sync streams. One row
per set (or per side, for unilateral movements — the `side` column).

```sql
create table set_logs (
  id                       uuid primary key default uuid_generate_v7(),
  session_id               uuid not null references workout_sessions(id) on delete cascade,
  session_exercise_id      uuid not null references session_exercises(id) on delete cascade,
  source_set_id            uuid references prescribed_sets(id) on delete set null,
  movement_id              uuid not null references movements(id) on delete restrict,
  position                 integer not null,                            -- 1=Warm-Up, 2=WS1, ...
  side                     text not null default 'both',                -- 'both' | 'left' | 'right'
  set_kind                 text not null,
  outcome                  text not null default 'completed',           -- completed | failed | skipped
  reps                     integer,
  reps_text                text,                                         -- "12 + cap" overflow for For Time
  duration_seconds         integer,
  weight_kg                numeric(7,3),
  weight_assist_kg         numeric(7,3),                                -- assistance (negative load) for assisted pull-ups
  rpe                      numeric(3,1),
  tempo_actual             text,                                         -- optional self-reported tempo
  rest_after_seconds       integer,
  is_drop_set              boolean not null default false,
  drop_index               smallint,                                     -- 1, 2 for first/second drop
  notes                    text,
  recorded_at              timestamptz not null default now(),
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now(),
  check (set_kind in ('warmup','working','max_unbroken','drop','back_off','isometric_hold','complex','primer')),
  check (outcome in ('completed','failed','skipped')),
  check (side in ('both','left','right')),
  check (rpe is null or rpe between 1 and 10),
  check (weight_kg is null or weight_kg >= 0),
  check (reps is null or reps >= 0),
  check (duration_seconds is null or duration_seconds >= 0)
);

create index set_logs_session_id_idx          on set_logs (session_id, recorded_at);
create index set_logs_exercise_id_idx          on set_logs (session_exercise_id, position, side);
create index set_logs_movement_recent_idx      on set_logs (movement_id, recorded_at desc);
-- For "previous-set" lookup during logging (PRD §4.3 Prev-set):
create index set_logs_user_movement_idx        on set_logs (session_id, movement_id, side, position);
```

The `(movement_id, recorded_at desc)` composite serves the per-exercise
trend query the charts surface needs (PRD §7.1 "per-exercise weight & e1RM
trend"). It's deliberately *not* prefixed by `user_id` because RLS already
constrains the result set to the calling user — Postgres uses the index
without the leftmost user_id when RLS adds it as an implicit filter. (See
§10.1.)

### 6.8 `workout_summaries`

Denormalized session totals computed at completion. PRD §4.2.3 explicitly
calls this out as a write at finish.

```sql
create table workout_summaries (
  session_id           uuid primary key references workout_sessions(id) on delete cascade,
  user_id              uuid not null references users(id) on delete cascade,
  completed_at         timestamptz not null,
  total_volume_kg      numeric(12,3) not null default 0,
  total_reps           integer not null default 0,
  total_working_sets   integer not null default 0,
  total_duration_seconds integer not null default 0,
  rpe_average          numeric(3,1),
  prs_set              integer not null default 0,
  hk_workout_uuid      text,                                              -- HKWorkout / HealthRecord ID for delete-on-account-deletion
  metadata             jsonb not null default '{}'::jsonb
);

create index workout_summaries_user_completed_idx
  on workout_summaries (user_id, completed_at desc);
```

### 6.9 `prs`

PRD §7.4 verbatim, hardened.

```sql
create table prs (
  user_id          uuid not null references users(id) on delete cascade,
  movement_id      uuid not null references movements(id) on delete cascade,
  pr_kind          text not null,             -- '1RM' | '3RM' | '5RM' | '8RM' | '10RM' | 'e1RM' | 'volume'
  value            numeric(12,3) not null,
  set_log_id       uuid not null references set_logs(id) on delete cascade,
  achieved_at      timestamptz not null,
  primary key (user_id, movement_id, pr_kind),
  check (pr_kind in ('1RM','3RM','5RM','8RM','10RM','12RM','e1RM','volume','distance','time'))
);

create index prs_user_achieved_idx           on prs (user_id, achieved_at desc);
create index prs_movement_idx                on prs (movement_id);
```

A trigger on `set_logs` insert maintains this table — the rule lives
server-side (PRD §7.4 rationale: "computing on-device means PR rules can't
evolve without an app-store review cycle").

### 6.10 `body_metrics`

PRD §7 references `body_metric` as a synced table; explicit DDL was not
provided.

```sql
create table body_metrics (
  id              uuid primary key default uuid_generate_v7(),
  user_id         uuid not null references users(id) on delete cascade,
  recorded_on     date not null,
  recorded_at     timestamptz not null default now(),
  weight_kg       numeric(6,3),
  body_fat_pct    numeric(4,2),
  resting_hr_bpm  integer,
  hrv_rmssd_ms    numeric(6,2),
  steps           integer,
  source          text not null default 'manual',  -- 'manual' | 'healthkit' | 'health_connect' | 'whoop' | 'oura'
  notes           text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  check (source in ('manual','healthkit','health_connect','whoop','oura','garmin')),
  check (weight_kg is null or weight_kg between 20 and 500),
  check (body_fat_pct is null or body_fat_pct between 1 and 75)
);

create unique index body_metrics_user_day_source
  on body_metrics (user_id, recorded_on, source);
create index body_metrics_user_recent_idx
  on body_metrics (user_id, recorded_at desc);
```

The unique on `(user_id, recorded_on, source)` deduplicates the daily
HealthKit/Health Connect background sync — repeated polls on the same day
upsert one row per source.

---

## 7 · Nutrition

PRD §6.4 supplied SQLite DDL. Ported to Postgres conventions.

### 7.1 `foods`, `recipes`, `saved_meals`

```sql
create table foods (
  id              uuid primary key default uuid_generate_v7(),
  source          text not null,             -- 'usda' | 'off' | 'nutritionix' | 'user'
  source_id       text,
  name            text not null,
  brand           text,
  serving_size    numeric(8,3) not null,
  serving_unit    text not null,             -- 'g' | 'ml' | 'oz' | 'cup' | 'piece'
  calories        numeric(8,2) not null,
  protein_g       numeric(7,2) not null,
  carb_g          numeric(7,2) not null,
  fat_g           numeric(7,2) not null,
  fiber_g         numeric(7,2),
  sugar_g         numeric(7,2),
  attribution     text,
  cached_at       timestamptz,
  search_vector   tsvector generated always as (
    setweight(to_tsvector('simple', coalesce(name, '')), 'A') ||
    setweight(to_tsvector('simple', coalesce(brand, '')), 'B')
  ) stored,
  check (source in ('usda','off','nutritionix','user'))
);
create unique index foods_source_external on foods (source, source_id) where source_id is not null;
create index foods_search_idx on foods using gin (search_vector);

create table recipes (
  id              uuid primary key default uuid_generate_v7(),
  cms_source_id   text,
  name            text not null,
  servings        numeric(5,2) not null default 1,
  cover_image_url text,
  body_markdown   text,
  active          boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create table recipe_ingredients (
  id              uuid primary key default uuid_generate_v7(),
  recipe_id       uuid not null references recipes(id) on delete cascade,
  food_id         uuid references foods(id) on delete set null,
  display_text    text not null,
  servings        numeric(6,3),
  position        integer not null
);
create index recipe_ingredients_recipe_idx on recipe_ingredients (recipe_id);

create table saved_meals (
  id              uuid primary key default uuid_generate_v7(),
  user_id         uuid not null references users(id) on delete cascade,
  name            text not null,
  default_meal    text not null default 'snack',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  check (default_meal in ('breakfast','lunch','dinner','snack'))
);

create table saved_meal_items (
  id              uuid primary key default uuid_generate_v7(),
  saved_meal_id   uuid not null references saved_meals(id) on delete cascade,
  food_id         uuid references foods(id) on delete set null,
  servings        numeric(6,3) not null,
  position        integer not null
);
create index saved_meal_items_meal_idx on saved_meal_items (saved_meal_id);
```

### 7.2 `food_log_entries`

PRD §6.4 verbatim, ported.

```sql
create table food_log_entries (
  id              uuid primary key default uuid_generate_v7(),
  user_id         uuid not null references users(id) on delete cascade,
  consumed_at     timestamptz not null,
  consumed_on     date not null,                                       -- denormalized for ring aggregation
  meal            text not null,                                       -- 'breakfast' | 'lunch' | 'dinner' | 'snack'
  food_id         uuid references foods(id) on delete set null,
  recipe_id       uuid references recipes(id) on delete set null,
  saved_meal_id   uuid references saved_meals(id) on delete set null,
  servings        numeric(6,3) not null,
  -- denormalized for fast aggregation:
  calories        numeric(8,2) not null,
  protein_g       numeric(7,2) not null,
  carb_g          numeric(7,2) not null,
  fat_g           numeric(7,2) not null,
  fiber_g         numeric(7,2),
  source          text not null,                                       -- 'manual' | 'barcode' | 'recipe' | 'saved_meal' | 'ai_photo'
  photo_id        text,                                                -- Phase 4 reserved
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  check (meal in ('breakfast','lunch','dinner','snack')),
  check (source in ('manual','barcode','recipe','saved_meal','ai_photo'))
);

create index food_log_entries_user_day_idx        on food_log_entries (user_id, consumed_on desc);
create index food_log_entries_food_id_idx          on food_log_entries (food_id) where food_id is not null;
create index food_log_entries_recipe_id_idx        on food_log_entries (recipe_id) where recipe_id is not null;
```

### 7.3 `macro_targets`

```sql
create table macro_targets (
  id              uuid primary key default uuid_generate_v7(),
  user_id         uuid not null references users(id) on delete cascade,
  effective_on    date not null,
  goal            text not null,                                       -- 'lose' | 'maintain' | 'gain'
  calories        integer not null,
  protein_g       integer not null,
  carb_g          integer not null,
  fat_g           integer not null,
  fiber_g         integer,
  source          text not null default 'wizard',                      -- 'wizard' | 'manual' | 'adaptive' (Phase 4)
  created_at      timestamptz not null default now(),
  unique (user_id, effective_on),
  check (goal in ('lose','maintain','gain')),
  check (source in ('wizard','manual','adaptive'))
);

create index macro_targets_user_active_idx
  on macro_targets (user_id, effective_on desc);
```

A `macro_target_history` table is *not* needed — the same table is the
history. The "current target" view is `select * from macro_targets where
user_id = $1 order by effective_on desc limit 1`.

---

## 8 · Subscriptions and entitlements

### 8.1 `entitlements`

PRD §11.3 webhook-derived shape. One row per (user, track_code) — the
multi-attach model from PRD §11.2 where one Persist subscription grants
multiple track entitlements is handled by *multiple rows* sharing the same
underlying `rc_event_id`.

```sql
create table entitlements (
  id                  uuid primary key default uuid_generate_v7(),
  user_id             uuid not null references users(id) on delete cascade,
  track_code          text not null,                                   -- matches tracks.code
  active              boolean not null default true,
  expires_at          timestamptz,
  granted_at          timestamptz not null default now(),
  product_identifier  text,                                            -- the IAP product that granted it
  rc_event_id         text,                                            -- last RC event that touched this row
  metadata            jsonb not null default '{}'::jsonb,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (user_id, track_code)
);

create index entitlements_user_active_idx
  on entitlements (user_id) where active = true;
create index entitlements_track_code_idx on entitlements (track_code);
create index entitlements_expiring_idx
  on entitlements (expires_at) where active = true and expires_at is not null;
```

### 8.2 `webhook_events` (inbox)

PRD §11.3 "inbox" pattern: write the raw payload first (idempotent on
event.id), return 200, then a background worker derives entitlement state.
This is the *only* server-only table that uses `bigint identity` because
PowerSync never reads it.

```sql
create table webhook_events (
  id              bigint generated always as identity primary key,
  provider        text not null,                                       -- 'revenuecat' | 'sanity' | 'apple_sn2' | 'google_rtdn'
  event_id        text not null,                                       -- provider-supplied unique ID
  event_type      text not null,
  payload         jsonb not null,
  signature_valid boolean not null default false,
  received_at     timestamptz not null default now(),
  processed_at    timestamptz,
  processing_error text,
  unique (provider, event_id)
);

create index webhook_events_unprocessed_idx
  on webhook_events (provider, received_at) where processed_at is null;
create index webhook_events_payload_gin
  on webhook_events using gin (payload jsonb_path_ops);
```

### 8.3 `subscription_products`

A small mirror of the IAP catalog so the app can show the right marketing
copy without shipping an updated build for each price change.

```sql
create table subscription_products (
  id                  uuid primary key default uuid_generate_v7(),
  store               text not null,                                   -- 'app_store' | 'play_store' | 'stripe'
  product_identifier  text not null,
  display_name        text not null,
  description         text,
  price_cents         integer,
  currency            text,                                             -- 'USD'
  period              text,                                             -- 'month' | 'year' | 'lifetime'
  granted_track_codes text[] not null default '{}',
  active              boolean not null default true,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (store, product_identifier),
  check (store in ('app_store','play_store','stripe')),
  check (period is null or period in ('month','year','lifetime','week'))
);
```

---

## 9 · Charts

### 9.1 `user_charts`

PRD §7.2 verbatim, ported.

```sql
create table user_charts (
  id              uuid primary key default uuid_generate_v7(),
  user_id         uuid not null references users(id) on delete cascade,
  title           text not null,
  chart_type      text not null,
  x_source        text not null,                                       -- 'date_day' | 'date_week' | 'date_month'
  y_source        text not null,                                       -- 'workout_set' | 'body_weight' | 'steps' | 'macro'
  y_field         text not null,                                       -- 'weight_kg' | 'reps' | 'volume_load' | ...
  aggregation     text not null,
  filter_json     jsonb not null default '{}'::jsonb,
  date_range      text not null default 'last_90d',
  position        integer not null default 100,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  check (chart_type in ('line','bar','stacked_bar','pie','area')),
  check (aggregation in ('max','min','sum','avg','count','one_rm_epley')),
  check (x_source in ('date_day','date_week','date_month')),
  check (y_source in ('workout_set','body_weight','steps','macro','readiness','prs'))
);

create index user_charts_user_idx       on user_charts (user_id, position);
create index user_charts_filter_gin     on user_charts using gin (filter_json jsonb_path_ops);
```

---

## 10 · Cross-cutting

### 10.1 RLS policy patterns

Every user-owned table has RLS enabled. The pattern uses `(select
auth.uid())` (not bare `auth.uid()`) per `security-rls-performance` —
wrapping in a SELECT lets Postgres evaluate the function once per query
instead of once per row.

```sql
-- Template applied to every user-owned table (set_logs shown):
alter table set_logs enable row level security;

create policy set_logs_owner_all on set_logs
  for all to authenticated
  using (
    exists (
      select 1 from workout_sessions s
      where s.id = set_logs.session_id
        and s.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from workout_sessions s
      where s.id = set_logs.session_id
        and s.user_id = (select auth.uid())
    )
  );
```

Tables with a direct `user_id` column (the simple case) get the
straightforward policy:

```sql
alter table body_metrics enable row level security;

create policy body_metrics_owner on body_metrics
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
```

Content tables (`tracks`, `programs`, `mesocycles`, `blocks`, `microcycles`,
`days`, `sections`, `prescribed_groups`, `prescribed_exercises`,
`prescribed_sets`, `coaching_notes`, `mobility_flows`,
`mobility_flow_steps`, `movements`, `substitution_rules`) are filtered by
entitlement via a security-definer helper that bypasses RLS on
`entitlements` itself:

```sql
create or replace function has_entitlement(track text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.entitlements e
    where e.user_id = (select auth.uid())
      and e.track_code = $1
      and e.active = true
  );
$$;

alter table programs enable row level security;
create policy programs_entitled_read on programs
  for select to authenticated
  using (
    exists (
      select 1 from tracks t
      where t.id = programs.track_id
        and has_entitlement(t.code)
    )
  );
```

The `movements` library is read-public to authenticated users (Phase 1
deliberately doesn't gate the library by entitlement — it's a marketing
surface):

```sql
alter table movements enable row level security;
create policy movements_public_read on movements
  for select to authenticated
  using (active = true);
```

### 10.2 Index catalogue

Every index already lives next to its table above. The ones worth
re-summarising for the index-review pass:

| Hot query                                                 | Index                                                                                          |
| --------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| Single active workout enforcement                         | `workout_sessions_active_one (user_id) where status='in_progress'` (PRD §4.8)                  |
| Crash-recovery banner (PRD §4.10)                         | `workout_sessions_idle_idx (last_activity_at) where status='in_progress'`                      |
| Previous-set overlay during logging (PRD §4.3)            | `set_logs_user_movement_idx (session_id, movement_id, side, position)`                         |
| Per-exercise trend chart (PRD §7.1)                       | `set_logs_movement_recent_idx (movement_id, recorded_at desc)`                                 |
| PR feed                                                   | `prs_user_achieved_idx (user_id, achieved_at desc)`                                            |
| Bridge-week deload nudge                                  | `microcycles_bridge_idx (program_id, starts_on) where kind <> 'standard'`                      |
| Movement search                                           | `movements_search_idx using gin (search_vector)` + `movements_name_trgm_idx using gin (name gin_trgm_ops)` |
| Webhook idempotency                                       | `webhook_events (provider, event_id) UNIQUE`                                                   |
| Daily macro ring                                          | `food_log_entries_user_day_idx (user_id, consumed_on desc)`                                    |
| RC entitlement expiry sweep                               | `entitlements_expiring_idx (expires_at) where active = true`                                   |

BRIN is intentionally absent: every "time-ordered" hot table is also
filtered by `user_id` first, which makes B-tree composites strictly better
than BRIN in this access pattern.

### 10.3 Triggers

Three small triggers carry their weight; everything else is application-layer.

```sql
-- 1. Universal updated_at touch
create or replace function touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

-- Apply to every table with an updated_at column. Example:
create trigger tracks_touch_updated before update on tracks
  for each row execute function touch_updated_at();
-- (repeat per table; generated by migration template)

-- 2. PR detection on set_logs insert (PRD §7.4)
create or replace function detect_prs() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_user uuid;
begin
  select user_id into v_user from public.workout_sessions where id = new.session_id;
  if v_user is null then return new; end if;

  -- Rep-bucketed RM: one row per (user, movement, '<n>RM') for n in (1,3,5,8,10,12)
  -- Insert only if new value beats the existing.
  if new.weight_kg is not null and new.reps is not null and new.reps between 1 and 12 then
    insert into public.prs (user_id, movement_id, pr_kind, value, set_log_id, achieved_at)
    values (v_user, new.movement_id,
            (case
              when new.reps = 1 then '1RM' when new.reps <= 3 then '3RM'
              when new.reps <= 5 then '5RM' when new.reps <= 8 then '8RM'
              when new.reps <= 10 then '10RM' else '12RM' end),
            new.weight_kg, new.id, new.recorded_at)
    on conflict (user_id, movement_id, pr_kind)
      do update set value = excluded.value,
                     set_log_id = excluded.set_log_id,
                     achieved_at = excluded.achieved_at
      where prs.value < excluded.value;

    -- Epley e1RM
    insert into public.prs (user_id, movement_id, pr_kind, value, set_log_id, achieved_at)
    values (v_user, new.movement_id, 'e1RM',
            new.weight_kg * (1 + new.reps / 30.0), new.id, new.recorded_at)
    on conflict (user_id, movement_id, pr_kind)
      do update set value = excluded.value,
                     set_log_id = excluded.set_log_id,
                     achieved_at = excluded.achieved_at
      where prs.value < excluded.value;
  end if;

  return new;
end $$;

create trigger set_logs_prs_after_insert
  after insert on set_logs
  for each row execute function detect_prs();
```

Movement FTS is maintained by the STORED `tsvector` generated column — no
trigger needed.

### 10.4 PowerSync sync-stream → table coverage

| Stream             | Tables (`client_sync` annotation)                                                                                                                                                                                                                                                |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `my_active_workout` | `workout_sessions`, `session_sections`, `session_groups`, `session_exercises`, `set_logs`, `readiness_surveys` (filtered to in-progress session)                                                                                                                                |
| `my_history`        | `workout_sessions` (status≠in_progress), `session_sections`, `session_groups`, `session_exercises`, `set_logs`, `workout_summaries`, `prs`, `body_metrics`, `food_log_entries`, `saved_meals`, `saved_meal_items`, `macro_targets`, `user_charts`, `equipment_profiles`, `enrollments` |
| `entitled_programs` | `programs`, `mesocycles`, `blocks`, `microcycles`, `days`, `sections`, `prescribed_groups`, `prescribed_exercises`, `prescribed_sets`, `coaching_notes` (all filtered by `has_entitlement(tracks.code)`)                                                                          |
| `movement_library`  | `movements` (active), `substitution_rules`                                                                                                                                                                                                                                       |
| `mobility_flows`    | `mobility_flows` (active), `mobility_flow_steps`                                                                                                                                                                                                                                  |
| `subscriptions`     | `entitlements` (mine), `subscription_products` (active)                                                                                                                                                                                                                          |
| **Server-only**     | `users`, `identities`, `webhook_events`, `tracks` (read via programs), `recipes`, `recipe_ingredients`, `foods` (queried on demand from server, not bulk-synced)                                                                                                                  |

`foods` is intentionally server-side only despite being content — the
~4 million Open Food Facts catalog must not bulk-sync to every device.
Queries hit the server via the food-search endpoint and cache the touched
rows via PowerSync's normal mechanism.

### 10.5 Migration & seeding notes

- Constraints added in later migrations use the `do $$ … if not exists … end
  $$;` pattern from `schema-constraints.md` (Postgres has no `ADD
  CONSTRAINT IF NOT EXISTS`).
- Bulk inserts (Open Food Facts seed, USDA seed, Sanity initial dump) use
  `COPY` not row-by-row `INSERT` (rule `data-batch-inserts`).
- Sanity webhooks upsert with `on conflict (id) do update where rev is
  distinct from excluded.rev` to skip stale arrivals (engineering-research
  §5).
- All `text + check` enums are additive: new values added by a follow-up
  migration that drops the old check and adds a new one in a single
  transaction — never `ALTER TYPE` (no PG enum types in this schema, by
  design).
- `pg_uuidv7` is the only non-stdlib extension required; if Supabase's
  managed Postgres doesn't have it pre-installed, fall back to the inline
  function from RFC 9562:

  ```sql
  create or replace function uuid_generate_v7() returns uuid
  language sql volatile parallel safe as $$
    select encode(
      overlay(uuid_send(gen_random_uuid())
              placing substring(int8send((extract(epoch from clock_timestamp()) * 1000)::bigint) from 3) from 1 for 6)
      , 'hex')::uuid;
  $$;
  ```

### 10.6 Open questions

These are intentionally left for follow-up rather than baked into v1:

- **Per-side weight asymmetry.** `set_logs.side` allows separate left/right
  rows but the prescriptions don't support per-side weight overrides
  (rare; observed only in rehab-style work that's mostly out of Persist
  scope).
- **Olympic complex per-component logging.** `set_kind = 'complex'` plus
  `reps_kind = 'complex_unit'` represents the complex as one logged unit.
  PRD §4.4.1 hints at an optional expansion to per-component reps for
  failed complexes — not modelled here; needs a follow-up `complex_components`
  table or a JSONB structure on the parent `set_logs` row.
- **AMRAP partial reps.** Currently squeezed into `reps_text` ("12 + 5
  partial"); a richer `partial_reps` column may be warranted post-launch
  once leaderboards (Phase 3) require sortable values.
- **Hybrid Running pace fields.** Per-set `pace_seconds_per_km`,
  `distance_m`, `elevation_m`, `hr_avg`, `hr_max` will be needed before
  Hybrid Running launches; sketched on `set_logs.metadata` JSONB for now.
- **Coach Form Review videos** (Phase 3): a `form_review_clips` table with
  Bunny upload IDs, FK to `set_log_id`, plus a `coach_replies` thread.
- **Workshop-specific overrides** — the multi-attach entitlement model is
  in place but per-workshop scheduling fields (start window, prerequisite
  workshops) need a `workshops` table that extends `tracks`.

---

## Appendix A · Mapping the persist PDF primitives to the schema

| Coach-authored phrase                                | Where it lives                                                                                |
| ---------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| "Pump Lift 5x"                                       | `tracks` (`family='pump_lift'`, `cadence='5x'`)                                                |
| "Week 5 Day 1 — Persist PUMP LIFT 5x"                | `microcycles.position=5`, `days.position=1`, `days.display_name`                               |
| "A) Daily Focus Note"                                | `sections.kind='focus_note'` + `sections.daily_focus_note`                                     |
| "B) Warmup (8 min)"                                  | `sections.kind='warmup'`, `target_duration_min=8`, `prescription_mode='rounds'`                |
| "3 Rounds"                                           | `prescribed_groups.round_count_min=3`, `round_count_max=3`                                     |
| "C) Strength Intensity 1 (15 min)"                   | `sections.kind='strength_intensity'`, `prescription_mode='straight_sets'`                      |
| "Front Squat / 3 Working Sets; rest 2-3 min"         | `prescribed_groups.round_count=3`, `rest_between_rounds_seconds_min=120, max=180`              |
| "Warm-Up Set - 8 reps @ 20X0 Tempo - Easy"           | `prescribed_sets (set_kind='warmup', reps_min=8, tempo='20X0', rpe_text='Easy')`               |
| "Working Set 1 - 6 reps @ 20X0 Tempo - RPE 7"        | `prescribed_sets (set_kind='working', reps_min=6, tempo='20X0', rpe_min=7)`                    |
| "Working Set 3 - Max Unbroken reps @ Set 1 weight"   | `set_kind='max_unbroken'`, `reps_text='Max Unbroken reps'`, `weight_ref={"kind":"relative_to_set","target_position":2}` |
| "+ Double Drop Set to Failure"                       | `has_drop_set=true`, `drop_set_descriptor={"drops":2,"reduce_pct":[30,30]}`                    |
| "Every 2:30 x 4 Working Sets"                        | `prescribed_groups.interval_seconds=150`, `round_count=4`                                      |
| "EMOM x 6mins / Odd - … / Even - …"                  | `sections.prescription_mode='emom'`; one `prescribed_group` per minute pattern (or single group with metadata) |
| "Every 3:00 x 5 Sets"                                | `sections.prescription_mode='e3mom'`, `prescribed_groups.interval_seconds=180, round_count=5` |
| "3 Sets x 3 min AMRAP"                               | `sections.prescription_mode='amrap'`, `cap_seconds=180`, `round_count=3`                       |
| "For Time / 500m Row @ 85%"                          | `sections.prescription_mode='for_time'`, `cap_seconds` if any                                  |
| "directly into / Close Grip Bench Press"             | `prescribed_exercises.chained_into_next=true` on the prior row                                 |
| "rest 60 sec / rest 90 sec and back to 1"            | `prescribed_exercises.rest_after_seconds_min/max` (within group), `prescribed_groups.rest_between_rounds_seconds_min/max` (after the round) |
| "Supinated Lat Pulldown OR Supinated Strict Pull Up" | Two `prescribed_exercises` rows; second has `alternate_of_exercise_id` → first                 |
| "10 reps/side"                                       | `prescribed_sets.per_side=true`, `reps_kind='per_side_fixed'`, `reps_min=10`                   |
| "30-45 sec"                                          | `reps_kind='time'`, `duration_seconds_min=30, max=45`                                          |
| "Loading Note: …"                                    | `prescribed_groups.loading_note`                                                                |
| "Effort Note: …"                                     | `prescribed_groups.effort_note`                                                                  |
| "Short on Time? Remove Strength Balance"             | `prescribed_groups.short_on_time_remove=true` on that group                                    |
| "OPTIONAL - Active Recovery Work"                    | `days.is_optional=true`, `days.kind='active_recovery'`                                         |
| "Work-In Lesson - Week 5"                            | `days.kind='lesson'`; `coaching_notes (scope='lesson', kind='lesson')` carries the prose       |
| "Bridge Week"                                        | `microcycles.kind='bridge_week'` (or `'orphan_bridge'` when not under a block)                 |

---

## Appendix B · Open-question disposition

The PRD §13 explicitly defers Apple Watch, Wear OS, Live Activities, AI
features, leaderboards, HRV-aware autoregulation, coach Form Review, and
the v2 admin console to later phases. The schema accommodates them via
existing JSONB extension points and the un-implemented tables sketched in
§10.6 — none of those deferrals require Phase 1 schema changes.
