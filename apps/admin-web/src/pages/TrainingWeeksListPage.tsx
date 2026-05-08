import { useMemo, useState } from 'react'
import { useNavigate } from '@tanstack/react-router'
import { useQueryClient } from '@tanstack/react-query'

import { deleteTrainingWeek } from '../api/training-weeks'
import { TrainingWeeksTable } from '../components/TrainingWeeksTable'
import { UploadDialog } from '../components/UploadDialog'
import { Button } from '../components/ui/Button'
import { EmptyState } from '../components/ui/EmptyState'
import {
  trainingWeeksKeys,
  useTrainingWeeks,
} from '../hooks/useTrainingWeeks'
import type { TrainingWeekSummary } from '@byow/types'

export function TrainingWeeksListPage() {
  const { records, loading, error, refresh } = useTrainingWeeks()
  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const [uploadOpen, setUploadOpen] = useState(false)
  const [pendingDelete, setPendingDelete] =
    useState<TrainingWeekSummary | null>(null)
  const [deleting, setDeleting] = useState(false)
  const [deleteError, setDeleteError] = useState<string | null>(null)

  const stats = useMemo(() => {
    const dayCount = records.reduce((s, r) => s + r.day_count, 0)
    const parsedDays = records.reduce((s, r) => s + r.parsed_day_count, 0)
    const underparsedDays = records.reduce(
      (s, r) => s + r.underparsed_day_count,
      0,
    )
    const lastUpdated = records.reduce<string | null>((acc, r) => {
      if (!acc || r.last_persisted_at > acc) return r.last_persisted_at
      return acc
    }, null)
    const coveragePct =
      dayCount > 0 ? Math.round((parsedDays / dayCount) * 100) : 0
    return { dayCount, parsedDays, underparsedDays, lastUpdated, coveragePct }
  }, [records])

  const empty = !loading && records.length === 0

  const handleConfirmDelete = async () => {
    if (!pendingDelete) return
    setDeleting(true)
    setDeleteError(null)
    try {
      await deleteTrainingWeek(pendingDelete.week_starts_on)
      await queryClient.invalidateQueries({
        queryKey: trainingWeeksKeys.list(),
      })
      setPendingDelete(null)
    } catch (err) {
      setDeleteError(err instanceof Error ? err.message : String(err))
    } finally {
      setDeleting(false)
    }
  }

  return (
    <>
      <div className="mb-6 flex flex-col gap-3 md:flex-row md:items-end md:justify-between">
        <div>
          <h1 className="text-[28px] font-bold leading-tight text-ink">
            Training Weeks
          </h1>
          <p className="mt-1 text-sm text-ink-muted">
            Persisted programming weeks. Drop a Persist PDF to add or refresh
            a week.
          </p>
        </div>
        <Button onClick={() => setUploadOpen(true)} icon={<UploadIcon />}>
          Upload PDF
        </Button>
      </div>

      {error ? (
        <div className="mb-4 rounded-[var(--radius-card)] bg-danger/10 px-4 py-3 text-sm text-danger">
          Failed to load training weeks: {error}
        </div>
      ) : null}

      {!empty && !loading ? <OperationsStripe stats={stats} /> : null}

      {loading ? (
        <div className="rounded-[var(--radius-card)] bg-card px-6 py-12 text-center text-sm text-ink-muted shadow-[0_2px_8px_rgba(15,23,42,0.06)]">
          Loading…
        </div>
      ) : empty ? (
        <div className="rounded-[var(--radius-card)] bg-card shadow-[0_2px_8px_rgba(15,23,42,0.06)]">
          <EmptyState
            icon={<UploadIcon size={28} />}
            title="No training weeks yet"
            description="Drop a Persist weekly PDF to parse it into a structured training week. Run as a dry-run first if you just want to test the segmenter."
            action={
              <Button onClick={() => setUploadOpen(true)} icon={<UploadIcon />}>
                Upload your first PDF
              </Button>
            }
          />
        </div>
      ) : (
        <TrainingWeeksTable
          records={records}
          onRequestDelete={setPendingDelete}
        />
      )}

      <UploadDialog
        open={uploadOpen}
        onClose={() => setUploadOpen(false)}
        onUploaded={(weekStartsOn) => {
          refresh()
          if (weekStartsOn) {
            void navigate({
              to: '/training-weeks/$weekStartsOn',
              params: { weekStartsOn },
            })
          }
        }}
      />

      {pendingDelete ? (
        <DeleteConfirm
          record={pendingDelete}
          deleting={deleting}
          error={deleteError}
          onCancel={() => {
            if (!deleting) {
              setPendingDelete(null)
              setDeleteError(null)
            }
          }}
          onConfirm={handleConfirmDelete}
        />
      ) : null}
    </>
  )
}

