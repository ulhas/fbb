import { Inject, Injectable } from '@nestjs/common';
import { and, eq, sql } from 'drizzle-orm';
import { WINSTON_MODULE_PROVIDER } from 'nest-winston';
import type { Logger } from 'winston';

import { DatabaseService } from '../../database/database.service';
import { coachingNotes } from '../../database/schema/coaching-notes';
import { days } from '../../database/schema/days';
import { mesocycles } from '../../database/schema/mesocycles';
import { microcycles } from '../../database/schema/microcycles';
import { movements } from '../../database/schema/movements';
import { prescribedExercises } from '../../database/schema/prescribed-exercises';
import { prescribedGroups } from '../../database/schema/prescribed-groups';
import { prescribedSets } from '../../database/schema/prescribed-sets';
import { programs } from '../../database/schema/programs';
import { sections } from '../../database/schema/sections';
import { tracks } from '../../database/schema/tracks';
import type {
  ParsedDay,
  ParsedDocument,
  ParsedExercise,
  ParsedGroup,
  ParsedSection,
  ParsedTrack,
} from '../schemas/parsed-document.schema';
import type { DayChunk, SegmenterResult } from './document.segmenter';

export interface PersistResult {
  trackCount: number;
  microcycleCount: number;
  dayCount: number;
  sectionCount: number;
  groupCount: number;
  exerciseCount: number;
  setCount: number;
  movementCount: number;
}

// Walks the ParsedDocument tree and writes it into the relational schema.
// Each track is wrapped in its own transaction so a single bad track doesn't
// poison the rest of the upload — if you'd rather have all-or-nothing
// semantics, hoist the `tx` to the top-level loop.
//
// Re-upload semantics: if the (program, track-code) microcycle already exists
// for the same source PDF, we delete the old microcycle (cascades through
// days → sections → groups → exercises → sets → coaching_notes) and rebuild
// it. Tracks/programs/mesocycles/movements are upserted, never replaced.
@Injectable()
export class TrainingWeekPersister {
  // Per-upload movement-id cache. `movements` has no unique constraint on
  // name (intentional — admins may legitimately have multiple "Pull Up"
  // entries differing by equipment), so two parallel per-day transactions
  // racing on the same movement name would each SELECT-miss and INSERT,
  // producing duplicates. Routing all upserts through this in-memory cache
  // serialises the SELECT/INSERT for the duration of a single upload.
  // Keyed by lower(name) — equipment is always 'mixed' for parser-created
  // placeholders, so name alone uniquely identifies the row we'd create.
  private readonly movementIdCache = new Map<string, Promise<string>>();

  constructor(
    private readonly database: DatabaseService,
    @Inject(WINSTON_MODULE_PROVIDER) private readonly logger: Logger,
  ) {}

  // Call between uploads to drop the cache. Movements created during a prior
  // upload are still in the DB, so a fresh SELECT will pick them up — the
  // cache only needs to span the parallel-parse window.
  resetMovementCache(): void {
    this.movementIdCache.clear();
  }

  async persist(
    doc: ParsedDocument,
    requestId: string,
  ): Promise<PersistResult> {
    const result: PersistResult = {
      trackCount: 0,
      microcycleCount: 0,
      dayCount: 0,
      sectionCount: 0,
      groupCount: 0,
      exerciseCount: 0,
      setCount: 0,
      movementCount: 0,
    };

    this.logger.info({
      msg: 'persist.start',
      requestId,
      filename: doc.source_filename,
      tracks: doc.tracks.length,
      totalDays: doc.tracks.reduce((s, t) => s + t.days.length, 0),
    });

    for (const track of doc.tracks) {
      const trackStart = Date.now();
      try {
        await this.database.db.transaction(async (tx) => {
          await this.persistTrack(tx, doc, track, result);
        });
        result.trackCount += 1;
        this.logger.info({
          msg: 'persist.track_complete',
          requestId,
          trackCode: track.track_code,
          days: track.days.length,
          durationMs: Date.now() - trackStart,
        });
      } catch (err) {
        this.logger.error({
          msg: 'persist.track_failed',
          requestId,
          trackCode: track.track_code,
          days: track.days.length,
          durationMs: Date.now() - trackStart,
          error: err instanceof Error ? err.message : String(err),
          stack: err instanceof Error ? err.stack?.split('\n').slice(0, 5).join(' | ') : null,
          ...pgErrorFields(err),
        });
        throw err;
      }
    }

    this.logger.info({
      msg: 'persist.complete',
      requestId,
      filename: doc.source_filename,
      ...result,
    });

    return result;
  }

