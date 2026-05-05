import { Fragment, useMemo, useState, type ReactNode } from 'react'
import { Link, useParams, useSearchParams } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'

import {
  pollUploadJobUntilDone,
  retryUploadJobDays,
} from '../api/upload-jobs'
import { Badge } from '../components/ui/Badge'
import { Card } from '../components/ui/Card'
import {
  trainingWeeksKeys,
  useTrainingWeek,
  useTrainingWeekDay,
  useTrainingWeeks,
} from '../hooks/useTrainingWeeks'
import type {
  ParsedDay,
  ParsedExercise,
  ParsedGroup,
  ParsedSection,
  ParsedSet,
  TrackFamily,
  TrainingWeekDayCell,
  TrainingWeekDayMeta,
  TrainingWeekTrackIndex,
} from '../types'

// Sun-indexed so Date.getDay() maps directly. Using scheduled_on as the source
// of truth (rather than ParsedDay.position) means weekday labels stay correct
// even if a track skips a day or starts mid-week.
const WEEKDAY_LABEL = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

const FAMILY_LABEL: Record<TrackFamily, string> = {
  pump_lift: 'Pump Lift',
  pump_condition: 'Pump Condition',
  perform: 'Perform',
  minimalist: 'Minimalist',
  hybrid_running: 'Hybrid Run',
  workshop: 'Workshop',
  onramp: 'Onramp',
}

const FAMILY_ORDER = Object.keys(FAMILY_LABEL) as TrackFamily[]

const CADENCE_ORDER = ['3x', '4x', '5x', 'custom', '__none__'] as const

type View = 'matrix' | 'day' | 'track'

function asView(v: string | null): View {
  return v === 'matrix' || v === 'day' ? v : 'track'
}

// All date helpers anchor on UTC so an ISO date like 2026-04-20 always renders
// as April 20 regardless of the viewer's timezone. Parsing without a `Z`
// suffix and then calling `.toISOString()` rolls the date forward/back by a
// day for any non-UTC locale — that bug surfaced as "Sunday always empty" in
// the matrix view.
function weekdayLabel(iso: string): string {
  const d = new Date(`${iso}T00:00:00Z`)
  return WEEKDAY_LABEL[d.getUTCDay()]
}

function formatDate(iso: string): string {
  if (!iso) return '—'
  const d = new Date(`${iso}T00:00:00Z`)
  return d.toLocaleDateString(undefined, {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    timeZone: 'UTC',
  })
}

