import { useMemo, useState } from 'react'
import { Link, useParams } from 'react-router-dom'

import { Badge } from '../components/ui/Badge'
import { Card } from '../components/ui/Card'
import { useTrainingWeek } from '../hooks/useTrainingWeeks'
import type {
  ParsedDay,
  ParsedExercise,
  ParsedGroup,
  ParsedSection,
  ParsedSet,
  ParsedTrack,
  ParseWarning,
} from '../types'

const WEEKDAY_LABEL = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']

function formatDate(iso: string): string {
  if (!iso) return '—'
  const d = new Date(`${iso}T00:00:00`)
  return d.toLocaleDateString(undefined, {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
  })
}

export function TrainingWeekDetailPage() {
  const { id } = useParams<{ id: string }>()
  const record = useTrainingWeek(id)
  const [activeTrackCode, setActiveTrackCode] = useState<string | null>(null)

  if (!record) {
    return (
      <div className="rounded-[var(--radius-card)] bg-card p-12 text-center shadow-[0_2px_8px_rgba(15,23,42,0.06)]">
        <h2 className="text-xl font-semibold text-ink">Record not found</h2>
        <p className="mt-2 text-sm text-ink-muted">
          This training week is not in your local storage. It may have been
          deleted, or you may be on a different browser/device.
        </p>
        <div className="mt-6">
          <Link
            to="/"
            className="text-sm font-semibold text-fbb-orange hover:text-fbb-orange-dark"
          >
            ← Back to training weeks
          </Link>
        </div>
      </div>
    )
  }

  const tracks = record.document?.tracks ?? []
  const activeTrack =
    tracks.find((t) => t.track_code === activeTrackCode) ?? tracks[0] ?? null

  // Group warnings by track for the per-track header strip.
  const warningsByTrack = useMemo(() => {
    const map = new Map<string, ParseWarning[]>()
    for (const w of record.parse_warnings) {
      const trackCode = w.locator.split('/')[0]
      const list = map.get(trackCode) ?? []
      list.push(w)
      map.set(trackCode, list)
    }
    return map
  }, [record.parse_warnings])

  return (
    <>
      <div className="mb-6 flex flex-col gap-1">
        <Link
          to="/"
          className="text-xs font-medium text-ink-muted hover:text-fbb-orange"
        >
          ← Training weeks
        </Link>
        <div className="flex flex-col gap-3 md:flex-row md:items-end md:justify-between">
          <div>
            <h1 className="text-[28px] font-bold leading-tight text-ink">
              Week of {formatDate(record.week_starts_on)}
            </h1>
            <p className="mt-1 font-mono text-xs text-ink-muted">
              {record.source_filename} ·{' '}
              <span className="text-ink-secondary">{record.id}</span>
            </p>
          </div>
          <MetricsRow record={record} />
        </div>
      </div>

      {record.parse_warnings.length > 0 ? (
        <div className="mb-6 rounded-[var(--radius-card)] border border-warning/30 bg-[#FCEFD9] px-4 py-3">
          <div className="flex items-start gap-2">
            <WarningIcon />
            <div className="flex-1">
              <div className="text-sm font-semibold text-ink">
                {record.parse_warnings.length}{' '}
                {record.parse_warnings.length === 1 ? 'warning' : 'warnings'} from
                the parser
              </div>
              <ul className="mt-1.5 space-y-1 text-sm text-ink-secondary">
                {record.parse_warnings.slice(0, 6).map((w, i) => (
                  <li key={i} className="flex gap-2">
                    <span className="font-mono text-xs text-warning">
                      {w.code}
                    </span>
                    <span className="font-mono text-xs text-ink-muted">
                      {w.locator}
                    </span>
                    <span className="text-xs text-ink-secondary">
                      — {w.detail}
                    </span>
                  </li>
                ))}
                {record.parse_warnings.length > 6 ? (
                  <li className="text-xs text-ink-muted">
                    + {record.parse_warnings.length - 6} more
                  </li>
                ) : null}
              </ul>
            </div>
          </div>
        </div>
      ) : null}

      {tracks.length === 0 ? (
        <Card>
          <p className="text-sm text-ink-secondary">
            This record has no parsed tracks. It may have been a dry-run upload
            (segmenter only).
          </p>
        </Card>
      ) : (
        <>
          <TrackTabs
            tracks={tracks}
            active={activeTrack}
            onSelect={setActiveTrackCode}
            warningsByTrack={warningsByTrack}
          />
          {activeTrack ? <TrackPanel track={activeTrack} /> : null}
        </>
      )}
    </>
  )
}