  // ---- Incremental persistence ------------------------------------------
  //
  // Pre-creates tracks/programs/mesocycles/microcycles/days from segmenter
  // output, BEFORE any LLM call, so each successful day-parse can immediately
  // write its sections/groups/exercises/sets without holding up the rest of
  // the upload. Each track is wrapped in its own transaction; if a single
  // track fails, others still land.
  //
  // Returns a `chunkIndex → dayId` map so the orchestrator can route each
  // completed parse to the right day shell. The shells themselves carry only
  // segmenter-known fields (kind, scheduled_on, position, display_name) —
  // the LLM-only fields (sections, coaching_notes) populate via
  // `persistDayContents` as parses come in.
  async prepareShells(
    filename: string,
    seg: Pick<SegmenterResult, 'tracks' | 'chunks'>,
    requestId: string,
  ): Promise<{
    dayIdByChunkIndex: Map<number, string>;
    trackCount: number;
    microcycleCount: number;
    dayCount: number;
  }> {
    const dayIdByChunkIndex = new Map<number, string>();
    let trackCount = 0;
    let microcycleCount = 0;
    let dayCount = 0;

    // Index chunks by track for the per-track transaction.
    const chunksByTrack = new Map<string, Array<{ index: number; chunk: DayChunk }>>();
    seg.chunks.forEach((chunk, index) => {
      const list = chunksByTrack.get(chunk.trackCode) ?? [];
      list.push({ index, chunk });
      chunksByTrack.set(chunk.trackCode, list);
    });

    for (const segTrack of seg.tracks) {
      const ownChunks = chunksByTrack.get(segTrack.trackCode) ?? [];
      const trackForShells = segmenterTrackToParsed(segTrack);
      const trackStart = Date.now();
      try {
        await this.database.db.transaction(async (tx) => {
          const trackId = await this.upsertTrack(tx, trackForShells);
          const programId = await this.upsertProgramForTrack(
            tx,
            trackId,
            trackForShells,
          );
          const mesocycleId = await this.upsertMesocycleIfStandard(
            tx,
            programId,
            trackForShells,
          );

          const microcycleSourceId = `persist-pdf:${filename}#${segTrack.trackCode}`;
          // Idempotency: drop any prior microcycle for this PDF+track.
          // Cascades wipe days/sections/groups/exercises/sets/coaching_notes.
          await tx
            .delete(microcycles)
            .where(eq(microcycles.cmsSourceId, microcycleSourceId));

          const [microcycle] = await tx
            .insert(microcycles)
            .values({
              programId,
              mesocycleId,
              position: segTrack.microcycle.weekPosition ?? 1,
              kind: segTrack.microcycle.kind,
              displayName: segTrack.displayName,
              startsOn: segTrack.microcycle.startsOn,
              endsOn: segTrack.microcycle.endsOn,
              cmsSourceId: microcycleSourceId,
            })
            .returning({ id: microcycles.id });
          microcycleCount += 1;

          // Insert empty day shells. cms_source_id matches what the LLM
          // assembler will compose for the same chunk, so a future replace-
          // by-source-id run lines up.
          for (const { index, chunk } of ownChunks) {
            const [row] = await tx
              .insert(days)
              .values({
                microcycleId: microcycle.id,
                position: chunk.position,
                scheduledOn: chunk.scheduledOn,
                displayName: chunk.displayName,
                kind: chunk.kind,
                isOptional: chunk.isOptional,
                cmsSourceId: `persist-pdf:${filename}#${chunk.trackCode}/${chunk.scheduledOn}`,
              })
              .returning({ id: days.id });
            dayIdByChunkIndex.set(index, row.id);
            dayCount += 1;
          }
        });
        trackCount += 1;
        this.logger.info({
          msg: 'persist.shells_track_complete',
          requestId,
          trackCode: segTrack.trackCode,
          days: ownChunks.length,
          durationMs: Date.now() - trackStart,
        });
      } catch (err) {
        this.logger.error({
          msg: 'persist.shells_track_failed',
          requestId,
          trackCode: segTrack.trackCode,
          days: ownChunks.length,
          durationMs: Date.now() - trackStart,
          error: err instanceof Error ? err.message : String(err),
          stack:
            err instanceof Error
              ? err.stack?.split('\n').slice(0, 5).join(' | ')
              : null,
          ...pgErrorFields(err),
        });
        // Don't throw — let other tracks proceed. Days for this track will
        // simply not appear in `dayIdByChunkIndex`, so the orchestrator skips
        // their per-day persistence.
      }
    }

    this.logger.info({
      msg: 'persist.shells_ready',
      requestId,
      filename,
      trackCount,
      microcycleCount,
      dayCount,
    });

    return { dayIdByChunkIndex, trackCount, microcycleCount, dayCount };
  }