export function TrainingWeekDetailPage() {
  const { weekStartsOn } = useParams<{ weekStartsOn: string }>()
  const { record, loading, error } = useTrainingWeek(weekStartsOn)
  const [searchParams, setSearchParams] = useSearchParams()

  const view = asView(searchParams.get('view'))
  const familyParam = searchParams.get('family') as TrackFamily | null
  const cadenceParam = searchParams.get('cadence')
  const trackParam = searchParams.get('track')
  const dayParam = searchParams.get('day')

  // List of all weeks — drives prev/next navigation. Already cached if the
  // user came from the list page; otherwise this triggers a small extra fetch.
  const { records: weekList } = useTrainingWeeks()

  // `prev` is the *older* week, `next` is the *newer* week (chronological).
  const weekNav = useMemo(() => {
    if (!weekStartsOn || weekList.length === 0)
      return { prev: null as string | null, next: null as string | null }
    const sorted = [...weekList].sort((a, b) =>
      a.week_starts_on.localeCompare(b.week_starts_on),
    )
    const i = sorted.findIndex((w) => w.week_starts_on === weekStartsOn)
    return {
      prev: i > 0 ? sorted[i - 1].week_starts_on : null,
      next: i >= 0 && i < sorted.length - 1 ? sorted[i + 1].week_starts_on : null,
    }
  }, [weekList, weekStartsOn])

  // Selections cascade family → cadence → track. Each level reads from the URL
  // first; if the URL value is missing/stale (e.g. user picked a new family),
  // we fall back to the first available option without writing the URL — that
  // keeps the back button useful and URLs minimal.
  const families = useMemo<TrackFamily[]>(() => {
    if (!record) return []
    const seen = new Set<TrackFamily>()
    for (const t of record.tracks) seen.add(t.family)
    return FAMILY_ORDER.filter((f) => seen.has(f))
  }, [record])

  const effectiveFamily =
    familyParam && families.includes(familyParam)
      ? familyParam
      : families[0] ?? null

  const cadences = useMemo<Array<{ key: string; label: string }>>(() => {
    if (!record || !effectiveFamily) return []
    const seen = new Map<string, string>()
    for (const t of record.tracks) {
      if (t.family !== effectiveFamily) continue
      const key = t.cadence ?? '__none__'
      seen.set(key, t.cadence ?? '—')
    }
    return CADENCE_ORDER.filter((k) => seen.has(k)).map((k) => ({
      key: k,
      label: seen.get(k)!,
    }))
  }, [record, effectiveFamily])

  const effectiveCadence =
    cadenceParam && cadences.some((c) => c.key === cadenceParam)
      ? cadenceParam
      : cadences[0]?.key ?? null

  const filteredTracks = useMemo(() => {
    if (!record || !effectiveFamily || !effectiveCadence) return []
    return record.tracks.filter(
      (t) =>
        t.family === effectiveFamily &&
        (t.cadence ?? '__none__') === effectiveCadence,
    )
  }, [record, effectiveFamily, effectiveCadence])

  // Day view uses a softer filter: it respects URL family/cadence when
  // present but never auto-defaults. No URL filter = show every track for
  // the selected day. This lets users land in day view (or carry a `family`
  // selection over from track view) and see *all* matching tracks at once.
  const dayViewTracks = useMemo(() => {
    if (!record) return []
    let arr = record.tracks
    if (familyParam && families.includes(familyParam)) {
      arr = arr.filter((t) => t.family === familyParam)
    }
    if (cadenceParam) {
      arr = arr.filter((t) => (t.cadence ?? '__none__') === cadenceParam)
    }
    return arr
  }, [record, familyParam, cadenceParam, families])

  const effectiveTrack =
    filteredTracks.find((t) => t.track_code === trackParam) ??
    filteredTracks[0] ??
    null

  const updateParams = (next: Record<string, string | null>) => {
    const params = new URLSearchParams(searchParams)
    for (const [k, v] of Object.entries(next)) {
      if (v == null) params.delete(k)
      else params.set(k, v)
    }
    setSearchParams(params, { replace: true })
  }

  if (loading) {
    return (
      <div className="rounded-[var(--radius-card)] bg-card p-12 text-center shadow-[0_2px_8px_rgba(15,23,42,0.06)]">
        <p className="text-sm text-ink-muted">Loading…</p>
      </div>
    )
  }

  if (error || !record) {
    return (
      <div className="rounded-[var(--radius-card)] bg-card p-12 text-center shadow-[0_2px_8px_rgba(15,23,42,0.06)]">
        <h2 className="text-xl font-semibold text-ink">Week not found</h2>
        <p className="mt-2 text-sm text-ink-muted">
          {error ?? 'No training week is persisted for this date.'}
        </p>
        <div className="mt-6">
          <Link
            to="/training-weeks"
            className="text-sm font-semibold text-fbb-orange hover:text-fbb-orange-dark"
          >
            ← Back to training weeks
          </Link>
        </div>
      </div>
    )
  }

  const tracks = record.tracks

  return (
    <>
      <div className="mb-6">
        <div className="flex flex-col gap-3 md:flex-row md:items-end md:justify-between">
          <div className="flex items-end gap-3">
            <WeekNavLink
              iso={weekNav.prev}
              direction="prev"
              searchParams={searchParams}
            />
            <div>
              <h1 className="text-[28px] font-bold leading-tight text-ink">
                Week of {formatDate(record.week_starts_on)}
              </h1>
              <p className="mt-1 font-mono text-xs text-ink-muted">
                {record.week_starts_on} → {record.week_ends_on}
              </p>
            </div>
            <WeekNavLink
              iso={weekNav.next}
              direction="next"
              searchParams={searchParams}
            />
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <Badge tone="info">🏋️ {tracks.length} tracks</Badge>
            {tracks[0]?.microcycle.week_position != null ? (
              <Badge tone="neutral">
                Week {tracks[0].microcycle.week_position}
              </Badge>
            ) : null}
            {tracks[0]?.microcycle.kind ? (
              <Badge tone="neutral">
                {humanize(tracks[0].microcycle.kind)}
              </Badge>
            ) : null}
            <ViewToggle
              view={view}
              onChange={(v) => {
                // Track view's filter cascade writes `cadence` and `track`
                // to the URL as the user narrows down. Day and Matrix views
                // are multi-track by nature, so carrying those through would
                // silently shrink the visible set to whatever was last
                // selected. Drop them on the way out; keep `family` (a
                // useful scope) and `day` (the calendar day in focus).
                const next: Record<string, string | null> = {
                  view: v === 'track' ? null : v,
                }
                if (v !== 'track') {
                  next.cadence = null
                  next.track = null
                }
                updateParams(next)
              }}
            />
          </div>
        </div>
      </div>

      {tracks.length === 0 ? (
        <Card>
          <p className="text-sm text-ink-secondary">
            No tracks persisted for this week yet.
          </p>
        </Card>
      ) : (
        <>
          {view === 'track' ? (
            <TrackFilter
              families={families}
              activeFamily={effectiveFamily}
              cadences={cadences}
              activeCadence={effectiveCadence}
              tracks={filteredTracks}
              activeTrackCode={effectiveTrack?.track_code ?? null}
              showTrackPicker
              onSelectFamily={(f) =>
                updateParams({ family: f, cadence: null, track: null })
              }
              onSelectCadence={(c) =>
                updateParams({ cadence: c, track: null })
              }
              onSelectTrack={(code) => updateParams({ track: code })}
            />
          ) : null}
          {view === 'track' && effectiveTrack ? (
            <TrackPanel
              track={effectiveTrack}
              selectedDay={dayParam}
              onSelectDay={(iso) => updateParams({ day: iso })}
              weekStartsOn={record.week_starts_on}
              lastUploadJobId={record.last_upload_job_id}
            />
          ) : null}
          {view === 'matrix' ? (
            <MatrixView
              weekStartsOn={record.week_starts_on}
              tracks={tracks}
              onPickCell={(track, iso) =>
                updateParams({
                  view: null,
                  family: track.family,
                  cadence: track.cadence ?? '__none__',
                  track: track.track_code,
                  day: iso,
                })
              }
            />
          ) : null}
          {view === 'day' ? (
            <DayView
              tracks={dayViewTracks}
              weekStartsOn={record.week_starts_on}
              selectedDay={dayParam}
              onSelectDay={(iso) => updateParams({ day: iso })}
              lastUploadJobId={record.last_upload_job_id}
            />
          ) : null}
        </>
      )}
    </>
  )
}

