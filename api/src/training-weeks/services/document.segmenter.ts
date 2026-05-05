import {
  PRESCRIPTION_MODES,
  type DayKind,
  type MicrocycleKind,
  type TrackCadence,
  type TrackFamily,
} from '../../database/schema/enums';
import type { ParseWarning } from '../schemas/parsed-document.schema';
import { __internal, parseToc } from './toc.parser';

const { TRACK_HEADING_REGEX, DAY_LINE_REGEX, WEEK_DAY_REGEX, monthDayYearToIso } =
  __internal;

export interface DayChunk {
  trackCode: string;
  trackHeading: string;
  family: TrackFamily;
  cadence: TrackCadence | null;
  // Calendar-derived from the date heading.
  scheduledOn: string; // ISO YYYY-MM-DD
  position: number; // 1=Mon..7=Sun
  // From the "Week N Day M - Persist X" line; cross-checked against scheduledOn.
  weekPosition: number | null;
  dayPosition: number | null;
  displayName: string; // first non-blank descriptive line ("Week 1 Day 1 - Persist PUMP LIFT 5x")
  kind: DayKind;
  isOptional: boolean;
  rawText: string;
}

export interface SegmenterResult {
  weekStartsOn: string | null;
  // One entry per (track, day) found in the body. Sunday lessons land here too,
  // with `kind: 'lesson'` and minimal section structure expected from the LLM.
  chunks: DayChunk[];
  // Per-track meta extracted from the body (mesocycle hint).
  tracks: Array<{
    trackCode: string;
    trackHeading: string;
    family: TrackFamily;
    cadence: TrackCadence | null;
    displayName: string;
    microcycle: {
      kind: MicrocycleKind;
      startsOn: string;
      endsOn: string;
      weekPosition: number | null;
      mesocyclePositionHint: number | null;
    };
  }>;
  warnings: ParseWarning[];
}

// Map a track heading like "Pump Lift 5x" to a stable `tracks.code` slug and
// pull out family + cadence. The slug feeds `tracks.code` for upserts.
export function classifyTrack(heading: string): {
  trackCode: string;
  family: TrackFamily;
  cadence: TrackCadence | null;
} {
  const lower = heading.trim().toLowerCase();
  const cadenceMatch = lower.match(/\b(3x|4x|5x)\b/);
  const cadence = (cadenceMatch?.[1] ?? null) as TrackCadence | null;
  const familySlug = lower.replace(/\s+(3x|4x|5x)\s*$/, '').replace(/\s+/g, '_');
  const familyMap: Record<string, TrackFamily> = {
    pump_lift: 'pump_lift',
    pump_condition: 'pump_condition',
    perform: 'perform',
    minimalist: 'minimalist',
    hybrid_running: 'hybrid_running',
    workshop: 'workshop',
  };
  const family = familyMap[familySlug] ?? 'pump_lift';
  const trackCode = cadence ? `${familySlug}_${cadence}` : familySlug;
  return { trackCode, family, cadence };
}

const ACTIVE_RECOVERY_REGEX = /Active\s+Recovery/i;
const OPTIONAL_REGEX = /^A\)\s*OPTIONAL\b/i;
const SECTION_LETTER_REGEX = /^[A-G]\)/;
const MARCUS_LETTER_HINT = /^(?:Warmly,|Marcus\s*$)/m;

const POSITION_BY_WEEKDAY: Record<string, number> = {
  Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7,
};