  // Looks up dayIds for a set of chunks by joining microcycles → days. Used
  // by retry: shells were created on the original run, we just need to map
  // each retry chunk back to its existing day row.
  async findDayIds(
    filename: string,
    pairs: Array<{ trackCode: string; position: number; key: number }>,
  ): Promise<Map<number, string>> {
    const out = new Map<number, string>();
    for (const { trackCode, position, key } of pairs) {
      const microSourceId = `persist-pdf:${filename}#${trackCode}`;
      const [mc] = await this.database.db
        .select({ id: microcycles.id })
        .from(microcycles)
        .where(eq(microcycles.cmsSourceId, microSourceId))
        .limit(1);
      if (!mc) continue;
      const [dayRow] = await this.database.db
        .select({ id: days.id })
        .from(days)
        .where(and(eq(days.microcycleId, mc.id), eq(days.position, position)))
        .limit(1);
      if (dayRow) out.set(key, dayRow.id);
    }
    return out;
  }

  // Wipes the contents of a day shell (sections/groups/exercises/sets via
  // cascade, plus coaching_notes scoped to the day). Used before re-running
  // a retried day to keep position-uniques clean if any orphans linger.
  async clearDayContents(dayId: string): Promise<void> {
    await this.database.db.transaction(async (tx) => {
      await tx.delete(sections).where(eq(sections.dayId, dayId));
      await tx
        .delete(coachingNotes)
        .where(and(eq(coachingNotes.scope, 'day'), eq(coachingNotes.scopeId, dayId)));
    });
  }