function ViewToggle({
  view,
  onChange,
}: {
  view: View
  onChange: (v: View) => void
}) {
  const items: Array<{ key: View; label: string }> = [
    { key: 'matrix', label: 'Matrix' },
    { key: 'day', label: 'Day' },
    { key: 'track', label: 'Track' },
  ]
  return (
    <div
      role="tablist"
      aria-label="View"
      className="inline-flex items-center rounded-full border border-divider bg-card p-0.5"
    >
      {items.map((it) => {
        const active = it.key === view
        return (
          <button
            key={it.key}
            type="button"
            role="tab"
            aria-selected={active}
            onClick={() => onChange(it.key)}
            className={`cursor-pointer rounded-full px-3 py-1 text-xs font-semibold transition-colors ${
              active
                ? 'bg-fbb-orange text-white'
                : 'text-ink-muted hover:text-ink'
            }`}
          >
            {it.label}
          </button>
        )
      })}
    </div>
  )
}

function TrackFilter({
  families,
  activeFamily,
  cadences,
  activeCadence,
  tracks,
  activeTrackCode,
  showTrackPicker,
  onSelectFamily,
  onSelectCadence,
  onSelectTrack,
}: {
  families: TrackFamily[]
  activeFamily: TrackFamily | null
  cadences: Array<{ key: string; label: string }>
  activeCadence: string | null
  tracks: TrainingWeekTrackIndex[]
  activeTrackCode: string | null
  showTrackPicker: boolean
  onSelectFamily: (f: TrackFamily) => void
  onSelectCadence: (c: string) => void
  onSelectTrack: (code: string) => void
}) {
  const showCadence = cadences.length > 1
  const showTracks = showTrackPicker && tracks.length > 1
  return (
    <div className="mb-6 space-y-2 rounded-[var(--radius-card)] bg-card p-3 shadow-[0_2px_8px_rgba(15,23,42,0.06)]">
      <ChipRow label="Family">
        {families.map((f) => (
          <Chip
            key={f}
            active={f === activeFamily}
            onClick={() => onSelectFamily(f)}
          >
            {FAMILY_LABEL[f]}
          </Chip>
        ))}
      </ChipRow>
      {showCadence ? (
        <ChipRow label="Cadence">
          {cadences.map((c) => (
            <Chip
              key={c.key}
              active={c.key === activeCadence}
              onClick={() => onSelectCadence(c.key)}
            >
              {c.label}
            </Chip>
          ))}
        </ChipRow>
      ) : null}
      {showTracks ? (
        <ChipRow label="Track">
          {tracks.map((t) => (
            <Chip
              key={t.track_code}
              active={t.track_code === activeTrackCode}
              onClick={() => onSelectTrack(t.track_code)}
            >
              {t.display_name}
            </Chip>
          ))}
        </ChipRow>
      ) : null}
    </div>
  )
}

function ChipRow({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex flex-wrap items-center gap-2">
      <span className="w-16 shrink-0 text-[10px] font-semibold uppercase tracking-wider text-ink-muted">
        {label}
      </span>
      <div className="flex flex-wrap items-center gap-1.5">{children}</div>
    </div>
  )
}

function Chip({
  active,
  onClick,
  children,
}: {
  active: boolean
  onClick: () => void
  children: ReactNode
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`inline-flex cursor-pointer items-center rounded-full border px-3 py-1 text-xs font-medium transition-colors ${
        active
          ? 'border-fbb-orange bg-fbb-orange-tint text-fbb-orange-dark'
          : 'border-divider bg-surface text-ink-secondary hover:border-fbb-orange/40 hover:text-ink'
      }`}
    >
      {children}
    </button>
  )
}

