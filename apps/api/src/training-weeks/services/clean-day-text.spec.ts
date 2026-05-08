import type { DayChunk } from './document.segmenter';
import { cleanDayTextForLlm } from './clean-day-text';

const baseChunk: DayChunk = {
  trackCode: 'perform',
  trackHeading: 'Perform',
  family: 'perform',
  cadence: null,
  scheduledOn: '2026-05-09',
  position: 6,
  weekPosition: 1,
  dayPosition: 6,
  displayName: 'Week 1 Day 6 - Persist PERFORM',
  kind: 'workout',
  isOptional: false,
  rawText: '',
};

describe('cleanDayTextForLlm', () => {
  it('strips the date heading and week-day header line', () => {
    const input = [
      'Saturday, May 9th, 2026',
      'Week 1 Day 6 - Persist PERFORM',
      'A) Daily Focus Notes:',
      'Spoto Press',
    ].join('\n');
    const out = cleanDayTextForLlm(input, baseChunk);
    expect(out.startsWith('A) Daily Focus Notes:')).toBe(true);
    expect(out).not.toContain('Saturday');
    expect(out).not.toContain('Week 1 Day 6');
  });

  it('strips URLs and email addresses inline', () => {
    const input = [
      'A) Warmup',
      'See video at https://example.com/spoto-press for cues',
      'Questions? support@functional-bodybuilding.com',
      'B) Strength Intensity 1',
    ].join('\n');
    const out = cleanDayTextForLlm(input, baseChunk);
    expect(out).not.toContain('https://');
    expect(out).not.toContain('support@');
    expect(out).toContain('B) Strength Intensity 1');
    expect(out).toContain('See video at  for cues');
  });

  it('drops "Page N of M" footers and copyright lines', () => {
    const input = [
      'A) Warmup',
      '5 reps Squat',
      'Page 12 of 56',
      'Functional Bodybuilding © 2026',
      'B) Strength',
    ].join('\n');
    const out = cleanDayTextForLlm(input, baseChunk);
    expect(out).not.toMatch(/Page\s+12/);
    expect(out).not.toContain('Functional Bodybuilding');
    expect(out).toContain('B) Strength');
  });

  it('collapses runs of blank lines but preserves single paragraph breaks', () => {
    const input = [
      'A) Warmup',
      '',
      '',
      '',
      'B) Strength',
      '',
      'Working Sets',
    ].join('\n');
    const out = cleanDayTextForLlm(input, baseChunk);
    expect(out).toBe(
      ['A) Warmup', '', 'B) Strength', '', 'Working Sets'].join('\n'),
    );
  });

  it('leaves programming text untouched (set/weight/RPE shapes pass through)', () => {
    const input = [
      'A) Strength Intensity 1',
      'Every 2:30 x 4 Working Sets',
      'Working Set 1: 5 reps @ 70% RPE 8',
      'Working Set 2: 3-5 reps @ 53/35# (Male/Female)',
      '+ Double Drop Set to Failure',
    ].join('\n');
    const out = cleanDayTextForLlm(input, baseChunk);
    expect(out).toContain('Every 2:30 x 4 Working Sets');
    expect(out).toContain('Working Set 1: 5 reps @ 70% RPE 8');
    expect(out).toContain('53/35# (Male/Female)');
    expect(out).toContain('+ Double Drop Set to Failure');
  });

  it('does NOT strip "Week N Day M" if it appears mid-content (only the leading header)', () => {
    const input = [
      'Saturday, May 9th, 2026',
      'Week 1 Day 6 - Persist PERFORM',
      'A) Daily Focus Notes:',
      'Notes mention Week 2 Day 3 of last block as a comparison.',
      'Week 1 Day 6 - Persist PERFORM',
    ].join('\n');
    const out = cleanDayTextForLlm(input, baseChunk);
    // Leading two lines stripped; the in-content mentions kept.
    expect(out).toContain('Notes mention Week 2 Day 3');
    expect(out).toMatch(/Week 1 Day 6 - Persist PERFORM\s*$/);
  });

  it('returns an empty string when the input is only header noise', () => {
    const input = [
      'Saturday, May 9th, 2026',
      'Week 1 Day 6 - Persist PERFORM',
      '',
      '',
    ].join('\n');
    expect(cleanDayTextForLlm(input, baseChunk)).toBe('');
  });
});