  // Persists one day's sections/groups/exercises/sets/coaching_notes against
  // a pre-created day shell. Per-day transaction — a single bad day doesn't
  // poison sibling days. Idempotent only insofar as the day shell was just
  // recreated; calling this twice on the same dayId would duplicate rows.
  async persistDayContents(
    dayId: string,
    parsedDay: ParsedDay,
    requestId: string,
  ): Promise<{
    sectionCount: number;
    groupCount: number;
    exerciseCount: number;
    setCount: number;
    movementCount: number;
  }> {
    const counts = {
      sectionCount: 0,
      groupCount: 0,
      exerciseCount: 0,
      setCount: 0,
      movementCount: 0,
    };
    const result: PersistResult = {
      trackCount: 0,
      microcycleCount: 0,
      dayCount: 0,
      ...counts,
    };

    const start = Date.now();
    try {
      await this.database.db.transaction(async (tx) => {
        // Mirror any LLM-derived fields onto the shell (kind may shift from
        // segmenter's guess to the model's classification).
        await tx
          .update(days)
          .set({
            kind: parsedDay.kind,
            isOptional: parsedDay.is_optional,
            displayName: parsedDay.display_name,
            updatedAt: new Date(),
          })
          .where(eq(days.id, dayId));

        for (const note of parsedDay.coaching_notes) {
          await tx.insert(coachingNotes).values({
            scope: 'day',
            scopeId: dayId,
            kind: note.kind,
            title: note.title,
            bodyMarkdown: note.body_markdown,
          });
        }

        for (const section of parsedDay.sections) {
          await this.persistSection(tx, dayId, section, result);
        }
      });
    } catch (err) {
      this.logger.error({
        msg: 'persist.day_failed',
        requestId,
        dayId,
        scheduledOn: parsedDay.scheduled_on,
        error: err instanceof Error ? err.message : String(err),
        stack:
          err instanceof Error
            ? err.stack?.split('\n').slice(0, 5).join(' | ')
            : null,
        ...pgErrorFields(err),
      });
      throw err;
    }

    this.logger.info({
      msg: 'persist.day_complete',
      requestId,
      dayId,
      scheduledOn: parsedDay.scheduled_on,
      sections: result.sectionCount,
      exercises: result.exerciseCount,
      sets: result.setCount,
      durationMs: Date.now() - start,
    });

    return {
      sectionCount: result.sectionCount,
      groupCount: result.groupCount,
      exerciseCount: result.exerciseCount,
      setCount: result.setCount,
      movementCount: result.movementCount,
    };
  }

  // ---- Legacy whole-document path (kept for callers not yet migrated) ----
  private async persistTrack(
    tx: Tx,
    doc: ParsedDocument,
    track: ParsedTrack,
    result: PersistResult,
  ): Promise<void> {
    const trackId = await this.upsertTrack(tx, track);
    const programId = await this.upsertProgramForTrack(tx, trackId, track);
    const mesocycleId = await this.upsertMesocycleIfStandard(
      tx,
      programId,
      track,
    );

    const microcycleSourceId = `persist-pdf:${doc.source_filename}#${track.track_code}`;
    // Idempotency: drop any prior microcycle from this PDF for this track.
    // Cascades wipe days/sections/groups/exercises/sets/coaching_notes.
    await tx.delete(microcycles).where(eq(microcycles.cmsSourceId, microcycleSourceId));

    const [microcycle] = await tx
      .insert(microcycles)
      .values({
        programId,
        mesocycleId,
        position: track.microcycle.week_position ?? 1,
        kind: track.microcycle.kind,
        displayName: this.microcycleDisplayName(track),
        startsOn: track.microcycle.starts_on,
        endsOn: track.microcycle.ends_on,
        cmsSourceId: microcycleSourceId,
      })
      .returning({ id: microcycles.id });
    result.microcycleCount += 1;

    for (const day of track.days) {
      await this.persistDay(tx, microcycle.id, day, result);
    }
  }

  private async persistDay(
    tx: Tx,
    microcycleId: string,
    day: ParsedTrack['days'][number],
    result: PersistResult,
  ): Promise<void> {
    const [dayRow] = await tx
      .insert(days)
      .values({
        microcycleId,
        position: day.position,
        scheduledOn: day.scheduled_on,
        displayName: day.display_name,
        kind: day.kind,
        isOptional: day.is_optional,
        cmsSourceId: day.cms_source_id,
      })
      .returning({ id: days.id });
    result.dayCount += 1;

    for (const note of day.coaching_notes) {
      await tx.insert(coachingNotes).values({
        scope: 'day',
        scopeId: dayRow.id,
        kind: note.kind,
        title: note.title,
        bodyMarkdown: note.body_markdown,
      });
    }

    for (const section of day.sections) {
      await this.persistSection(tx, dayRow.id, section, result);
    }
  }

