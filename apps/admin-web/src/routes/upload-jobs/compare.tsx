import { useMemo } from 'react'
import { Link, createFileRoute } from '@tanstack/react-router'

import { Badge } from '../../components/ui/Badge'
import { useUploadJob, useUploadJobs } from '../../hooks/useUploadJobs'
import type {
  ModelSpec,
  ParseWarning,
  UploadJobDetail,
  UploadJobStatus,
  UploadJobSummary,
} from '@fbb/types'

interface CompareSearch {
  a?: string
  b?: string
}

export const Route = createFileRoute('/upload-jobs/compare')({
  component: ComparePage,
  validateSearch: (raw): CompareSearch => ({
    a: typeof raw.a === 'string' ? raw.a : undefined,
    b: typeof raw.b === 'string' ? raw.b : undefined,
  }),
})

const STATUS_TONE: Record<
  UploadJobStatus,
  'success' | 'warning' | 'info' | 'neutral'
> = {
  succeeded: 'success',
  failed: 'warning',
  running: 'info',
  queued: 'neutral',
}

function ComparePage() {
  const { a, b } = Route.useSearch()
  const aJob = useUploadJob(a)
  const bJob = useUploadJob(b)
  const { records: jobs } = useUploadJobs()

  const aRecord = aJob.record
  const bRecord = bJob.record

  // Pool of candidates the user can pick `b` from: every other job that
  // shares this PDF's filename. Same source → apples-to-apples comparison.
  const peers = useMemo<UploadJobSummary[]>(() => {
    if (!aRecord) return []
    return jobs
      .filter((j) => j.id !== aRecord.id)
      .filter((j) => j.source_filename === aRecord.source_filename)
      .sort((x, y) => y.uploaded_at.localeCompare(x.uploaded_at))
  }, [jobs, aRecord])

  if (!a) {
    return <Empty />
  }

  if (aJob.loading || (b && bJob.loading)) {
    return <LoadingCard />
  }

  if (!aRecord) {
    return <Missing message={aJob.error ?? `No upload job ${a}`} />
  }

  return (
    <>
      <div className="mb-6">
        <Link
          to="/upload-jobs/$id"
          params={{ id: aRecord.id }}
          className="mb-2 inline-flex items-center gap-1 text-xs font-semibold text-fbb-orange hover:text-fbb-orange-dark"
        >
          ← Back to job
        </Link>
        <h1 className="text-[24px] font-bold leading-tight text-ink">
          Compare runs · {aRecord.source_filename}
        </h1>
        <p className="mt-1 text-sm text-ink-muted">
          Side-by-side comparison of two parses of the same PDF. Pick a peer
          run on the right.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <ColumnPanel
          label="Run A"
          record={aRecord}
          peerOptions={peers}
          peerSelectedId={null}
        />
        {bRecord ? (
          <ColumnPanel
            label="Run B"
            record={bRecord}
            peerOptions={peers}
            peerSelectedId={bRecord.id}
            aId={aRecord.id}
          />
        ) : (
          <PickerColumn aId={aRecord.id} peers={peers} />
        )}
      </div>
    </>
  )
}

