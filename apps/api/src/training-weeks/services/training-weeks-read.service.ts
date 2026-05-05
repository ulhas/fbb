import { Injectable } from '@nestjs/common';
import { and, asc, desc, eq, inArray, sql } from 'drizzle-orm';

import { DatabaseService } from '../../database/database.service';
import { coachingNotes } from '../../database/schema/coaching-notes';
import { days } from '../../database/schema/days';
import { microcycles } from '../../database/schema/microcycles';
import { movements } from '../../database/schema/movements';
import { prescribedExercises } from '../../database/schema/prescribed-exercises';
import { prescribedGroups } from '../../database/schema/prescribed-groups';
import { prescribedSets } from '../../database/schema/prescribed-sets';
import { programs } from '../../database/schema/programs';
import { sections } from '../../database/schema/sections';
import { tracks } from '../../database/schema/tracks';
import { uploadJobs } from '../../database/schema/upload-jobs';
import type {
  ParsedCoachingNote,
  ParsedDay,
  ParsedExercise,
  ParsedGroup,
  ParsedSection,
  ParsedSet,
  ParsedTrack,
} from '../schemas/parsed-document.schema';

export interface TrainingWeekSummaryRow {
  week_starts_on: string;
  week_ends_on: string;
  track_count: number;
  day_count: number;
  last_persisted_at: string;
}

export interface TrainingWeekDetailRow {
  week_starts_on: string;
  week_ends_on: string;
  tracks: ParsedTrack[];
  last_persisted_at: string;
  // Most recent succeeded upload-job whose parsed document covers this week.
  // Surfaced so the admin UI knows which job to POST to /upload-jobs/:id/retry
  // for per-day reparse. Null when no upload-job is recoverable (e.g. the
  // week was seeded directly into the relational tables, or jobs were purged).
  last_upload_job_id: string | null;
}

// Reads training-week data out of the relational tables. The persister writes
// the inverse direction; this service is the read-side, returning the same
// `ParsedTrack[]` tree shape so existing renderers keep working without a
// second mapping layer.
@Injectable()
export class TrainingWeeksReadService {
  constructor(private readonly database: DatabaseService) {}

  // Aggregates microcycles by `starts_on`. Each unique date is one training
  // week; counts roll up across all tracks for that week. Newest first.
  async listWeeks(limit = 100): Promise<TrainingWeekSummaryRow[]> {
    const rows = await this.database.db
      .select({
        weekStartsOn: microcycles.startsOn,
        weekEndsOn: microcycles.endsOn,
        trackCount: sql<number>`count(distinct ${programs.trackId})::int`,
        dayCount: sql<number>`count(distinct ${days.id})::int`,
        lastPersistedAt: sql<Date>`max(${microcycles.updatedAt})`,
      })
      .from(microcycles)
      .leftJoin(programs, eq(microcycles.programId, programs.id))
      .leftJoin(days, eq(days.microcycleId, microcycles.id))
      .groupBy(microcycles.startsOn, microcycles.endsOn)
      .orderBy(desc(microcycles.startsOn))
      .limit(limit);

    return rows.map((r) => ({
      week_starts_on: r.weekStartsOn,
      week_ends_on: r.weekEndsOn,
      track_count: r.trackCount,
      day_count: r.dayCount,
      last_persisted_at: new Date(r.lastPersistedAt).toISOString(),
    }));
  }