  private async persistSection(
    tx: Tx,
    dayId: string,
    section: ParsedSection,
    result: PersistResult,
  ): Promise<void> {
    const [sectionRow] = await tx
      .insert(sections)
      .values({
        dayId,
        position: section.position,
        letter: section.letter,
        kind: section.kind,
        displayName: section.display_name,
        targetDurationMin: section.target_duration_min,
        targetDurationMax: section.target_duration_max,
        prescriptionMode: section.prescription_mode,
        dailyFocusNote: section.daily_focus_note,
        effortNote: section.effort_note,
      })
      .returning({ id: sections.id });
    result.sectionCount += 1;

    for (const group of section.groups) {
      await this.persistGroup(tx, sectionRow.id, group, result);
    }
  }

  private async persistGroup(
    tx: Tx,
    sectionId: string,
    group: ParsedGroup,
    result: PersistResult,
  ): Promise<void> {
    const [groupRow] = await tx
      .insert(prescribedGroups)
      .values({
        sectionId,
        position: group.position,
        roundCountMin: group.round_count_min,
        roundCountMax: group.round_count_max,
        intervalSeconds: group.interval_seconds,
        capSeconds: group.cap_seconds,
        restBetweenRoundsSecondsMin: group.rest_between_rounds_seconds_min,
        restBetweenRoundsSecondsMax: group.rest_between_rounds_seconds_max,
        restBetweenRoundsText: group.rest_between_rounds_text,
        loadingNote: group.loading_note,
        effortNote: group.effort_note,
        shortOnTimeRemove: group.short_on_time_remove,
        scoring: group.scoring,
        // Group has no first-class columns for `interval_pyramid_steps` or
        // `progression_text`; both ride in metadata so the read-side can
        // reconstruct the original ParsedGroup shape losslessly.
        metadata: {
          ...(group.interval_pyramid_steps
            ? { interval_pyramid_steps: group.interval_pyramid_steps }
            : {}),
          ...(group.progression_text
            ? { progression_text: group.progression_text }
            : {}),
        },
      })
      .returning({ id: prescribedGroups.id });
    result.groupCount += 1;

    // Two-pass exercise insert so `alternate_of_exercise_id` can resolve to a
    // sibling that's already been written.
    const idByPosition = new Map<number, string>();
    const sortedPrimaries = group.exercises.filter(
      (e) => e.alternate_of_position == null,
    );
    const alternates = group.exercises.filter(
      (e) => e.alternate_of_position != null,
    );

    for (const exercise of sortedPrimaries) {
      const id = await this.persistExercise(
        tx,
        groupRow.id,
        exercise,
        null,
        result,
      );
      idByPosition.set(exercise.position, id);
    }
    for (const exercise of alternates) {
      const altOf = idByPosition.get(exercise.alternate_of_position!);
      if (!altOf) {
        // The primary it references was either out of range or also marked
        // as an alternate — either way it's a parser bug. Skip the insert
        // and let the warning carry the bad data.
        this.logger.warn({
          msg: 'persist.alternate_unresolved',
          groupId: groupRow.id,
          position: exercise.position,
          alternate_of_position: exercise.alternate_of_position,
        });
        continue;
      }
      await this.persistExercise(
        tx,
        groupRow.id,
        exercise,
        altOf,
        result,
      );
    }
  }

  private async persistExercise(
    tx: Tx,
    groupId: string,
    exercise: ParsedExercise,
    alternateOfExerciseId: string | null,
    result: PersistResult,
  ): Promise<string> {
    const movementId = await this.upsertMovement(tx, exercise.movement_display_name, result);

    const [row] = await tx
      .insert(prescribedExercises)
      .values({
        groupId,
        position: exercise.position,
        movementId,
        alternateOfExerciseId,
        chainedIntoNext: exercise.chained_into_next,
        restAfterSecondsMin: exercise.rest_after_seconds_min,
        restAfterSecondsMax: exercise.rest_after_seconds_max,
        restAfterText: exercise.rest_after_text,
        isUnilateral: exercise.is_unilateral,
        perSideStarts: exercise.per_side_starts,
        notes: exercise.notes,
      })
      .returning({ id: prescribedExercises.id });
    result.exerciseCount += 1;

    for (const set of exercise.sets) {
      await tx.insert(prescribedSets).values({
        exerciseId: row.id,
        position: set.position,
        setKind: set.set_kind,
        repsKind: set.reps_kind,
        repsMin: set.reps_min,
        repsMax: set.reps_max,
        repsText: set.reps_text,
        durationSecondsMin: set.duration_seconds_min,
        durationSecondsMax: set.duration_seconds_max,
        perSide: set.per_side,
        tempo: set.tempo,
        rpeMin: set.rpe_min != null ? set.rpe_min.toString() : null,
        rpeMax: set.rpe_max != null ? set.rpe_max.toString() : null,
        rpeText: set.rpe_text,
        weightRef: set.weight_ref,
        restAfterSecondsMin: set.rest_after_seconds_min,
        restAfterSecondsMax: set.rest_after_seconds_max,
        restAfterText: set.rest_after_text,
        hasDropSet: set.has_drop_set,
        dropSetDescriptor: set.drop_set_descriptor,
        notes: set.notes,
      });
      result.setCount += 1;
    }

    return row.id;
  }