export function segment(fullText: string): SegmenterResult {
  const toc = parseToc(fullText);
  const body = fullText.slice(toc.bodyStartIndex);
  const lines = body.split(/\r?\n/);

  // Pre-pass: strip stray colon-only lines (Apr 20 has them after Warmup).
  // Also collapse a doubled `A)` header where the first instance is just a
  // label (Apr 27 Thursday: `A) Active Recovery Work :` then `A) Active Recovery (40 min)`).
  const cleaned: string[] = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const t = line.trim();
    if (/^[\s:]*$/.test(line) && t === ':') continue;
    cleaned.push(line);
  }

  // Walk to identify track + day blocks. Each block runs from one date heading
  // up to (but excluding) the next date heading or the next track heading.
  type Block = {
    trackHeading: string;
    headerLine: string; // the date line itself
    weekday: string; // "Mon"
    scheduledOn: string;
    bodyLines: string[];
  };
  const blocks: Block[] = [];
  let currentTrack: string | null = null;
  let pending: Block | null = null;

  const pushPending = () => {
    if (pending) blocks.push(pending);
    pending = null;
  };

  for (const rawLine of cleaned) {
    const t = rawLine.trim();
    if (TRACK_HEADING_REGEX.test(t)) {
      pushPending();
      currentTrack = t;
      continue;
    }
    const dayMatch = t.match(DAY_LINE_REGEX);
    if (dayMatch && currentTrack) {
      pushPending();
      const iso = monthDayYearToIso(dayMatch[2], dayMatch[3], dayMatch[4]);
      if (!iso) continue;
      pending = {
        trackHeading: currentTrack,
        headerLine: t,
        weekday: dayMatch[1],
        scheduledOn: iso,
        bodyLines: [],
      };
      continue;
    }
    if (pending) pending.bodyLines.push(rawLine);
  }
  pushPending();

  const warnings: ParseWarning[] = [];
  const chunks: DayChunk[] = [];
  const trackMeta = new Map<string, SegmenterResult['tracks'][number]>();

  for (const b of blocks) {
    const { trackCode, family, cadence } = classifyTrack(b.trackHeading);
    const position = POSITION_BY_WEEKDAY[b.weekday] ?? 1;

    // The displayName is the first non-blank line in the chunk's body —
    // typically "Week 1 Day 1 - Persist PUMP LIFT 5x", possibly followed by a
    // second tag line like "Pump Lift 5x - April" (Apr 20 doc).
    const firstLine = b.bodyLines.find((l) => l.trim().length > 0)?.trim() ?? '';
    const weekDayMatch = firstLine.match(WEEK_DAY_REGEX);
    const weekPosition = weekDayMatch ? parseInt(weekDayMatch[1], 10) : null;
    const dayPosition = weekDayMatch ? parseInt(weekDayMatch[2], 10) : null;

    const dayKind = inferDayKind(b.bodyLines);
    const isOptional = b.bodyLines.some((l) => OPTIONAL_REGEX.test(l.trim()));

    if (dayPosition != null && dayPosition !== position) {
      warnings.push({
        scope: 'day',
        locator: `${trackCode}/${b.scheduledOn}`,
        code: 'week_day_position_mismatch',
        detail: `weekday=${b.weekday} → position=${position} but Week-line says day_position=${dayPosition}`,
      });
    }

    chunks.push({
      trackCode,
      trackHeading: b.trackHeading,
      family,
      cadence,
      scheduledOn: b.scheduledOn,
      position,
      weekPosition,
      dayPosition,
      displayName: firstLine || `${b.headerLine} - ${b.trackHeading}`,
      kind: dayKind,
      isOptional,
      rawText: [b.headerLine, ...b.bodyLines].join('\n').trim(),
    });

    if (!trackMeta.has(trackCode)) {
      trackMeta.set(trackCode, {
        trackCode,
        trackHeading: b.trackHeading,
        family,
        cadence,
        displayName: b.trackHeading,
        microcycle: {
          kind: 'standard',
          startsOn: isoMonday(b.scheduledOn, position),
          endsOn: isoMonday(b.scheduledOn, position, 6),
          weekPosition,
          mesocyclePositionHint: weekPosition,
        },
      });
    }
  }

  // Apr 27 PDF has a Perform Sunday entry duplicated in the body (one empty
  // header followed by another with the full Marcus letter). Coach duplication
  // artifact — when we see the same (trackCode, scheduledOn), keep the row
  // with the longer rawText and surface a warning so the human reviewer knows.
  const deduped: DayChunk[] = [];
  const seen = new Map<string, number>(); // key → index in deduped
  for (const chunk of chunks) {
    const key = `${chunk.trackCode}/${chunk.scheduledOn}`;
    const existingIdx = seen.get(key);
    if (existingIdx === undefined) {
      seen.set(key, deduped.length);
      deduped.push(chunk);
      continue;
    }
    const existing = deduped[existingIdx];
    const winner =
      chunk.rawText.length > existing.rawText.length ? chunk : existing;
    deduped[existingIdx] = winner;
    warnings.push({
      scope: 'day',
      locator: key,
      code: 'duplicate_day_in_body',
      detail: `body contains two chunks for ${key}; kept the longer (${winner.rawText.length} chars), discarded the shorter (${Math.min(chunk.rawText.length, existing.rawText.length)} chars)`,
    });
  }

  return {
    weekStartsOn: toc.weekStartsOn,
    chunks: deduped,
    tracks: [...trackMeta.values()],
    warnings,
  };
}

function inferDayKind(bodyLines: string[]): DayKind {
  const text = bodyLines.join('\n');
  const hasSectionLetters = bodyLines.some((l) => SECTION_LETTER_REGEX.test(l.trim()));
  if (!hasSectionLetters && MARCUS_LETTER_HINT.test(text)) return 'lesson';
  if (!hasSectionLetters) return 'lesson';

  // First lettered section sets the kind for active-recovery / rest days.
  const firstLetterLine = bodyLines.find((l) => SECTION_LETTER_REGEX.test(l.trim()));
  if (firstLetterLine && ACTIVE_RECOVERY_REGEX.test(firstLetterLine)) {
    return 'active_recovery';
  }
  return 'workout';
}

// ISO Monday for the week containing `iso` whose `position` (1=Mon..7=Sun) is
// known. With a known weekday we can compute Monday without needing locale or
// Date library: subtract (position-1) days. Optional `addDays` lets us also
// produce Sunday (position 7).
function isoMonday(iso: string, position: number, addDays = 0): string {
  const [y, m, d] = iso.split('-').map((s) => parseInt(s, 10));
  const date = new Date(Date.UTC(y, m - 1, d));
  date.setUTCDate(date.getUTCDate() - (position - 1) + addDays);
  return date.toISOString().slice(0, 10);
}

// PRESCRIPTION_MODES is referenced via prompts; re-export for tree-shaking.
export { PRESCRIPTION_MODES };
