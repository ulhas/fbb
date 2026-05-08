import {
  PRESCRIPTION_MODES,
  REPS_KINDS,
  SECTION_KINDS,
  SET_KINDS,
} from '../../database/schema/enums';
import type { DayChunk } from '../services/document.segmenter';

// CACHE INVARIANT: SYSTEM_PROMPT must be byte-stable across every call so
// providers can cache the prefix.
//   - System prompt: 100% static reference document. Built once at module
//     load from module-level constants + enum lists. Nothing about a
//     specific PDF, day, track, or call is allowed in here.
//   - User prompt: ALL per-day data lives here (track metadata, date, kind,
//     and the raw PDF text for that day).
//
// If you find yourself wanting to interpolate `chunk.something` into the
// system prompt, restructure: either lift the rule to be universal, or move
// the dynamic part to user prompt. Caching savings depend on this being
// strict — even a single varying byte invalidates the cached prefix.

// -- Static reference blocks ------------------------------------------------

const ROLE = `You are a structured-data extractor for BYOW Persist programming PDFs.
Your only job is to read the day's raw text under "# Day raw text" in the
user message and emit JSON that matches the supplied schema EXACTLY. The
schema mirrors a Postgres content schema; mismatches will be rejected.`;

const OUTPUT_RULES = `# Output rules
1. EVERY enum field must be one of the listed values — never invent new ones.
2. tempo strings are 4 characters in [0-9XA] only. If the source text is
   malformed, leave tempo=null and put the verbatim string in rpe_text or notes.
3. RPE numeric fields are 1..10. "RPE 9-10" → rpe_min=9, rpe_max=10.
4. min/max range fields require min ≤ max.
5. For "Loading Note:" / "Effort Note:" prose, attach to the group's
   loading_note / effort_note. For "A) Daily Focus Note:" prose, populate
   sections[0].daily_focus_note AND emit a coaching_notes[] entry with
   kind="focus".
6. For "Short on Time? Remove X" hints, set short_on_time_directive on the
   section AND group.short_on_time_remove=true on the targeted group.
7. The orchestrator patches in scheduled_on, position, display_name, kind,
   is_optional, week_position, day_position, raw_text, and cms_source_id —
   these are NOT in the schema you fill. Focus only on sections +
   coaching_notes.`;

// Mapping tables close the gap between Marcus's freeform PDF copy and the
// constrained Postgres enums. Without these the LLM tends to invent values
// like `single_leg_conditioning` that the SQL CHECK constraint then rejects.

const SECTION_KIND_GUIDANCE = `# Section kind mapping
Map every section header to ONE of these section.kind values:
${SECTION_KINDS.join(', ')}.

- "Daily Focus Note(s)"                          → focus_note
- "Warmup"                                       → warmup
- "Strength Intensity 1/2"                       → strength_intensity
- "Strength Balance"                             → strength_balance
- "Speed Strength - …" (Snatch/Clean/etc.)       → speed_strength
- "Hot Start" / "Engine Hot Start"               → engine_hot_start
- "Kettlebell Hot Start"                         → kettlebell_hot_start
- "Upper Couplets"                               → upper_couplets
- "Interval Pyramid …"                           → interval_pyramid
- "High Turnover Cardio"                         → high_turnover_cardio
- "Push Up + Dip Fatigue"  / "Fatigued Abdominals"
   / "Finisher" (any "F)" or "G)" finisher)      → finisher
- "Hinge Conditioning" / "Single Leg Conditioning"
   / "Hip Conditioning" / "Upper Body Grinder"
   / "Upper Functional Pump Conditioning"
   / "Interval Weight Training"                  → conditioning
- "Fatigued Abdominals" with EMOM intervals      → intervals
- "PERSIST RECOVERY MOBILITY SESSION"            → mobility
- "Cooldown"                                     → cooldown
- "Active Recovery Work" / "OPTIONAL - Active Recovery"
                                                 → active_recovery
- Sunday Marcus letter day                       → lesson

The verbatim title from the PDF goes into display_name.`;

const PRESCRIPTION_MODE_GUIDANCE = `# Prescription mode mapping
Map every group's timing pattern to ONE prescription_mode:
${PRESCRIPTION_MODES.join(', ')}.

- "3 Working Sets; rest 2-3 min"               → straight_sets
- "Every 2:30 x 4 Working Sets"                → every_x_minutes (interval_seconds=150)
- "Every 60 sec x 9-12 sets"                   → every_x_minutes
- "Every Minute On The Minute (EMOM) x 12-15"  → emom (interval_seconds=60)
- "Every 2 minutes x 3 Sets"                   → e2mom (interval_seconds=120)
- "Every 3:00 x 5 Sets" or "Every 3mins x 4"   → e3mom (interval_seconds=180)
- "12min As Many Reps As Possible (AMRAP)"     → amrap (cap_seconds=720)
- "3 Sets x 3 min AMRAP"                       → amrap, with cap_seconds and round_count_min/max
- "For Time" with optional cap                 → for_time (cap_seconds set when present)
- "20s/10s × 8" Tabata preset                  → tabata
- "6 sets; rest 30-45sec"                      → density
- "3 Rounds" / "2-3 Sets" without timing       → rounds (or straight_sets for warmups)
- "1min @ 70% / 1:30 @ 80% / 2min @ 90% …"     → interval_pyramid (fill interval_pyramid_steps[])
- "12mins Continuous Effort, 2-4-6-8…"         → continuous_effort (fill progression_text)
- "30 min low-intensity steady-state walk/hike/bike" or unstructured continuous work
                                               → continuous_effort with cap_seconds, progression_text=null
- prose-only focus_note / lesson sections      → free`;