  private async upsertTrack(tx: Tx, track: ParsedTrack): Promise<string> {
    const [row] = await tx
      .insert(tracks)
      .values({
        code: track.track_code,
        family: track.family,
        cadence: track.cadence,
        displayName: track.display_name,
      })
      .onConflictDoUpdate({
        target: tracks.code,
        set: {
          family: track.family,
          cadence: track.cadence,
          displayName: track.display_name,
          updatedAt: new Date(),
        },
      })
      .returning({ id: tracks.id });
    return row.id;
  }

  private async upsertProgramForTrack(
    tx: Tx,
    trackId: string,
    track: ParsedTrack,
  ): Promise<string> {
    // One synthetic "auto" program per track holds every microcycle ingested
    // by this admin pipeline. When real program structures are introduced
    // (CMS-authored), microcycles can be reassigned via UPDATE rather than
    // re-imported.
    const programCode = 'auto';
    const existing = await tx
      .select({ id: programs.id })
      .from(programs)
      .where(and(eq(programs.trackId, trackId), eq(programs.code, programCode)))
      .limit(1);

    if (existing[0]) {
      // Stretch program window to cover this microcycle so the
      // programs_dates_check stays satisfied.
      await tx
        .update(programs)
        .set({
          startsOn: sql`least(${programs.startsOn}, ${track.microcycle.starts_on}::date)`,
          endsOn: sql`greatest(${programs.endsOn}, ${track.microcycle.ends_on}::date)`,
          updatedAt: new Date(),
        })
        .where(eq(programs.id, existing[0].id));
      return existing[0].id;
    }

    const [row] = await tx
      .insert(programs)
      .values({
        trackId,
        code: programCode,
        displayName: `Auto Program — ${track.track_code}`,
        startsOn: track.microcycle.starts_on,
        endsOn: track.microcycle.ends_on,
        state: 'draft',
      })
      .returning({ id: programs.id });
    return row.id;
  }

  private async upsertMesocycleIfStandard(
    tx: Tx,
    programId: string,
    track: ParsedTrack,
  ): Promise<string | null> {
    if (track.microcycle.kind !== 'standard') return null;

    // Standard microcycles require a mesocycle (DB check). Use the parser hint
    // if available; otherwise fall back to position 1 — best-effort placement
    // that admins can re-thread later as more weeks land.
    const position = track.microcycle.mesocycle_position_hint ?? 1;
    const existing = await tx
      .select({
        id: mesocycles.id,
        startsOn: mesocycles.startsOn,
        endsOn: mesocycles.endsOn,
      })
      .from(mesocycles)
      .where(and(eq(mesocycles.programId, programId), eq(mesocycles.position, position)))
      .limit(1);

    if (existing[0]) {
      // Stretch the window to cover the new microcycle. mesocycles_dates_check
      // is just ends_on >= starts_on, so any superset is fine.
      await tx
        .update(mesocycles)
        .set({
          startsOn: sql`least(${mesocycles.startsOn}, ${track.microcycle.starts_on}::date)`,
          endsOn: sql`greatest(${mesocycles.endsOn}, ${track.microcycle.ends_on}::date)`,
          updatedAt: new Date(),
        })
        .where(eq(mesocycles.id, existing[0].id));
      return existing[0].id;
    }

    const [row] = await tx
      .insert(mesocycles)
      .values({
        programId,
        position,
        displayName: `Mesocycle ${position} — ${track.track_code}`,
        startsOn: track.microcycle.starts_on,
        endsOn: track.microcycle.ends_on,
      })
      .returning({ id: mesocycles.id });
    return row.id;
  }