function DayView({
  tracks,
  weekStartsOn,
  selectedDay,
  onSelectDay,
  lastUploadJobId,
}: {
  tracks: TrainingWeekTrackIndex[]
  weekStartsOn: string
  selectedDay: string | null
  onSelectDay: (iso: string) => void
  lastUploadJobId: string | null
}) {
  // Calendar dates Mon..Sun for the week, UTC-anchored to match MatrixView.
  const weekDates = useMemo(() => {
    const out: string[] = []
    const base = new Date(`${weekStartsOn}T00:00:00Z`)
    for (let i = 0; i < 7; i++) {
      const d = new Date(base)
      d.setUTCDate(d.getUTCDate() + i)
      out.push(d.toISOString().slice(0, 10))
    }
    return out
  }, [weekStartsOn])

  const activeIso =
    selectedDay && weekDates.includes(selectedDay) ? selectedDay : weekDates[0]

  // Heavy lift: full sections/groups/exercises/sets for every track on the
  // active date. RQ caches per (week, day) so toggling Track ↔ Day on the
  // same day reuses the same payload.
  const { record: dayDetail, loading: dayLoading } = useTrainingWeekDay(
    weekStartsOn,
    activeIso,
  )

  // Filter the day-detail cells to the tracks visible under the current
  // family/cadence URL filter. Ordering follows `tracks` (the index order).
  const visibleCells = useMemo(() => {
    if (!dayDetail) return []
    const cellByTrack = new Map(
      dayDetail.cells.map((c) => [c.track.track_code, c]),
    )
    return tracks
      .map((t) => cellByTrack.get(t.track_code))
      .filter((c): c is TrainingWeekDayCell => c !== undefined)
  }, [dayDetail, tracks])

  // Strip indicators come from the slim index — no need to wait on the
  // heavy day-detail fetch to render the pill counts.
  const countsByDate = useMemo(() => {
    const map = new Map<
      string,
      { workout: number; recovery: number; lesson: number; off: number }
    >()
    for (const iso of weekDates) {
      let workout = 0
      let recovery = 0
      let lesson = 0
      let off = 0
      for (const t of tracks) {
        const day = t.days.find((d) => d.scheduled_on === iso)
        if (!day) continue
        if (day.kind === 'workout') workout++
        else if (day.kind === 'active_recovery') recovery++
        else if (day.kind === 'lesson') lesson++
        else off++
      }
      map.set(iso, { workout, recovery, lesson, off })
    }
    return map
  }, [tracks, weekDates])

  return (
    <div className="space-y-4">
      <DayCalendarStrip
        weekDates={weekDates}
        countsByDate={countsByDate}
        activeIso={activeIso}
        onSelect={onSelectDay}
      />

      <div className="flex items-baseline justify-between">
        <h2 className="text-lg font-bold text-ink">{formatDate(activeIso)}</h2>
        <span className="text-sm text-ink-muted">
          {visibleCells.length} track{visibleCells.length === 1 ? '' : 's'}
        </span>
      </div>

      {dayLoading ? (
        <Card>
          <p className="text-sm text-ink-muted">Loading…</p>
        </Card>
      ) : visibleCells.length === 0 ? (
        <Card>
          <p className="text-sm text-ink-secondary">
            No tracks have a day for {formatDate(activeIso)}.
          </p>
        </Card>
      ) : (
        <div className="grid gap-3 [grid-template-columns:repeat(auto-fill,minmax(420px,1fr))]">
          {visibleCells.map((cell) => (
            <DayTrackCard
              key={cell.track.track_code}
              cell={cell}
              weekStartsOn={weekStartsOn}
              lastUploadJobId={lastUploadJobId}
            />
          ))}
        </div>
      )}
    </div>
  )
}

function DayCalendarStrip({
  weekDates,
  countsByDate,
  activeIso,
  onSelect,
}: {
  weekDates: string[]
  countsByDate: Map<
    string,
    { workout: number; recovery: number; lesson: number; off: number }
  >
  activeIso: string
  onSelect: (iso: string) => void
}) {
  return (
    <div className="-mx-1 flex gap-1.5 overflow-x-auto px-1 pb-1">
      {weekDates.map((iso) => {
        const counts = countsByDate.get(iso) ?? {
          workout: 0,
          recovery: 0,
          lesson: 0,
          off: 0,
        }
        return (
          <DayCalendarPill
            key={iso}
            iso={iso}
            counts={counts}
            active={iso === activeIso}
            onClick={() => onSelect(iso)}
          />
        )
      })}
    </div>
  )
}

function DayCalendarPill({
  iso,
  counts,
  active,
  onClick,
}: {
  iso: string
  counts: { workout: number; recovery: number; lesson: number; off: number }
  active: boolean
  onClick: () => void
}) {
  // Indicators are stacked in priority order: workouts dominate, then
  // recovery, then lesson. Rest/mobility is implicit (it's "tracks not
  // training").
  const indicators: string[] = []
  if (counts.workout > 0) indicators.push(`🏋️ ${counts.workout}`)
  if (counts.recovery > 0) indicators.push(`🤸 ${counts.recovery}`)
  if (counts.lesson > 0) indicators.push(`📚 ${counts.lesson}`)
  return (
    <button
      type="button"
      onClick={onClick}
      className={`flex min-w-[124px] shrink-0 cursor-pointer flex-col items-start gap-1 rounded-[var(--radius-card)] border px-3 py-2 text-left transition-colors ${
        active
          ? 'border-fbb-orange bg-fbb-orange-tint shadow-[0_4px_12px_rgba(15,23,42,0.08)]'
          : 'border-divider bg-card hover:border-fbb-orange/40'
      }`}
    >
      <div className="flex items-baseline gap-1.5">
        <span className="text-[11px] font-semibold uppercase tracking-wider text-ink-muted">
          {weekdayLabel(iso)}
        </span>
        <span className="text-[15px] font-bold text-ink">
          {monthDayShort(iso)}
        </span>
      </div>
      {indicators.length > 0 ? (
        <span className="text-[10px] text-ink-muted">
          {indicators.join(' · ')}
        </span>
      ) : null}
    </button>
  )
}