function ColumnPanel({
  label,
  record,
  peerOptions,
  peerSelectedId,
  aId,
}: {
  label: string
  record: UploadJobDetail
  peerOptions: UploadJobSummary[]
  peerSelectedId: string | null
  aId?: string
}) {
  const tracks = record.document?.tracks ?? []
  const dayCount = tracks.reduce((s, t) => s + t.days.length, 0)
  return (
    <section className="flex flex-col gap-3 rounded-[var(--radius-card)] bg-card p-4 shadow-[0_2px_8px_rgba(15,23,42,0.06)]">
      <header className="flex items-baseline justify-between gap-3">
        <div className="flex items-baseline gap-2">
          <span className="text-[11px] font-semibold uppercase tracking-wider text-ink-muted">
            {label}
          </span>
          <Link
            to="/upload-jobs/$id"
            params={{ id: record.id }}
            className="font-mono text-xs text-fbb-orange hover:text-fbb-orange-dark"
          >
            {record.id.slice(0, 8)}…
          </Link>
        </div>
        <Badge tone={STATUS_TONE[record.status]}>{record.status}</Badge>
      </header>

      <div className="flex flex-col gap-1">
        <ModelLine spec={record.parse_metrics?.model_spec ?? null} />
        <div className="text-[11px] text-ink-muted">
          {new Date(record.uploaded_at).toLocaleString()}
        </div>
      </div>

      <dl className="grid grid-cols-2 gap-x-3 gap-y-2 border-t border-divider pt-3 text-sm">
        <Stat label="Tracks" value={String(tracks.length)} />
        <Stat label="Days" value={String(dayCount)} />
        <Stat
          label="Warnings"
          value={String(record.parse_warnings.length)}
          tone={record.parse_warnings.length === 0 ? 'success' : 'warning'}
        />
        <Stat
          label="Tokens (in)"
          value={record.parse_metrics?.tokens_input_total.toLocaleString() ?? '—'}
        />
        <Stat
          label="Tokens (out)"
          value={record.parse_metrics?.tokens_output_total.toLocaleString() ?? '—'}
        />
        <Stat
          label="LLM time"
          value={formatMs(record.parse_metrics?.llm_total_ms)}
        />
      </dl>

      <WarningsList warnings={record.parse_warnings} />

      {peerOptions.length > 0 && peerSelectedId && aId ? (
        <PeerSwitcher aId={aId} peers={peerOptions} currentId={peerSelectedId} />
      ) : null}
    </section>
  )
}

function PickerColumn({
  aId,
  peers,
}: {
  aId: string
  peers: UploadJobSummary[]
}) {
  return (
    <section className="flex flex-col gap-3 rounded-[var(--radius-card)] border-2 border-dashed border-divider bg-surface p-6 text-center">
      <h2 className="text-[11px] font-semibold uppercase tracking-wider text-ink-muted">
        Run B
      </h2>
      {peers.length === 0 ? (
        <p className="text-sm text-ink-secondary">
          No other runs of this PDF yet. Use{' '}
          <span className="font-semibold text-ink">Reparse with…</span> on the
          job detail page to spawn another model's run.
        </p>
      ) : (
        <>
          <p className="text-sm text-ink-secondary">
            Pick another run of this PDF to compare against:
          </p>
          <ul className="mt-2 flex flex-col gap-1 text-left">
            {peers.map((p) => (
              <li key={p.id}>
                <Link
                  to="/upload-jobs/compare"
                  search={{ a: aId, b: p.id }}
                  className="flex items-center justify-between gap-3 rounded-md bg-card px-3 py-2 text-sm hover:bg-fbb-orange-tint/40"
                >
                  <span className="flex flex-col">
                    <span className="text-ink">
                      {p.model_spec?.model ?? '—'}
                    </span>
                    <span className="text-[11px] text-ink-muted">
                      {p.model_spec?.provider}
                      {p.model_spec?.reasoning_effort
                        ? ` · ${p.model_spec.reasoning_effort}`
                        : ''}
                    </span>
                  </span>
                  <span className="text-[11px] text-ink-muted">
                    {new Date(p.uploaded_at).toLocaleDateString()}
                  </span>
                </Link>
              </li>
            ))}
          </ul>
        </>
      )}
    </section>
  )
}

function PeerSwitcher({
  aId,
  peers,
  currentId,
}: {
  aId: string
  peers: UploadJobSummary[]
  currentId: string
}) {
  if (peers.length <= 1) return null
  return (
    <details className="border-t border-divider pt-3 text-sm">
      <summary className="cursor-pointer text-[12px] font-semibold text-fbb-orange hover:text-fbb-orange-dark">
        Switch peer run
      </summary>
      <ul className="mt-2 flex flex-col gap-1">
        {peers
          .filter((p) => p.id !== currentId)
          .map((p) => (
            <li key={p.id}>
              <Link
                to="/upload-jobs/compare"
                search={{ a: aId, b: p.id }}
                replace
                className="flex items-center justify-between gap-3 rounded-md bg-surface px-3 py-1.5 text-[13px] hover:bg-fbb-orange-tint/40"
              >
                <span>{p.model_spec?.model ?? '—'}</span>
                <span className="text-[11px] text-ink-muted">
                  {p.model_spec?.provider}
                  {p.model_spec?.reasoning_effort
                    ? ` · ${p.model_spec.reasoning_effort}`
                    : ''}
                </span>
              </Link>
            </li>
          ))}
      </ul>
    </details>
  )
}

