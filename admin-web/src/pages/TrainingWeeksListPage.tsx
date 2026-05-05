import { useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'

import { TrainingWeeksTable } from '../components/TrainingWeeksTable'
import { UploadDialog } from '../components/UploadDialog'
import { Badge } from '../components/ui/Badge'
import { Button } from '../components/ui/Button'
import { EmptyState } from '../components/ui/EmptyState'
import { Stat } from '../components/ui/Stat'
import { useTrainingWeeks } from '../hooks/useTrainingWeeks'

export function TrainingWeeksListPage() {
  const { records, remove } = useTrainingWeeks()
  const [uploadOpen, setUploadOpen] = useState(false)
  const navigate = useNavigate()

  const stats = useMemo(() => {
    const totalDays = records.reduce(
      (s, r) =>
        s +
        (r.document
          ? r.document.tracks.reduce((ss, t) => ss + t.days.length, 0)
          : 0),
      0,
    )
    const totalTokens = records.reduce(
      (s, r) => s + (r.parse_metrics?.tokens_total ?? 0),
      0,
    )
    const totalWarnings = records.reduce(
      (s, r) => s + r.parse_warnings.length,
      0,
    )
    return {
      weekCount: records.length,
      totalDays,
      totalTokens,
      totalWarnings,
    }
  }, [records])

  const empty = records.length === 0

  return (
    <>
      <div className="mb-6 flex flex-col gap-3 md:flex-row md:items-end md:justify-between">
        <div>
          <h1 className="text-[28px] font-bold leading-tight text-ink">
            Training Weeks
          </h1>
          <p className="mt-1 text-sm text-ink-muted">
            Persist programming PDFs uploaded for review. Saved locally in this
            browser — drop another PDF to add a new week.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Badge tone="info">{stats.weekCount} on file</Badge>
          <Button onClick={() => setUploadOpen(true)} icon={<UploadIcon />}>
            Upload PDF
          </Button>
        </div>
      </div>

      {!empty ? (
        <div className="mb-6 grid gap-4 md:grid-cols-4">
          <Stat label="Weeks" value={stats.weekCount} accent="orange" />
          <Stat label="Days parsed" value={stats.totalDays} accent="teal" />
          <Stat
            label="Total tokens"
            value={stats.totalTokens.toLocaleString()}
            hint="Across all uploaded weeks"
          />
          <Stat
            label="Open warnings"
            value={stats.totalWarnings}
            accent={stats.totalWarnings === 0 ? 'success' : 'warning'}
            hint={stats.totalWarnings === 0 ? 'All clean' : 'Review on detail page'}
          />
        </div>
      ) : null}

      {empty ? (
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
        <TrainingWeeksTable records={records} onDelete={remove} />
      )}

      <UploadDialog
        open={uploadOpen}
        onClose={() => setUploadOpen(false)}
        onUploaded={(id) => navigate(`/training-weeks/${id}`)}
      />
    </>
  )
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