function DayTrackCard({
  cell,
  weekStartsOn,
  lastUploadJobId,
}: {
  cell: TrainingWeekDayCell
  weekStartsOn: string
  lastUploadJobId: string | null
}) {
  const { track, day } = cell
  const { sectionCount, exerciseCount } = countDay(day)
  const tone = kindToneOf(day.kind)
  const looksUnderparsed =
    (day.kind === 'workout' || day.kind === 'active_recovery') &&
    exerciseCount === 0
  return (
    <div className="flex flex-col rounded-[var(--radius-card)] bg-card shadow-[0_2px_8px_rgba(15,23,42,0.06)]">
      <header className="flex items-start justify-between gap-2 border-b border-divider px-4 py-3">
        <div className="min-w-0">
          <div className="truncate text-[14px] font-semibold text-ink">
            {track.display_name}
          </div>
          <div className="mt-0.5 flex flex-wrap items-center gap-1.5">
            <Badge tone="info">{FAMILY_LABEL[track.family]}</Badge>
            {track.cadence ? (
              <Badge tone="orange">{track.cadence}</Badge>
            ) : null}
            {track.microcycle.week_position != null ? (
              <Badge tone="neutral">W{track.microcycle.week_position}</Badge>
            ) : null}
          </div>
        </div>
        <div className="flex shrink-0 flex-col items-end gap-1">
          <Badge tone={tone}>{humanize(day.kind)}</Badge>
          {day.is_optional ? <Badge tone="neutral">Optional</Badge> : null}
        </div>
      </header>
      {sectionCount > 0 ? (
        <div className="border-b border-divider px-4 py-2 text-[11px] text-ink-muted">
          📋 {sectionCount} {sectionCount === 1 ? 'section' : 'sections'} · 💪{' '}
          {exerciseCount} {exerciseCount === 1 ? 'exercise' : 'exercises'}
        </div>
      ) : null}
      <div className="px-4 py-3">
        {day.kind === 'lesson' ? <LessonBody day={day} /> : null}
        {day.sections.length > 0 ? (
          <div className="space-y-2">
            {day.sections.map((s) => (
              <SectionDrawer
                key={s.position}
                section={s}
                defaultOpen={false}
              />
            ))}
          </div>
        ) : looksUnderparsed ? (
          <UnderparsedDayCallout
            trackCode={track.track_code}
            scheduledOn={day.scheduled_on}
            weekStartsOn={weekStartsOn}
            lastUploadJobId={lastUploadJobId}
          />
        ) : null}
      </div>
    </div>
  )
}

function TrackPanel({
  track,
  selectedDay,
  onSelectDay,
  weekStartsOn,
  lastUploadJobId,
}: {
  track: TrainingWeekTrackIndex
  selectedDay: string | null
  onSelectDay: (iso: string) => void
  weekStartsOn: string
  lastUploadJobId: string | null
}) {
  // The selected day is anchored on calendar date, not track position, so it
  // survives switching tracks (you stay on the same day-of-week). Falls back
  // to the first workout, otherwise the first day in the track.
  const activeIso = useMemo(() => {
    if (selectedDay && track.days.some((d) => d.scheduled_on === selectedDay))
      return selectedDay
    return (
      track.days.find((d) => d.kind === 'workout')?.scheduled_on ??
      track.days[0]?.scheduled_on ??
      null
    )
  }, [track, selectedDay])

  // Day-detail returns every track's full content for the active calendar
  // day; we filter to this track's cell. RQ caches per (week, day), so the
  // payload is shared with Day view when the user toggles between them.
  const { record: dayDetail, loading: dayLoading } = useTrainingWeekDay(
    weekStartsOn,
    activeIso,
  )

  const activeCell =
    dayDetail?.cells.find((c) => c.track.track_code === track.track_code) ??
    null

  return (
    <div className="space-y-4">
      <DayStrip
        days={track.days}
        activeIso={activeIso}
        onSelect={onSelectDay}
      />

      {dayLoading ? (
        <Card>
          <p className="text-sm text-ink-muted">Loading…</p>
        </Card>
      ) : activeCell ? (
        <DayPanel
          day={activeCell.day}
          trackCode={track.track_code}
          weekStartsOn={weekStartsOn}
          lastUploadJobId={lastUploadJobId}
        />
      ) : null}
    </div>
  )
}


function DayStrip({
  days,
  activeIso,
  onSelect,
}: {
  days: TrainingWeekDayMeta[]
  activeIso: string | null
  onSelect: (iso: string) => void
}) {
  return (
    <div className="-mx-1 flex gap-1.5 overflow-x-auto px-1 pb-1">
      {days.map((d) => (
        <DayPill
          key={d.scheduled_on}
          day={d}
          active={d.scheduled_on === activeIso}
          onClick={() => onSelect(d.scheduled_on)}
        />
      ))}
    </div>
  )
}