  private async upsertMovement(
    _tx: Tx,
    name: string,
    result: PersistResult,
  ): Promise<string> {
    // Cache hit: another concurrent day already kicked off the lookup —
    // share the promise so both end up with the same id. The insert below
    // runs against the root `db` (not the caller's `tx`) and auto-commits,
    // so other in-flight per-day transactions can FK to this movement
    // without waiting for this one's caller to commit.
    const key = name.trim().toLowerCase();
    const cached = this.movementIdCache.get(key);
    if (cached) return cached;

    const promise = this.doUpsertMovement(name, result);
    this.movementIdCache.set(key, promise);
    return promise;
  }

  private async doUpsertMovement(
    name: string,
    result: PersistResult,
  ): Promise<string> {
    // Movements have no name unique constraint (intentional — same name can
    // legitimately differ by equipment), so look up case-insensitively first
    // and only insert on miss. Equipment defaults to 'mixed' for placeholder
    // movements; admins refine these later.
    const db = this.database.db;
    const existing = await db
      .select({ id: movements.id })
      .from(movements)
      .where(sql`lower(${movements.name}) = lower(${name})`)
      .limit(1);
    if (existing[0]) return existing[0].id;

    const [row] = await db
      .insert(movements)
      .values({
        name,
        equipment: 'mixed',
      })
      .returning({ id: movements.id });
    result.movementCount += 1;
    return row.id;
  }

  private microcycleDisplayName(track: ParsedTrack): string {
    const wp = track.microcycle.week_position;
    const base = track.display_name;
    return wp != null ? `${base} — Week ${wp}` : base;
  }
}

// Drizzle's transaction callback receives a typed `tx` proxy that mirrors the
// db type. Aliasing keeps the helper signatures readable.
type Tx = Parameters<
  Parameters<DatabaseService['db']['transaction']>[0]
>[0];

// Drizzle wraps the underlying pg Error in a "Failed query: …" Error, hiding
// the constraint name / sqlstate that actually identifies the failure. The
// pg error sits on `err.cause`. Surface its fields so the log carries enough
// to diagnose without re-running.
function pgErrorFields(err: unknown): Record<string, unknown> {
  if (!(err instanceof Error)) return {};
  const cause = (err as Error & { cause?: unknown }).cause;
  if (!cause || typeof cause !== 'object') return {};
  const c = cause as Record<string, unknown>;
  return {
    pgCode: c.code,
    pgConstraint: c.constraint,
    pgDetail: c.detail,
    pgTable: c.table,
    pgColumn: c.column,
    pgSchema: c.schema,
    pgWhere: c.where,
    pgRoutine: c.routine,
    pgMessage: c.message,
  };
}

// Adapt the segmenter's camelCase track shape to the snake_case ParsedTrack
// shape so the existing upsert helpers (which were written against the LLM
// output) work for shell creation too. Days are intentionally empty —
// shells don't carry day content yet.
function segmenterTrackToParsed(
  t: SegmenterResult['tracks'][number],
): ParsedTrack {
  return {
    track_code: t.trackCode,
    family: t.family,
    cadence: t.cadence,
    display_name: t.displayName,
    microcycle: {
      kind: t.microcycle.kind,
      starts_on: t.microcycle.startsOn,
      ends_on: t.microcycle.endsOn,
      mesocycle_position_hint: t.microcycle.mesocyclePositionHint,
      week_position: t.microcycle.weekPosition,
    },
    days: [],
  };
}