  // Returns the full tree for one week — every track, every day, every
  // section/group/exercise/set, plus day-scoped coaching notes. Returns null
  // if no microcycles exist for the date.
  async getWeek(weekStartsOn: string): Promise<TrainingWeekDetailRow | null> {
    const microRows = await this.database.db
      .select({
        microcycleId: microcycles.id,
        microcycleKind: microcycles.kind,
        microcycleStartsOn: microcycles.startsOn,
        microcycleEndsOn: microcycles.endsOn,
        microcyclePosition: microcycles.position,
        microcycleUpdatedAt: microcycles.updatedAt,
        trackId: tracks.id,
        trackCode: tracks.code,
        trackFamily: tracks.family,
        trackCadence: tracks.cadence,
        trackDisplayName: tracks.displayName,
      })
      .from(microcycles)
      .innerJoin(programs, eq(microcycles.programId, programs.id))
      .innerJoin(tracks, eq(programs.trackId, tracks.id))
      .where(eq(microcycles.startsOn, weekStartsOn));

    if (microRows.length === 0) return null;

    const dayRows = await this.database.db
      .select()
      .from(days)
      .where(
        inArray(
          days.microcycleId,
          microRows.map((m) => m.microcycleId),
        ),
      )
      .orderBy(asc(days.scheduledOn));

    const dayIds = dayRows.map((d) => d.id);
    const sectionRows = dayIds.length
      ? await this.database.db
          .select()
          .from(sections)
          .where(inArray(sections.dayId, dayIds))
          .orderBy(asc(sections.position))
      : [];

    const sectionIds = sectionRows.map((s) => s.id);
    const groupRows = sectionIds.length
      ? await this.database.db
          .select()
          .from(prescribedGroups)
          .where(inArray(prescribedGroups.sectionId, sectionIds))
          .orderBy(asc(prescribedGroups.position))
      : [];

    const groupIds = groupRows.map((g) => g.id);
    const exerciseRows = groupIds.length
      ? await this.database.db
          .select({
            id: prescribedExercises.id,
            groupId: prescribedExercises.groupId,
            position: prescribedExercises.position,
            alternateOfExerciseId: prescribedExercises.alternateOfExerciseId,
            chainedIntoNext: prescribedExercises.chainedIntoNext,
            restAfterSecondsMin: prescribedExercises.restAfterSecondsMin,
            restAfterSecondsMax: prescribedExercises.restAfterSecondsMax,
            restAfterText: prescribedExercises.restAfterText,
            isUnilateral: prescribedExercises.isUnilateral,
            perSideStarts: prescribedExercises.perSideStarts,
            notes: prescribedExercises.notes,
            movementName: movements.name,
          })
          .from(prescribedExercises)
          .innerJoin(movements, eq(prescribedExercises.movementId, movements.id))
          .where(inArray(prescribedExercises.groupId, groupIds))
          .orderBy(asc(prescribedExercises.position))
      : [];

    const exerciseIds = exerciseRows.map((e) => e.id);
    const setRows = exerciseIds.length
      ? await this.database.db
          .select()
          .from(prescribedSets)
          .where(inArray(prescribedSets.exerciseId, exerciseIds))
          .orderBy(asc(prescribedSets.position))
      : [];

    const dayNoteRows = dayIds.length
      ? await this.database.db
          .select()
          .from(coachingNotes)
          .where(eq(coachingNotes.scope, 'day'))
      : [];
    const dayIdSet = new Set(dayIds);
    const filteredDayNotes = dayNoteRows.filter((n) => dayIdSet.has(n.scopeId));

    // Now stitch the tree together by parent id.
    const setsByExercise = groupBy(setRows, (s) => s.exerciseId);
    const exercisesByGroup = groupBy(exerciseRows, (e) => e.groupId);
    // Exercise primary lookup: position → exercise id, scoped per group, so
    // alternates can resolve their referent's `position` (the parser-output
    // shape uses position references rather than ids).
    const exerciseIdToPosition = new Map<string, number>();
    for (const e of exerciseRows) exerciseIdToPosition.set(e.id, e.position);

    const groupsBySection = groupBy(groupRows, (g) => g.sectionId);
    const sectionsByDay = groupBy(sectionRows, (s) => s.dayId);
    const notesByDay = groupBy(filteredDayNotes, (n) => n.scopeId);
    const daysByMicrocycle = groupBy(dayRows, (d) => d.microcycleId);

    const tracksOut: ParsedTrack[] = microRows.map((m) => {
      const trackDays: ParsedDay[] = (
        daysByMicrocycle.get(m.microcycleId) ?? []
      ).map((d) => ({
        scheduled_on: d.scheduledOn,
        position: d.position,
        display_name: d.displayName,
        kind: d.kind as ParsedDay['kind'],
        is_optional: d.isOptional,
        week_position: m.microcyclePosition,
        day_position: d.position,
        raw_text: '',
        cms_source_id: d.cmsSourceId ?? '',
        coaching_notes: (notesByDay.get(d.id) ?? []).map(
          (n): ParsedCoachingNote => ({
            kind: n.kind as ParsedCoachingNote['kind'],
            title: n.title,
            body_markdown: n.bodyMarkdown,
          }),
        ),
        sections: (sectionsByDay.get(d.id) ?? []).map(
          (s): ParsedSection => ({
            position: s.position,
            letter: s.letter,
            kind: s.kind as ParsedSection['kind'],
            display_name: s.displayName,
            target_duration_min: s.targetDurationMin,
            target_duration_max: s.targetDurationMax,
            prescription_mode: s.prescriptionMode as ParsedSection['prescription_mode'],
            daily_focus_note: s.dailyFocusNote,
            effort_note: s.effortNote,
            short_on_time_directive: null,
            groups: (groupsBySection.get(s.id) ?? []).map((g) =>
              buildGroup(
                g,
                s.prescriptionMode,
                exercisesByGroup,
                setsByExercise,
                exerciseIdToPosition,
              ),
            ),
          }),
        ),
      }));

      return {
        track_code: m.trackCode,
        family: m.trackFamily as ParsedTrack['family'],
        cadence: m.trackCadence as ParsedTrack['cadence'],
        display_name: m.trackDisplayName,
        microcycle: {
          kind: m.microcycleKind as ParsedTrack['microcycle']['kind'],
          starts_on: m.microcycleStartsOn,
          ends_on: m.microcycleEndsOn,
          mesocycle_position_hint: null,
          week_position: m.microcyclePosition,
        },
        days: trackDays,
      };
    });

    const lastPersistedAt = microRows.reduce<Date>((acc, m) => {
      const d = new Date(m.microcycleUpdatedAt);
      return d > acc ? d : acc;
    }, new Date(microRows[0].microcycleUpdatedAt));

    // Latest succeeded upload-job whose parsed document covers this week.
    // We match against `result_payload->document->>week_starts_on` because a
    // job's filename is informational; the document's own week_starts_on is
    // what the persister used to drive the writes.
    const jobRows = await this.database.db
      .select({ id: uploadJobs.id })
      .from(uploadJobs)
      .where(
        and(
          eq(uploadJobs.status, 'succeeded'),
          sql`(${uploadJobs.resultPayload} -> 'document' ->> 'week_starts_on') = ${weekStartsOn}`,
        ),
      )
      .orderBy(desc(uploadJobs.finishedAt))
      .limit(1);

    return {
      week_starts_on: weekStartsOn,
      week_ends_on: microRows[0].microcycleEndsOn,
      tracks: tracksOut,
      last_persisted_at: lastPersistedAt.toISOString(),
      last_upload_job_id: jobRows[0]?.id ?? null,
    };
  }
}