interface Stats {
  dayCount: number
  parsedDays: number
  underparsedDays: number
  lastUpdated: string | null
  coveragePct: number
}

function OperationsStripe({ stats }: { stats: Stats }) {
  return (
    <div className="mb-6 grid grid-cols-1 divide-y divide-divider rounded-[var(--radius-card)] bg-card shadow-[0_2px_8px_rgba(15,23,42,0.06)] sm:grid-cols-3 sm:divide-x sm:divide-y-0">
      <Metric
        label="Coverage"
        tone={stats.coveragePct >= 100 ? 'success' : 'warning'}
      >
        📊 {stats.parsedDays}/{stats.dayCount} days{' '}
        <span className="font-normal text-ink-muted">
          ({stats.coveragePct}%)
        </span>
      </Metric>
      <Metric
        label="Issues"
        tone={stats.underparsedDays === 0 ? 'success' : 'warning'}
      >
        {stats.underparsedDays === 0 ? (
          <>✓ All days parsed</>
        ) : (
          <>
            ⚠ {stats.underparsedDays} day
            {stats.underparsedDays === 1 ? '' : 's'} need reparse
          </>
        )}
      </Metric>
      <Metric label="Last upload">
        🕐{' '}
        {stats.lastUpdated ? formatRelative(stats.lastUpdated) : '—'}
      </Metric>
    </div>
  )
}

function Metric({
  label,
  tone,
  children,
}: {
  label: string
  tone?: 'success' | 'warning'
  children: React.ReactNode
}) {
  const toneClass =
    tone === 'success'
      ? 'text-success'
      : tone === 'warning'
        ? 'text-warning'
        : 'text-ink'
  return (
    <div className="px-5 py-4">
      <div className="text-[10px] font-semibold uppercase tracking-wider text-ink-muted">
        {label}
      </div>
      <div className={`mt-1 text-[14px] font-semibold ${toneClass}`}>
        {children}
      </div>
    </div>
  )
}

function DeleteConfirm({
  record,
  deleting,
  error,
  onCancel,
  onConfirm,
}: {
  record: TrainingWeekSummary
  deleting: boolean
  error: string | null
  onCancel: () => void
  onConfirm: () => void
}) {
  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-ink/40 px-4"
      onClick={onCancel}
      role="presentation"
    >
      <div
        className="w-full max-w-md rounded-[var(--radius-card)] bg-card p-6 shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        <h2 className="text-lg font-bold text-ink">
          Delete week of {formatDate(record.week_starts_on)}?
        </h2>
        <p className="mt-2 text-sm text-ink-secondary">
          This permanently removes {record.track_count} track
          {record.track_count === 1 ? '' : 's'} and {record.day_count} days of
          programming. The original PDF stays on file — re-upload to restore.
        </p>
        {error ? (
          <p className="mt-3 rounded-md bg-danger/10 px-3 py-2 text-sm text-danger">
            {error}
          </p>
        ) : null}
        <div className="mt-6 flex items-center justify-end gap-2">
          <button
            type="button"
            onClick={onCancel}
            disabled={deleting}
            className="cursor-pointer rounded-[var(--radius-button)] border border-divider bg-card px-4 py-2 text-sm font-semibold text-ink transition-colors hover:bg-surface disabled:cursor-not-allowed disabled:opacity-60"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={onConfirm}
            disabled={deleting}
            className="cursor-pointer rounded-[var(--radius-button)] bg-danger px-4 py-2 text-sm font-semibold text-white transition-colors hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
          >
            {deleting ? 'Deleting…' : 'Delete'}
          </button>
        </div>
      </div>
    </div>
  )
}

function formatDate(iso: string): string {
  if (!iso) return '—'
  const d = new Date(`${iso}T00:00:00Z`)
  return d.toLocaleDateString(undefined, {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    timeZone: 'UTC',
  })
}

function formatRelative(iso: string): string {
  if (!iso) return '—'
  const ms = Date.now() - Date.parse(iso)
  const sec = Math.floor(ms / 1000)
  if (sec < 60) return `${sec}s ago`
  const min = Math.floor(sec / 60)
  if (min < 60) return `${min}m ago`
  const hr = Math.floor(min / 60)
  if (hr < 24) return `${hr}h ago`
  const day = Math.floor(hr / 24)
  if (day < 7) return `${day}d ago`
  return new Date(iso).toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
  })
}

function UploadIcon({ size = 18 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <path
        d="M12 16V4M12 4L7 9M12 4L17 9M5 19H19"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  )
}