function MetricsRow({
  record,
}: {
  record: NonNullable<ReturnType<typeof useTrainingWeek>>
}) {
  const m = record.parse_metrics
  return (
    <div className="flex flex-wrap items-center gap-2">
      <Badge tone="info">{m.llm_calls} LLM calls</Badge>
      <Badge tone="neutral">{(m.llm_total_ms / 1000).toFixed(1)}s parse</Badge>
      {m.tokens_total > 0 ? (
        <Badge tone="orange">{m.tokens_total.toLocaleString()} tokens</Badge>
      ) : null}
      <Badge tone="neutral" className="font-mono">
        {m.model}
      </Badge>
    </div>
  )
}

function TrackTabs({
  tracks,
  active,
  onSelect,
  warningsByTrack,
}: {
  tracks: ParsedTrack[]
  active: ParsedTrack | null
  onSelect: (code: string) => void
  warningsByTrack: Map<string, ParseWarning[]>
}) {
  return (
    <div className="-mx-2 mb-6 overflow-x-auto px-2 pb-1">
      <div className="flex min-w-min items-center gap-1.5 border-b border-divider pb-0">
        {tracks.map((t) => {
          const isActive = active?.track_code === t.track_code
          const wn = warningsByTrack.get(t.track_code)?.length ?? 0
          return (
            <button
              key={t.track_code}
              type="button"
              onClick={() => onSelect(t.track_code)}
              className={`inline-flex items-center gap-2 whitespace-nowrap rounded-t-lg px-3.5 py-2.5 text-sm font-medium transition-colors ${
                isActive
                  ? 'border-b-2 border-fbb-orange bg-fbb-orange-tint/30 text-ink'
                  : 'text-ink-muted hover:bg-surface hover:text-ink'
              }`}
            >
              <span>{t.display_name}</span>
              <span className="font-mono text-[10px] text-ink-muted">
                {t.days.length}d
              </span>
              {wn > 0 ? (
                <span className="ml-1 inline-flex h-4 min-w-4 items-center justify-center rounded-full bg-warning px-1 text-[10px] font-semibold text-white">
                  {wn}
                </span>
              ) : null}
            </button>
          )
        })}
      </div>
    </div>
  )
}

function TrackPanel({ track }: { track: ParsedTrack }) {
  return (
    <div className="space-y-4">
      <Card>
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <div className="text-xs font-medium uppercase tracking-wider text-ink-muted">
              Microcycle
            </div>
            <div className="mt-1 text-base font-semibold text-ink">
              {formatDate(track.microcycle.starts_on)} →{' '}
              {formatDate(track.microcycle.ends_on)}
              <span className="ml-2 font-normal text-ink-muted">
                · 7 days · kind={' '}
                <span className="font-mono text-xs">{track.microcycle.kind}</span>
              </span>
            </div>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <Badge tone="info">{track.family}</Badge>
            {track.cadence ? (
              <Badge tone="orange">{track.cadence}</Badge>
            ) : null}
            {track.microcycle.week_position != null ? (
              <Badge tone="neutral">
                Week {track.microcycle.week_position}
              </Badge>
            ) : null}
          </div>
        </div>
      </Card>

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
        {track.days.map((day) => (
          <DayCard key={day.scheduled_on} day={day} />
        ))}
      </div>
    </div>
  )
}

function DayCard({ day }: { day: ParsedDay }) {
  const sectionCount = day.sections.length
  const groupCount = day.sections.reduce((s, sec) => s + sec.groups.length, 0)
  const exerciseCount = day.sections.reduce(
    (s, sec) =>
      s + sec.groups.reduce((gs, g) => gs + g.exercises.length, 0),
    0,
  )

  const kindTone =
    day.kind === 'workout'
      ? 'orange'
      : day.kind === 'active_recovery'
        ? 'info'
        : day.kind === 'lesson'
          ? 'neutral'
          : 'neutral'

  return (
    <details className="group rounded-[var(--radius-card)] bg-card shadow-[0_2px_8px_rgba(15,23,42,0.06)] transition-shadow open:shadow-[0_8px_24px_rgba(15,23,42,0.10)]">
      <summary className="flex flex-col gap-2 p-4">
        <div className="flex items-start justify-between">
          <div>
            <div className="text-[11px] font-semibold uppercase tracking-wider text-ink-muted">
              {WEEKDAY_LABEL[day.position - 1] ?? `Day ${day.position}`} ·{' '}
              {formatDate(day.scheduled_on).replace(/^\w+, /, '')}
            </div>
            <div className="mt-1 text-[15px] font-semibold text-ink">
              {day.display_name.replace(/^Week \d+ Day \d+ - /, '')}
            </div>
          </div>
          <span className="ml-2 mt-0.5 text-ink-muted transition-transform group-open:rotate-90">
            ›
          </span>
        </div>

        <div className="flex flex-wrap items-center gap-1.5">
          <Badge tone={kindTone as 'orange' | 'info' | 'neutral'}>
            {day.kind}
          </Badge>
          {day.is_optional ? <Badge tone="neutral">optional</Badge> : null}
          {sectionCount > 0 ? (
            <span className="font-mono text-[11px] text-ink-muted">
              {sectionCount}§ · {groupCount}g · {exerciseCount}ex
            </span>
          ) : (
            <span className="text-[11px] text-ink-muted">no structured sections</span>
          )}
        </div>
      </summary>

      <div className="border-t border-divider px-4 py-3">
        {day.kind === 'lesson' ? <LessonBody day={day} /> : null}
        {day.sections.length > 0 ? (
          <div className="space-y-3">
            {day.sections.map((s) => (
              <SectionDrawer key={s.position} section={s} />
            ))}
          </div>
        ) : null}
      </div>
    </details>
  )
}

