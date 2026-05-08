import type { DayChunk } from './document.segmenter';

// Deterministic noise-stripping for raw day text before it goes to the LLM.
// `chunk.rawText` is preserved as-is on the persisted day record (audit
// trail); this function returns a slimmed copy used only for the LLM call,
// shaving input tokens by removing PDF artifacts the model doesn't need.
//
// What we strip:
//   - The date heading (first line, e.g. "Saturday, May 9th, 2026") —
//     duplicated from chunk.scheduledOn in the user prompt context block.
//   - The "Week N Day M - Persist X" header line — duplicated from
//     chunk.weekPosition / chunk.dayPosition / chunk.trackHeading.
//   - URL strings (hyperlink artifacts pdfjs interleaves alongside the
//     visible exercise name) and bare email addresses.
//   - "Page N" / "Page N of M" pdfjs page-footer fragments.
//   - Functional Bodybuilding copyright lines.
//   - Trailing whitespace per line; tabs → 2 spaces; runs of blank lines
//     collapsed to a single blank line.
//
// What we DO NOT touch:
//   - Section letter prefixes (A), B), …) — the LLM uses these to
//     anchor sections.
//   - Section headers, exercise names, set lines, weights, RPE — anything
//     that looks like programming text.
//   - Anything between the first programming line and end-of-day.
//
// The function never throws on malformed input; worst case it returns a
// no-op cleaned copy, so a regex bug can't break the parse.

const URL_REGEX = /https?:\/\/\S+|www\.\S+/g;
const EMAIL_REGEX = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g;

const PAGE_FOOTER_REGEX = /^\s*Page\s+\d+(?:\s+of\s+\d+)?\s*$/i;
const COPYRIGHT_REGEX = /Functional\s+Body\s*building/i;
const DATE_LINE_REGEX =
  /^[A-Z][a-z]+,\s+[A-Z][a-z]+\s+\d{1,2}(?:st|nd|rd|th)?,\s*\d{4}$/i;
const WEEK_DAY_LINE_REGEX = /^Week\s+\d+\s+Day\s+\d+\s*[-–—]\s*Persist\b/i;

export function cleanDayTextForLlm(rawText: string, _chunk: DayChunk): string {
  let lines = rawText.split('\n');

  // Drop leading blank/header lines: blanks, the date heading, and the
  // "Week N Day M" line. Stop at the first programming line so we don't
  // strip a "Week 2 Day 3" mention that appears in coaching prose.
  while (lines.length > 0) {
    const t = lines[0].trim();
    if (t === '') {
      lines.shift();
      continue;
    }
    if (DATE_LINE_REGEX.test(t) || WEEK_DAY_LINE_REGEX.test(t)) {
      lines.shift();
      continue;
    }
    break;
  }

  const cleaned: string[] = [];
  let blankRun = 0;
  for (const raw of lines) {
    const stripped = raw
      .replace(/\t/g, '  ')
      .replace(URL_REGEX, '')
      .replace(EMAIL_REGEX, '')
      .replace(/[ \t]+$/g, '');

    const trimmed = stripped.trim();
    if (PAGE_FOOTER_REGEX.test(trimmed)) continue;
    if (COPYRIGHT_REGEX.test(trimmed)) continue;

    if (trimmed === '') {
      blankRun++;
      // First blank in a run preserves paragraph breaks; subsequent blanks
      // are pdf-extraction noise and get dropped.
      if (blankRun > 1) continue;
      cleaned.push('');
      continue;
    }
    blankRun = 0;
    cleaned.push(stripped);
  }

  // Trim leading/trailing blank lines so the user prompt's "# Day raw text"
  // section starts on the first programming line.
  while (cleaned.length > 0 && cleaned[0].trim() === '') cleaned.shift();
  while (cleaned.length > 0 && cleaned[cleaned.length - 1].trim() === '') {
    cleaned.pop();
  }

  return cleaned.join('\n');
}
