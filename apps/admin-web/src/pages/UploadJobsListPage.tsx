import { UploadJobsTable } from '../components/UploadJobsTable'
import { EmptyState } from '../components/ui/EmptyState'
import { useUploadJobs } from '../hooks/useUploadJobs'

export function UploadJobsListPage() {
  const { records, loading, error } = useUploadJobs()
  const empty = !loading && records.length === 0

  return (
    <>
      <div className="mb-6">
        <h1 className="text-[28px] font-bold leading-tight text-ink">
          Upload Jobs
        </h1>
        <p className="mt-1 text-sm text-ink-muted">
          Every PDF that's been parsed (or attempted). Click a row to view the
          source PDF alongside the parse output.
        </p>
      </div>

      {error ? (
        <div className="mb-4 rounded-[var(--radius-card)] bg-danger/10 px-4 py-3 text-sm text-danger">
          Failed to load upload jobs: {error}
        </div>
      ) : null}

      {loading ? (
        <div className="rounded-[var(--radius-card)] bg-card px-6 py-12 text-center text-sm text-ink-muted shadow-[0_2px_8px_rgba(15,23,42,0.06)]">
          Loading…
        </div>
      ) : empty ? (
        <div className="rounded-[var(--radius-card)] bg-card shadow-[0_2px_8px_rgba(15,23,42,0.06)]">
          <EmptyState
            icon={<UploadIcon size={28} />}
            title="No upload jobs yet"
            description="Upload a Persist PDF from the Training Weeks page and the job will show up here."
          />
        </div>
      ) : (
        <UploadJobsTable records={records} />
      )}
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