function buildGroup(
  g: typeof prescribedGroups.$inferSelect,
  // `prescribed_groups` has no first-class prescription_mode column — the
  // mode is stored at the section level. We propagate the section's value to
  // every child group so the wire shape stays whole; if a future schema adds
  // a per-group column, this fallback is the floor.
  sectionPrescriptionMode: string,
  exercisesByGroup: Map<string, ExerciseRow[]>,
  setsByExercise: Map<string, (typeof prescribedSets.$inferSelect)[]>,
  exerciseIdToPosition: Map<string, number>,
): ParsedGroup {
  const meta = (g.metadata ?? {}) as {
    interval_pyramid_steps?: ParsedGroup['interval_pyramid_steps'];
    progression_text?: string | null;
  };

  const exRows = exercisesByGroup.get(g.id) ?? [];
  const exercises: ParsedExercise[] = exRows.map((e) => ({
    position: e.position,
    movement_display_name: e.movementName,
    alternate_of_position: e.alternateOfExerciseId
      ? exerciseIdToPosition.get(e.alternateOfExerciseId) ?? null
      : null,
    chained_into_next: e.chainedIntoNext,
    rest_after_seconds_min: e.restAfterSecondsMin,
    rest_after_seconds_max: e.restAfterSecondsMax,
    rest_after_text: e.restAfterText,
    is_unilateral: e.isUnilateral,
    per_side_starts: e.perSideStarts as ParsedExercise['per_side_starts'],
    notes: e.notes,
    sets: (setsByExercise.get(e.id) ?? []).map(
      (s): ParsedSet => ({
        position: s.position,
        set_kind: s.setKind as ParsedSet['set_kind'],
        reps_kind: s.repsKind as ParsedSet['reps_kind'],
        reps_min: s.repsMin,
        reps_max: s.repsMax,
        reps_text: s.repsText,
        duration_seconds_min: s.durationSecondsMin,
        duration_seconds_max: s.durationSecondsMax,
        per_side: s.perSide,
        tempo: s.tempo,
        // Drizzle returns `numeric` columns as strings to preserve precision.
        rpe_min: s.rpeMin != null ? Number(s.rpeMin) : null,
        rpe_max: s.rpeMax != null ? Number(s.rpeMax) : null,
        rpe_text: s.rpeText,
        weight_ref: s.weightRef as ParsedSet['weight_ref'],
        rest_after_seconds_min: s.restAfterSecondsMin,
        rest_after_seconds_max: s.restAfterSecondsMax,
        rest_after_text: s.restAfterText,
        has_drop_set: s.hasDropSet,
        drop_set_descriptor: s.dropSetDescriptor as ParsedSet['drop_set_descriptor'],
        notes: s.notes,
      }),
    ),
  }));

  return {
    position: g.position,
    prescription_mode: sectionPrescriptionMode as ParsedGroup['prescription_mode'],
    round_count_min: g.roundCountMin,
    round_count_max: g.roundCountMax,
    interval_seconds: g.intervalSeconds,
    cap_seconds: g.capSeconds,
    rest_between_rounds_seconds_min: g.restBetweenRoundsSecondsMin,
    rest_between_rounds_seconds_max: g.restBetweenRoundsSecondsMax,
    rest_between_rounds_text: g.restBetweenRoundsText,
    loading_note: g.loadingNote,
    effort_note: g.effortNote,
    short_on_time_remove: g.shortOnTimeRemove,
    scoring: g.scoring as ParsedGroup['scoring'],
    interval_pyramid_steps: meta.interval_pyramid_steps ?? null,
    progression_text: meta.progression_text ?? null,
    exercises,
  };
}

type ExerciseRow = {
  id: string;
  groupId: string;
  position: number;
  alternateOfExerciseId: string | null;
  chainedIntoNext: boolean;
  restAfterSecondsMin: number | null;
  restAfterSecondsMax: number | null;
  restAfterText: string | null;
  isUnilateral: boolean;
  perSideStarts: string | null;
  notes: string | null;
  movementName: string;
};

function groupBy<T, K>(rows: T[], key: (row: T) => K): Map<K, T[]> {
  const out = new Map<K, T[]>();
  for (const row of rows) {
    const k = key(row);
    const list = out.get(k) ?? [];
    list.push(row);
    out.set(k, list);
  }
  return out;
}