function DayPill({
  day,
  active,
  onClick,
}: {
  day: TrainingWeekDayMeta
  active: boolean
  onClick: () => void
}) {
  const tone = kindToneOf(day.kind)
  return (
    <button
      type="button"
      onClick={onClick}
      className={`flex min-w-[124px] shrink-0 cursor-pointer flex-col items-start gap-1 rounded-[var(--radius-card)] border px-3 py-2 text-left transition-colors ${
        active
          ? 'border-fbb-orange bg-fbb-orange-tint shadow-[0_4px_12px_rgba(15,23,42,0.08)]'
          : 'border-divider bg-card hover:border-fbb-orange/40'
      }`}
    >
      <div className="flex items-baseline gap-1.5">
        <span className="text-[11px] font-semibold uppercase tracking-wider text-ink-muted">
          {weekdayLabel(day.scheduled_on)}
        </span>
        <span className="text-[15px] font-bold text-ink">
          {monthDayShort(day.scheduled_on)}
        </span>
      </div>
      <Badge tone={tone}>{humanize(day.kind)}</Badge>
      {day.exercise_count > 0 ? (
        <span className="text-[10px] text-ink-muted">
          💪 {day.exercise_count}
        </span>
      ) : null}
    </button>
  )
}

function DayPanel({
  day,
  trackCode,
  weekStartsOn,
  lastUploadJobId,
}: {
  day: ParsedDay
  trackCode: string
  weekStartsOn: string
  lastUploadJobId: string | null
}) {
  const { sectionCount, exerciseCount } = countDay(day)
  const tone = kindToneOf(day.kind)
  const cleanName = day.display_name.replace(/^Week \d+ Day \d+ - /, '')
  // Show the reparse affordance only when a programming day came back empty.
  // Lesson/rest/mobility days legitimately have no exercises; surfacing a
  // retry button there would invite no-op re-runs.
  const looksUnderparsed =
    (day.kind === 'workout' || day.kind === 'active_recovery') &&
    exerciseCount === 0
  return (
    <div className="rounded-[var(--radius-card)] bg-card shadow-[0_2px_8px_rgba(15,23,42,0.06)]">
      <header className="flex flex-wrap items-end justify-between gap-3 border-b border-divider px-5 py-4">
        <div>
          <div className="text-[11px] font-semibold uppercase tracking-wider text-ink-muted">
            {weekdayLabel(day.scheduled_on)} ·{' '}
            {formatDate(day.scheduled_on).replace(/^\w+, /, '')}
          </div>
          <h2 className="mt-1 text-lg font-bold text-ink">{cleanName}</h2>
        </div>
        <div className="flex flex-wrap items-center gap-1.5">
          <Badge tone={tone}>{humanize(day.kind)}</Badge>
          {day.is_optional ? <Badge tone="neutral">Optional</Badge> : null}
          {sectionCount > 0 ? (
            <span className="text-[12px] text-ink-muted">
              📋 {sectionCount} {sectionCount === 1 ? 'section' : 'sections'} ·
              💪 {exerciseCount}{' '}
              {exerciseCount === 1 ? 'exercise' : 'exercises'}
            </span>
          ) : null}
        </div>
      </header>
      <div className="px-5 py-4">
        {day.kind === 'lesson' ? <LessonBody day={day} /> : null}
        {day.sections.length > 0 ? (
          <div className="grid gap-3 [grid-template-columns:repeat(auto-fill,minmax(360px,1fr))]">
            {day.sections.map((s) => (
              <SectionDrawer key={s.position} section={s} />
            ))}
          </div>
        ) : looksUnderparsed ? (
          <UnderparsedDayCallout
            trackCode={trackCode}
            scheduledOn={day.scheduled_on}
            weekStartsOn={weekStartsOn}
            lastUploadJobId={lastUploadJobId}
          />
        ) : day.kind !== 'lesson' ? (
          <p className="py-6 text-center text-sm text-ink-muted">
            No structured sections.
          </p>
        ) : null}
      </div>
    </div>
  )
}

function UnderparsedDayCallout({
  trackCode,
  scheduledOn,
  weekStartsOn,
  lastUploadJobId,
}: {
  trackCode: string
  scheduledOn: string
  weekStartsOn: string
  lastUploadJobId: string | null
}) {
  const queryClient = useQueryClient()
  const [state, setState] = useState<'idle' | 'running' | 'failed'>('idle')
  const [error, setError] = useState<string | null>(null)

  const handleClick = async () => {
    if (!lastUploadJobId) return
    setState('running')
    setError(null)
    try {
      await retryUploadJobDays(lastUploadJobId, [`${trackCode}/${scheduledOn}`])
      await pollUploadJobUntilDone(lastUploadJobId)
      await queryClient.invalidateQueries({
        queryKey: trainingWeeksKeys.detail(weekStartsOn),
      })
      setState('idle')
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err))
      setState('failed')
    }
  }

  return (
    <div className="flex flex-col items-center gap-3 rounded-md border border-dashed border-warning/40 bg-warning/5 px-6 py-8 text-center">
      <span className="text-2xl" aria-hidden>
        ⚠️
      </span>
      <div>
        <p className="text-sm font-semibold text-ink">
          No exercises were parsed for this day
        </p>
        <p className="mt-1 max-w-md text-[13px] text-ink-muted">
          The PDF text for this day was processed but the parser returned no
          sections. Reparse to take another pass with a fresh LLM call.
        </p>
      </div>
      {lastUploadJobId ? (
        <>
          <button
            type="button"
            onClick={handleClick}
            disabled={state === 'running'}
            className="inline-flex h-10 cursor-pointer items-center gap-2 rounded-[var(--radius-button)] bg-fbb-orange px-5 text-sm font-semibold text-white transition-colors hover:bg-fbb-orange-dark disabled:cursor-not-allowed disabled:opacity-60"
          >
            {state === 'running' ? (
              <>
                <Spinner /> Reparsing…
              </>
            ) : (
              <>↻ Reparse this day</>
            )}
          </button>
          {state === 'failed' && error ? (
            <p className="text-[12px] text-danger">{error}</p>
          ) : null}
        </>
      ) : (
        <p className="text-[12px] text-ink-muted">
          Reparse unavailable — re-upload the PDF to enable retries.
        </p>
      )}
    </div>
  )
}

