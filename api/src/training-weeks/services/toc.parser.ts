// Pure functions — no Nest DI. Tested with extracted-text fixtures so the
// segmenter's invariants can be verified before any LLM call.

const MONTHS: Record<string, number> = {
  january: 0, february: 1, march: 2, april: 3, may: 4, june: 5,
  july: 6, august: 7, september: 8, october: 9, november: 10, december: 11,
};

// Track headings found at the top of each track's body and in the cover-page
// anchor list. `Hybrid Running` is two words; `Workshop` carries no cadence.
const TRACK_NAMES = [
  'Pump Lift',
  'Pump Condition',
  'Hybrid Running',
  'Perform',
  'Minimalist',
  'Workshop',
] as const;

const TRACK_HEADING_REGEX = new RegExp(
  `^(?:${TRACK_NAMES.join('|')})(?:\\s+(?:3x|4x|5x))?\\s*$`,
);

// "Monday, May 4th, 2026" / "Monday, April 27th, 2026" / "Sunday, May 3rd, 2026".
// Allows ordinal suffixes and an optional space before the year (Apr 27 doc
// has both "Tuesday April 21st, 2026" AND "Tuesday, April 21st, 2026").
const DAY_LINE_REGEX =
  /^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)[a-z]+,?\s+([A-Z][a-z]+)\s+(\d{1,2})(?:st|nd|rd|th)?,\s+(\d{4})\s*$/;

export interface TocEntry {
  trackHeading: string; // "Pump Lift 5x"
  scheduledOn: string; // ISO date YYYY-MM-DD
}

export interface ParsedToc {
  weekStartsOn: string | null; // from "Persist Week of <date>"
  entries: TocEntry[];
  // Slice of fullText that we determined to be TOC (everything before body).
  tocSlice: string;
  bodyStartIndex: number;
}

// Find the body-start cleverly: the cover-page anchor list repeats every
// track + day-date, then the body begins. Body start = the FIRST track
// heading line that is followed (within ~5 non-empty lines) by a "Week N
// Day M - Persist …" subheading. Until then we're still in the TOC.
const WEEK_DAY_REGEX = /^Week\s+(\d{1,2})\s+Day\s+(\d{1,2})\s+-\s+Persist\b/i;

const WEEK_OF_REGEX = /Persist\s+Week\s+of\s+([A-Z][a-z]+)\s+(\d{1,2}),\s+(\d{4})/i;

export function parseToc(fullText: string): ParsedToc {
  const lines = fullText.split(/\r?\n/);
  const weekStartsOn = extractWeekOf(fullText);

  // Locate body start: first track heading followed by a Week/Day line within
  // a small lookahead. Anchor-list track headings have a Day line *much*
  // further down, separated by date entries.
  let bodyStartLine = lines.length;
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!TRACK_HEADING_REGEX.test(line)) continue;
    if (hasWeekDaySoon(lines, i)) {
      bodyStartLine = i;
      break;
    }
  }

  const tocLines = lines.slice(0, bodyStartLine);
  const bodyStartIndex = tocLines.join('\n').length + (bodyStartLine > 0 ? 1 : 0);

  // TOC is the contiguous block of (trackHeading, day-date list, ...) pairs.
  // We just walk it and collect entries, ignoring everything else.
  const entries: TocEntry[] = [];
  let currentTrack: string | null = null;
  for (let i = 0; i < bodyStartLine; i++) {
    const line = lines[i].trim();
    if (TRACK_HEADING_REGEX.test(line)) {
      currentTrack = line;
      continue;
    }
    if (!currentTrack) continue;
    const m = line.match(DAY_LINE_REGEX);
    if (m) {
      const iso = monthDayYearToIso(m[2], m[3], m[4]);
      if (iso) entries.push({ trackHeading: currentTrack, scheduledOn: iso });
    }
  }

  return {
    weekStartsOn,
    entries,
    tocSlice: tocLines.join('\n'),
    bodyStartIndex,
  };
}

function hasWeekDaySoon(lines: string[], trackLineIndex: number): boolean {
  let nonEmptyCount = 0;
  for (let j = trackLineIndex + 1; j < lines.length && nonEmptyCount < 8; j++) {
    const t = lines[j].trim();
    if (!t) continue;
    nonEmptyCount++;
    if (WEEK_DAY_REGEX.test(t)) return true;
    // If the next non-empty line is a date line, we're still in the anchor list.
    if (DAY_LINE_REGEX.test(t)) continue;
    // If we encounter a non-date, non-week-day line that isn't another track
    // heading, we're past the anchor list — body starts here.
    if (!TRACK_HEADING_REGEX.test(t)) return true;
  }
  return false;
}

function extractWeekOf(fullText: string): string | null {
  const m = fullText.match(WEEK_OF_REGEX);
  if (!m) return null;
  return monthDayYearToIso(m[1], m[2], m[3]);
}

function monthDayYearToIso(
  month: string,
  day: string,
  year: string,
): string | null {
  const monthIndex = MONTHS[month.toLowerCase()];
  if (monthIndex == null) return null;
  const d = parseInt(day, 10);
  const y = parseInt(year, 10);
  if (Number.isNaN(d) || Number.isNaN(y) || d < 1 || d > 31) return null;
  return `${y.toString().padStart(4, '0')}-${(monthIndex + 1)
    .toString()
    .padStart(2, '0')}-${d.toString().padStart(2, '0')}`;
}

// Exposed for the segmenter — both work on the same line shape.
export const __internal = {
  TRACK_HEADING_REGEX,
  DAY_LINE_REGEX,
  WEEK_DAY_REGEX,
  monthDayYearToIso,
  TRACK_NAMES,
};