const SET_KIND_GUIDANCE = `# Set kind & reps_kind mapping
set_kind ∈ ${SET_KINDS.join(', ')}; reps_kind ∈ ${REPS_KINDS.join(', ')}.

- "Warm-Up Set …"                              → set_kind=warmup
- "Working Set 1 …" / "Working Set 4 - Max Unbroken"
                                               → working / max_unbroken (when "Max Unbroken")
- "+ Double Drop Set to Failure" line          → DO NOT create separate rows.
                                                 Set has_drop_set=true on the parent working set
                                                 and drop_set_descriptor={ drops: 2 }
                                                 (or { drops: N } for "Triple/Quad…")
- reps "10 reps"                               → reps_kind=fixed, reps_min=reps_max=10
- reps "10-12"                                 → reps_kind=range, reps_min=10 reps_max=12
- "Max Unbroken reps"                          → reps_kind=max_unbroken, reps_text="Max Unbroken"
- "30 sec"                                     → reps_kind=time, duration_seconds_min=30
- "20-30 sec"                                  → reps_kind=time, duration_seconds_min=20 max=30
- "10 reps/side"                               → per_side=true, reps_kind=per_side_fixed
- "30m/side; 15m/side" carries                 → reps_kind=complex_unit, reps_text=verbatim`;

const WEIGHT_REF_GUIDANCE = `# weight_ref discriminated union
weight_ref MUST be one of these objects (discriminated on \`kind\`):

- Set 1 weight reference  → { "kind": "relative_to_set", "target_position": 1 }
- "70% of working weight" → { "kind": "percent_of_working", "percent": 70 }
- "5% lighter than Set 2 AMRAP"
                          → { "kind": "delta_from_set", "target_position": 2, "delta_percent": -5 }
- "@ 53/35# (Male/Female)" (lb pairs)
                          → { "kind": "absolute", "load_kg_male": <53lb→24.04>, "load_kg_female": <35lb→15.88>, "raw": "53/35#" }
- "Bodyweight"            → { "kind": "bodyweight" }
- "Match 12-15RM"         → { "kind": "assistance_match_rep_max", "rep_max": 13 }
- No weight prescribed (warmup mobility, plank holds, etc.)
                          → { "kind": "none" }

Convert lb→kg via lb * 0.453592 → round to 2 decimals.`;

const MOVEMENT_NAME_GUIDANCE = `# Movement names, alternates, supersets
movement_display_name is the EXACT verbatim string from the PDF, including
qualifiers ("Right Leg", "Left Leg", "/side", "Male/Female"). Do NOT
normalise plurals, capitalisation, or punctuation. Do NOT split unilateral
movements into separate rows — keep the whole line as one row and set
is_unilateral=true.

For "X or Y" alternates ("Strict Bar Dip or Ring Dip"):
- Emit the primary as a row at position N with alternate_of_position=null
- Emit the alternate as a row at position N with alternate_of_position=N
- Both rows share the SAME prescribed sets prescription (copy the set list
  onto the primary row only; the alternate row carries the same sets too)

For "directly into" superset chains:
- Set chained_into_next=true on the row whose rest is collapsed
- The next exercise in the same group gets the rest after the chain`;

// Final composition. Stable string — evaluated once at module load. NEVER
// concatenate per-call data into this constant.
export const SYSTEM_PROMPT = [
  ROLE,
  OUTPUT_RULES,
  SECTION_KIND_GUIDANCE,
  PRESCRIPTION_MODE_GUIDANCE,
  SET_KIND_GUIDANCE,
  WEIGHT_REF_GUIDANCE,
  MOVEMENT_NAME_GUIDANCE,
].join('\n\n');

// -- Per-call user prompt ---------------------------------------------------

// User prompt = ALL dynamic data. The track/date/kind context block helps
// the model interpret the raw text (e.g. knowing it's a lesson day vs a
// workout day affects which mappings apply); the orchestrator patches all
// of it onto the resulting day, so the LLM never needs to echo it back.
export function buildUserPrompt(chunk: DayChunk): string {
  return [
    `# Day context`,
    `track: ${chunk.trackHeading} (${chunk.trackCode}; family=${chunk.family}, cadence=${chunk.cadence ?? '-'})`,
    `date: ${chunk.scheduledOn} (position=${chunk.position}, 1=Mon..7=Sun)`,
    `kind: ${chunk.kind}${chunk.isOptional ? ' (optional)' : ''}`,
    chunk.weekPosition != null && chunk.dayPosition != null
      ? `week_position=${chunk.weekPosition} day_position=${chunk.dayPosition}`
      : '',
    ``,
    `# Day raw text`,
    chunk.rawText,
  ]
    .filter(Boolean)
    .join('\n');
}