function LessonBody({ day }: { day: ParsedDay }) {
  const note = day.coaching_notes[0]
  if (!note) return null
  return (
    <div className="rounded-md bg-fbb-orange-tint/40 p-3 text-sm leading-relaxed text-ink-secondary">
      <div className="text-xs font-semibold uppercase tracking-wider text-fbb-orange-dark">
        {note.kind}
      </div>
      <div className="mt-1 whitespace-pre-wrap text-[13px]">
        {note.body_markdown}
      </div>
    </div>
  )
}

function SectionDrawer({ section }: { section: ParsedSection }) {
  return (
    <details className="group rounded-md border border-divider bg-surface/40">
      <summary className="flex items-start justify-between gap-3 px-3 py-2.5">
        <div className="flex flex-1 items-start gap-2">
          <span className="grid h-6 w-6 shrink-0 place-items-center rounded-md bg-fbb-orange-tint font-mono text-xs font-bold text-fbb-orange-dark">
            {section.letter}
          </span>
          <div>
            <div className="text-sm font-semibold text-ink">
              {section.display_name}
            </div>
            <div className="mt-0.5 flex flex-wrap items-center gap-1.5 text-[11px] text-ink-muted">
              <span className="font-mono">{section.kind}</span>
              <span>·</span>
              <span className="font-mono">{section.prescription_mode}</span>
              {section.target_duration_min ? (
                <>
                  <span>·</span>
                  <span>
                    {section.target_duration_min}
                    {section.target_duration_max &&
                    section.target_duration_max !== section.target_duration_min
                      ? `–${section.target_duration_max}`
                      : ''}{' '}
                    min
                  </span>
                </>
              ) : null}
            </div>
          </div>
        </div>
        <span className="text-ink-muted transition-transform group-open:rotate-90">
          ›
        </span>
      </summary>
      {section.daily_focus_note ? (
        <div className="border-t border-divider px-3 py-2 text-[13px] italic text-ink-secondary">
          {section.daily_focus_note}
        </div>
      ) : null}
      <div className="space-y-2 border-t border-divider px-3 py-2">
        {section.groups.map((g) => (
          <GroupDrawer key={g.position} group={g} />
        ))}
      </div>
    </details>
  )
}

function GroupDrawer({ group }: { group: ParsedGroup }) {
  const summary = formatGroupSummary(group)
  return (
    <div className="rounded-md bg-card p-2.5 shadow-[0_1px_3px_rgba(15,23,42,0.04)]">
      <div className="flex items-center justify-between gap-3">
        <div className="text-xs font-semibold text-ink-secondary">
          Group {group.position}
        </div>
        <div className="font-mono text-[11px] text-ink-muted">{summary}</div>
      </div>
      {group.loading_note ? (
        <div className="mt-1.5 text-[12px] text-ink-muted">
          <span className="font-semibold text-ink-secondary">Loading: </span>
          {group.loading_note}
        </div>
      ) : null}
      <div className="mt-2 space-y-1.5">
        {group.exercises.map((ex) => (
          <ExerciseRow key={`${ex.position}-${ex.alternate_of_position ?? ''}`} ex={ex} />
        ))}
      </div>
    </div>
  )
}