function WeekNavLink({
  iso,
  direction,
  searchParams,
}: {
  iso: string | null
  direction: 'prev' | 'next'
  searchParams: URLSearchParams
}) {
  // When jumping to a sibling week, we keep view + family/cadence (user prefs)
  // but drop `day` and `track` — the previous week's calendar dates and track
  // codes don't necessarily exist in the next one, and the page's fallbacks
  // re-derive sensible defaults.
  const arrow = direction === 'prev' ? '←' : '→'
  if (!iso) {
    return (
      <span
        className="grid h-9 w-9 place-items-center rounded-full border border-divider text-ink-muted opacity-40"
        aria-hidden
        title={direction === 'prev' ? 'No earlier week' : 'No later week'}
      >
        {arrow}
      </span>
    )
  }
  const next = new URLSearchParams(searchParams)
  next.delete('day')
  next.delete('track')
  const qs = next.toString()
  return (
    <Link
      to={`/training-weeks/${iso}${qs ? `?${qs}` : ''}`}
      replace
      aria-label={direction === 'prev' ? 'Previous week' : 'Next week'}
      className="grid h-9 w-9 cursor-pointer place-items-center rounded-full border border-divider bg-card text-ink-muted transition-colors hover:border-fbb-orange/60 hover:text-fbb-orange-dark"
    >
      {arrow}
    </Link>
  )
}

function Spinner() {
  return (
    <svg
      className="h-3 w-3 animate-spin"
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
    >
      <circle
        className="opacity-25"
        cx="12"
        cy="12"
        r="10"
        stroke="currentColor"
        strokeWidth="4"
      />
      <path
        className="opacity-75"
        fill="currentColor"
        d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"
      />
    </svg>
  )
}