function ModelLine({ spec }: { spec: ModelSpec | null }) {
  if (!spec) {
    return <span className="text-[12px] text-ink-muted">no model recorded</span>
  }
  return (
    <span className="flex items-baseline gap-2">
      <span className="font-mono text-sm font-semibold text-ink">
        {spec.model}
      </span>
      <span className="text-[11px] text-ink-muted">
        {spec.provider}
        {spec.reasoning_effort ? ` · ${spec.reasoning_effort}` : ''}
      </span>
    </span>
  )
}

function Stat({
  label,
  value,
  tone,
}: {
  label: string
  value: string
  tone?: 'success' | 'warning'
}) {
  const toneClass =
    tone === 'success'
      ? 'text-success'
      : tone === 'warning'
        ? 'text-warning'
        : 'text-ink'
  return (
    <div className="flex flex-col">
      <dt className="text-[10px] font-semibold uppercase tracking-wider text-ink-muted">
        {label}
      </dt>
      <dd className={`tabular-nums text-sm font-semibold ${toneClass}`}>
        {value}
      </dd>
    </div>
  )
}

function WarningsList({ warnings }: { warnings: ParseWarning[] }) {
  if (warnings.length === 0) {
    return (
      <div className="border-t border-divider pt-3 text-sm text-success">
        ✓ No warnings
      </div>
    )
  }
  return (
    <div className="border-t border-divider pt-3">
      <div className="mb-2 text-[11px] font-semibold uppercase tracking-wider text-ink-muted">
        Warnings ({warnings.length})
      </div>
      <ul className="max-h-72 space-y-1.5 overflow-y-auto pr-1">
        {warnings.map((w, i) => (
          <li
            key={`${w.code}-${i}`}
            className="rounded-md bg-warning/5 p-2 text-[12px]"
          >
            <div className="font-mono font-semibold text-warning">
              {w.code}
            </div>
            <div className="mt-0.5 text-ink-secondary">{w.detail}</div>
            {w.locator ? (
              <div className="mt-0.5 font-mono text-[10px] text-ink-muted">
                {w.scope} · {w.locator}
              </div>
            ) : null}
          </li>
        ))}
      </ul>
    </div>
  )
}

function formatMs(ms: number | undefined): string {
  if (!ms) return '—'
  if (ms < 1000) return `${ms}ms`
  return `${(ms / 1000).toFixed(1)}s`
}

function Empty() {
  return (
    <div className="rounded-[var(--radius-card)] bg-card p-12 text-center shadow-[0_2px_8px_rgba(15,23,42,0.06)]">
      <h2 className="text-xl font-semibold text-ink">Pick a job to compare</h2>
      <p className="mt-2 text-sm text-ink-muted">
        Open an upload job and click "Compare with another run" to land here
        with one slot pre-filled.
      </p>
    </div>
  )
}

function LoadingCard() {
  return (
    <div className="rounded-[var(--radius-card)] bg-card p-12 text-center shadow-[0_2px_8px_rgba(15,23,42,0.06)]">
      <p className="text-sm text-ink-muted">Loading…</p>
    </div>
  )
}

function Missing({ message }: { message: string }) {
  return (
    <div className="rounded-[var(--radius-card)] bg-card p-12 text-center shadow-[0_2px_8px_rgba(15,23,42,0.06)]">
      <h2 className="text-xl font-semibold text-ink">Job not found</h2>
      <p className="mt-2 text-sm text-ink-muted">{message}</p>
    </div>
  )
}