function ExerciseRow({ ex }: { ex: ParsedExercise }) {
  const isAlt = ex.alternate_of_position != null
  return (
    <div
      className={`rounded-sm px-2 py-1.5 text-[13px] ${
        isAlt ? 'border-l-2 border-fbb-teal pl-3 text-ink-secondary' : 'text-ink'
      }`}
    >
      <div className="flex items-center justify-between gap-2">
        <div className="font-medium">
          {isAlt ? <span className="text-ink-muted">or </span> : null}
          {ex.movement_display_name}
          {ex.chained_into_next ? (
            <span className="ml-1.5 text-[10px] font-normal text-fbb-orange-dark">
              → directly into
            </span>
          ) : null}
        </div>
        {ex.is_unilateral ? (
          <span className="font-mono text-[10px] text-ink-muted">unilateral</span>
        ) : null}
      </div>
      {ex.sets.length > 0 ? (
        <div className="mt-1 ml-1 space-y-0.5">
          {ex.sets.map((s) => (
            <SetLine key={`${s.position}-${s.set_kind}`} set={s} />
          ))}
        </div>
      ) : null}
    </div>
  )
}

function SetLine({ set }: { set: ParsedSet }) {
  return (
    <div className="flex flex-wrap items-center gap-x-2 gap-y-0.5 font-mono text-[11px] text-ink-secondary">
      <span className="inline-flex h-4 min-w-4 items-center justify-center rounded bg-surface px-1 text-[10px] font-semibold text-ink-muted">
        {set.position}
      </span>
      <span className="text-ink">{set.set_kind}</span>
      <span>·</span>
      <span>{formatReps(set)}</span>
      {set.tempo ? (
        <>
          <span>·</span>
          <span>@{set.tempo}</span>
        </>
      ) : null}
      {formatRpe(set) ? (
        <>
          <span>·</span>
          <span className="text-fbb-orange-dark">{formatRpe(set)}</span>
        </>
      ) : null}
      {formatWeight(set) ? (
        <>
          <span>·</span>
          <span className="text-ink-muted">{formatWeight(set)}</span>
        </>
      ) : null}
      {set.has_drop_set ? (
        <span className="ml-1 rounded bg-fbb-orange-tint px-1 py-0.5 text-[9px] font-semibold uppercase text-fbb-orange-dark">
          drop
        </span>
      ) : null}
    </div>
  )
}

function formatReps(s: ParsedSet): string {
  if (s.reps_text) return s.reps_text
  if (s.duration_seconds_min != null) {
    const max = s.duration_seconds_max
    if (max && max !== s.duration_seconds_min)
      return `${s.duration_seconds_min}-${max}s`
    return `${s.duration_seconds_min}s`
  }
  if (s.reps_min != null) {
    const suf = s.per_side ? '/side' : ''
    if (s.reps_max && s.reps_max !== s.reps_min)
      return `${s.reps_min}-${s.reps_max} reps${suf}`
    return `${s.reps_min} reps${suf}`
  }
  return ''
}

function formatRpe(s: ParsedSet): string {
  if (s.rpe_text) return s.rpe_text
  if (s.rpe_min == null) return ''
  if (s.rpe_max != null && s.rpe_max !== s.rpe_min)
    return `RPE ${s.rpe_min}-${s.rpe_max}`
  return `RPE ${s.rpe_min}`
}

function formatWeight(s: ParsedSet): string {
  const w = s.weight_ref
  if (!w || !('kind' in w) || w.kind === 'none') return ''
  switch (w.kind) {
    case 'bodyweight':
      return 'bodyweight'
    case 'absolute':
      return w.load_kg_male != null && w.load_kg_female != null
        ? `${w.load_kg_male}/${w.load_kg_female}kg`
        : w.raw ?? 'absolute'
    case 'percent_of_working':
      return `${w.percent}% of working`
    case 'relative_to_set':
      return `= set ${w.target_position}`
    case 'delta_from_set':
      return `Δ${w.delta_percent}% set ${w.target_position}`
    case 'assistance_match_rep_max':
      return `match ${w.rep_max}RM`
    default:
      return ''
  }
}

function formatGroupSummary(g: ParsedGroup): string {
  const parts: string[] = [g.prescription_mode]
  if (g.round_count_min) {
    if (g.round_count_max && g.round_count_max !== g.round_count_min)
      parts.push(`${g.round_count_min}-${g.round_count_max} rounds`)
    else parts.push(`${g.round_count_min} rounds`)
  }
  if (g.interval_seconds) parts.push(`every ${g.interval_seconds}s`)
  if (g.cap_seconds) parts.push(`cap ${g.cap_seconds}s`)
  return parts.join(' · ')
}

function WarningIcon() {
  return (
    <svg
      width="20"
      height="20"
      viewBox="0 0 24 24"
      fill="none"
      className="shrink-0 text-warning"
    >
      <path
        d="M12 9V13M12 17H12.01M10.29 3.86L1.82 18A2 2 0 003.54 21H20.46A2 2 0 0022.18 18L13.71 3.86A2 2 0 0010.29 3.86Z"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  )
}