function MatrixView({
  weekStartsOn,
  tracks,
  onPickCell,
}: {
  weekStartsOn: string
  tracks: TrainingWeekTrackIndex[]
  onPickCell: (track: TrainingWeekTrackIndex, iso: string) => void
}) {
  const weekDates = useMemo(() => {
    const out: string[] = []
    const base = new Date(`${weekStartsOn}T00:00:00Z`)
    for (let i = 0; i < 7; i++) {
      const d = new Date(base)
      d.setUTCDate(d.getUTCDate() + i)
      out.push(d.toISOString().slice(0, 10))
    }
    return out
  }, [weekStartsOn])

  const grouped = useMemo(() => {
    const byFamily = new Map<TrackFamily, TrainingWeekTrackIndex[]>()
    for (const t of tracks) {
      const list = byFamily.get(t.family) ?? []
      list.push(t)
      byFamily.set(t.family, list)
    }
    return FAMILY_ORDER.filter((f) => byFamily.has(f)).map((f) => ({
      family: f,
      tracks: byFamily.get(f)!,
    }))
  }, [tracks])

  return (
    <div className="overflow-auto rounded-[var(--radius-card)] bg-card shadow-[0_2px_8px_rgba(15,23,42,0.06)]">
      <table className="w-full table-fixed border-separate border-spacing-0 text-xs">
        <thead>
          <tr>
            <th className="sticky left-0 top-0 z-20 w-[140px] border-b border-divider bg-card px-3 py-2 text-left text-[10px] font-semibold uppercase tracking-wider text-ink-muted">
              Track
            </th>
            {weekDates.map((iso) => (
              <th
                key={iso}
                className="sticky top-0 z-10 border-b border-divider bg-card px-3 py-2 text-left"
              >
                <div className="text-[10px] font-semibold uppercase tracking-wider text-ink-muted">
                  {weekdayLabel(iso)}
                </div>
                <div className="font-mono text-[12px] text-ink">
                  {monthDayShort(iso)}
                </div>
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {grouped.map(({ family, tracks: famTracks }) => (
            <Fragment key={family}>
              <tr>
                <td
                  colSpan={1 + weekDates.length}
                  className="sticky left-0 z-10 border-b border-divider bg-fbb-teal-tint/40 px-3 py-1.5 text-[10px] font-bold uppercase tracking-wider text-ink-secondary"
                >
                  {FAMILY_LABEL[family]}
                </td>
              </tr>
              {famTracks.map((t) => (
                <tr key={t.track_code}>
                  <th className="sticky left-0 z-10 border-b border-divider bg-card px-3 py-2 text-left align-top">
                    <div className="text-[12px] font-semibold text-ink">
                      {t.display_name}
                    </div>
                    <div className="mt-0.5 flex items-center gap-1">
                      {t.cadence ? (
                        <span className="rounded bg-fbb-orange-tint px-1.5 py-0.5 font-mono text-[9px] font-semibold text-fbb-orange-dark">
                          {t.cadence}
                        </span>
                      ) : null}
                      {t.microcycle.week_position != null ? (
                        <span className="font-mono text-[9px] text-ink-muted">
                          W{t.microcycle.week_position}
                        </span>
                      ) : null}
                    </div>
                  </th>
                  {weekDates.map((iso) => {
                    const day = t.days.find((d) => d.scheduled_on === iso)
                    return (
                      <td
                        key={iso}
                        className="border-b border-divider align-top"
                      >
                        {day ? (
                          <MatrixCell
                            day={day}
                            onClick={() => onPickCell(t, iso)}
                          />
                        ) : (
                          <div className="h-[92px] bg-surface/30" />
                        )}
                      </td>
                    )
                  })}
                </tr>
              ))}
            </Fragment>
          ))}
        </tbody>
      </table>
    </div>
  )
}

function MatrixCell({
  day,
  onClick,
}: {
  day: TrainingWeekDayMeta
  onClick: () => void
}) {
  const tone = kindToneOf(day.kind)
  const cleanName = day.display_name.replace(/^Week \d+ Day \d+ - /, '')
  const stripeClass: Record<'orange' | 'info' | 'neutral', string> = {
    orange: 'border-l-fbb-orange',
    info: 'border-l-fbb-teal',
    neutral: 'border-l-divider',
  }
  return (
    <button
      type="button"
      onClick={onClick}
      className={`flex h-[92px] w-full cursor-pointer flex-col items-start gap-1 overflow-hidden border-l-4 px-3 py-2 text-left transition-colors hover:bg-fbb-orange-tint/30 ${stripeClass[tone]}`}
    >
      <Badge tone={tone}>{humanize(day.kind)}</Badge>
      {day.section_count > 0 ? (
        <span className="line-clamp-1 text-[11px] font-medium text-ink">
          {cleanName}
        </span>
      ) : null}
      {day.exercise_count > 0 ? (
        <span className="text-[10px] text-ink-muted">
          📋 {day.section_count} · 💪 {day.exercise_count}
        </span>
      ) : null}
      {day.is_optional ? (
        <span className="text-[10px] text-ink-muted">Optional</span>
      ) : null}
    </button>
  )
}

function kindToneOf(kind: string): 'orange' | 'info' | 'neutral' {
  if (kind === 'workout') return 'orange'
  if (kind === 'active_recovery') return 'info'
  return 'neutral'
}

function countDay(day: ParsedDay): {
  sectionCount: number
  groupCount: number
  exerciseCount: number
} {
  const sectionCount = day.sections.length
  const groupCount = day.sections.reduce((s, sec) => s + sec.groups.length, 0)
  const exerciseCount = day.sections.reduce(
    (s, sec) => s + sec.groups.reduce((gs, g) => gs + g.exercises.length, 0),
    0,
  )
  return { sectionCount, groupCount, exerciseCount }
}

function monthDayShort(iso: string): string {
  const d = new Date(`${iso}T00:00:00Z`)
  return d.toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
    timeZone: 'UTC',
  })
}

// snake_case → Title Case. Backend enums (kind, prescription_mode, set_kind,
// microcycle.kind, etc.) ship as snake_case; we humanize at the render boundary
// rather than maintaining a parallel display map for every enum variant.
function humanize(s: string | null | undefined): string {
  if (!s) return ''
  return s
    .split('_')
    .map((w) => (w ? w.charAt(0).toUpperCase() + w.slice(1) : w))
    .join(' ')
}

function LessonBody({ day }: { day: ParsedDay }) {
  const note = day.coaching_notes[0]
  if (!note) return null
  return (
    <div className="rounded-md bg-fbb-orange-tint/40 p-3 text-sm leading-relaxed text-ink-secondary">
      <div className="text-xs font-semibold uppercase tracking-wider text-fbb-orange-dark">
        {humanize(note.kind)}
      </div>
      <div className="mt-1 whitespace-pre-wrap text-[13px]">
        {note.body_markdown}
      </div>
    </div>
  )
}

function SectionDrawer({
  section,
  defaultOpen = true,
}: {
  section: ParsedSection
  defaultOpen?: boolean
}) {
  return (
    <details
      open={defaultOpen}
      className="group rounded-md border border-divider bg-surface/40"
    >
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
              <span>{humanize(section.kind)}</span>
              <span>·</span>
              <span>{humanize(section.prescription_mode)}</span>
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
      <span className="text-ink">{humanize(set.set_kind)}</span>
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
  const parts: string[] = [humanize(g.prescription_mode)]
  if (g.round_count_min) {
    if (g.round_count_max && g.round_count_max !== g.round_count_min)
      parts.push(`${g.round_count_min}-${g.round_count_max} rounds`)
    else parts.push(`${g.round_count_min} rounds`)
  }
  if (g.interval_seconds) parts.push(`every ${g.interval_seconds}s`)
  if (g.cap_seconds) parts.push(`cap ${g.cap_seconds}s`)
  return parts.join(' · ')
}
