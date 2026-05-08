import { useEffect, useMemo, useRef, useState } from 'react'
import { Link, useNavigate, useParams } from '@tanstack/react-router'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { Document, Page, pdfjs } from 'react-pdf'
import 'react-pdf/dist/Page/AnnotationLayer.css'
import 'react-pdf/dist/Page/TextLayer.css'

import {
  reparseUploadJobAs,
  uploadJobPdfUrl,
} from '../api/upload-jobs'
import { ModelPicker } from '../components/ModelPicker'
import { Badge } from '../components/ui/Badge'
import { Button } from '../components/ui/Button'
import { uploadJobsKeys, useUploadJob } from '../hooks/useUploadJobs'
import type {
  ModelSpec,
  ParseMetrics,
  ParseWarning,
  UploadJobStatus,
} from '@byow/types'

// Bundle the worker through Vite so we don't ship a public/ asset. The worker
// must match the pdfjs-dist version that react-pdf re-exports as `pdfjs`,
// otherwise the runtime errors on `API/Worker version mismatch`. We pin the
// dep at exactly `react-pdf`'s expected version (see package.json) — touch
// both together when bumping.
import workerUrl from 'pdfjs-dist/build/pdf.worker.min.mjs?url'

pdfjs.GlobalWorkerOptions.workerSrc = workerUrl

const STATUS_TONE: Record<
  UploadJobStatus,
  'success' | 'warning' | 'info' | 'neutral'
> = {
  succeeded: 'success',
  failed: 'warning',
  running: 'info',
  queued: 'neutral',
}

export function UploadJobDetailPage() {
  const { id } = useParams({ from: '/upload-jobs/$id' })
  const { record, loading, error } = useUploadJob(id)
  const [reparseOpen, setReparseOpen] = useState(false)

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
        <h2 className="text-xl font-semibold text-ink">Job not found</h2>
        <p className="mt-2 text-sm text-ink-muted">
          {error ?? 'No upload job exists with this id.'}
        </p>
        <div className="mt-6">
          <Link
            to="/upload-jobs"
            className="text-sm font-semibold text-byow-orange hover:text-byow-orange-dark"
          >
            ← Back to upload jobs
          </Link>
        </div>
      </div>
    )
  }

  const tracks = record.document?.tracks ?? []
  const dayCount = tracks.reduce((s, t) => s + t.days.length, 0)

  return (
    <>
      <div className="mb-6 flex flex-col gap-3 md:flex-row md:items-end md:justify-between">
        <div className="min-w-0">
          <Link
            to="/upload-jobs"
            className="mb-2 inline-flex items-center gap-1 text-xs font-semibold text-byow-orange hover:text-byow-orange-dark"
          >
            ← Upload jobs
          </Link>
          <h1 className="truncate text-[24px] font-bold leading-tight text-ink">
            {record.source_filename}
          </h1>
          <p className="mt-1 font-mono text-xs text-ink-muted">{record.id}</p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <Badge tone={STATUS_TONE[record.status]}>{record.status}</Badge>
          {tracks.length > 0 ? (
            <Badge tone="info">🏋️ {tracks.length} tracks</Badge>
          ) : null}
          {dayCount > 0 ? <Badge tone="info">📅 {dayCount} days</Badge> : null}
          {record.parse_warnings.length > 0 ? (
            <Badge tone="warning">⚠ {record.parse_warnings.length} warnings</Badge>
          ) : null}
          <Button
            variant="secondary"
            size="sm"
            onClick={() => setReparseOpen(true)}
            disabled={record.status === 'queued' || record.status === 'running'}
          >
            ↻ Reparse with…
          </Button>
        </div>
      </div>

      {record.error ? (
        <div className="mb-4 rounded-[var(--radius-card)] bg-danger/10 px-4 py-3 text-sm text-danger">
          <span className="font-semibold">Failed:</span> {record.error}
        </div>
      ) : null}

      <div className="grid min-h-[70vh] grid-cols-1 gap-4 lg:grid-cols-[minmax(0,1fr)_400px]">
        <PdfPanel jobId={record.id} />
        <SummaryPanel
          warnings={record.parse_warnings}
          weekStartsOn={record.document?.week_starts_on ?? null}
          uploadedAt={record.uploaded_at}
          finishedAt={record.finished_at}
          dryRunOnly={record.dry_run_only}
          metrics={record.parse_metrics}
          sourceJobId={record.id}
        />
      </div>

      {reparseOpen ? (
        <ReparseModal
          sourceJobId={record.id}
          currentSpec={record.parse_metrics?.model_spec ?? null}
          onClose={() => setReparseOpen(false)}
        />
      ) : null}
    </>
  )
}

function ReparseModal({
  sourceJobId,
  currentSpec,
  onClose,
}: {
  sourceJobId: string
  currentSpec: ModelSpec | null
  onClose: () => void
}) {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  // Seed with the source job's spec so the picker opens on the same model
  // the user just inspected; ModelPicker will reset to env-default if the
  // catalog doesn't recognise it.
  const [spec, setSpec] = useState<ModelSpec | null>(currentSpec)

  const mutation = useMutation({
    mutationFn: (s: ModelSpec) => reparseUploadJobAs(sourceJobId, s),
    onSuccess: ({ job_id }) => {
      void queryClient.invalidateQueries({ queryKey: uploadJobsKeys.list() })
      onClose()
      void navigate({ to: '/upload-jobs/$id', params: { id: job_id } })
    },
  })

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-ink/40 px-4"
      onClick={onClose}
      role="presentation"
    >
      <div
        className="w-full max-w-md rounded-[var(--radius-card)] bg-card p-6 shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        <h2 className="text-lg font-bold text-ink">Reparse with another model</h2>
        <p className="mt-1 text-sm text-ink-muted">
          Spawns a new upload job from this PDF using a different provider /
          model. Both runs stay around so you can compare warnings, tokens,
          and parse output.
        </p>

        <div className="mt-4">
          <ModelPicker
            value={spec}
            onChange={setSpec}
            disabled={mutation.isPending}
          />
        </div>

        {mutation.isError ? (
          <p className="mt-3 rounded-md bg-danger/10 px-3 py-2 text-sm text-danger">
            {mutation.error instanceof Error
              ? mutation.error.message
              : 'Reparse failed'}
          </p>
        ) : null}

        <div className="mt-6 flex items-center justify-end gap-2">
          <Button
            variant="secondary"
            size="sm"
            onClick={onClose}
            disabled={mutation.isPending}
          >
            Cancel
          </Button>
          <Button
            size="sm"
            onClick={() => spec && mutation.mutate(spec)}
            disabled={!spec || mutation.isPending}
          >
            {mutation.isPending ? 'Starting…' : 'Reparse'}
          </Button>
        </div>
      </div>
    </div>
  )
}

function PdfPanel({ jobId }: { jobId: string }) {
  const url = useMemo(() => uploadJobPdfUrl(jobId), [jobId])
  const [numPages, setNumPages] = useState<number | null>(null)
  const [width, setWidth] = useState(800)
  const containerRef = useRef<HTMLDivElement | null>(null)

  // Resize the page renderer to fit the container so the PDF stays legible
  // across narrow desktop windows. ResizeObserver beats useLayoutEffect for
  // this since the parent grid can resize at any time (e.g. devtools open).
  useEffect(() => {
    if (!containerRef.current) return
    const el = containerRef.current
    const measure = () => setWidth(el.clientWidth)
    measure()
    const ro = new ResizeObserver(measure)
    ro.observe(el)
    return () => ro.disconnect()
  }, [])

  return (
    <div className="overflow-hidden rounded-[var(--radius-card)] bg-card shadow-[0_2px_8px_rgba(15,23,42,0.06)]">
      <header className="flex items-center justify-between gap-3 border-b border-divider px-4 py-2.5">
        <span className="text-[11px] font-semibold uppercase tracking-wider text-ink-secondary">
          Source PDF {numPages ? `· ${numPages} pages` : ''}
        </span>
        <a
          href={url}
          target="_blank"
          rel="noreferrer"
          className="text-[12px] font-semibold text-byow-orange hover:text-byow-orange-dark"
        >
          Open in new tab ↗
        </a>
      </header>
      <div
        ref={containerRef}
        className="max-h-[80vh] overflow-y-auto bg-surface px-4 py-4"
      >
        <Document
          file={url}
          onLoadSuccess={({ numPages: n }) => setNumPages(n)}
          loading={<p className="py-12 text-center text-sm text-ink-muted">Loading PDF…</p>}
          error={
            <p className="py-12 text-center text-sm text-danger">
              Couldn't load the PDF. The file may have been removed from disk.
            </p>
          }
        >
          {Array.from({ length: numPages ?? 0 }, (_, i) => (
            <div key={i + 1} className="mb-3 shadow-[0_2px_8px_rgba(15,23,42,0.10)]">
              <Page
                pageNumber={i + 1}
                width={width - 32}
                renderAnnotationLayer={false}
                renderTextLayer={false}
              />
            </div>
          ))}
        </Document>
      </div>
    </div>
  )
}

function SummaryPanel({
  warnings,
  weekStartsOn,
  uploadedAt,
  finishedAt,
  dryRunOnly,
  metrics,
  sourceJobId,
}: {
  warnings: ParseWarning[]
  weekStartsOn: string | null
  uploadedAt: string
  finishedAt: string | null
  dryRunOnly: boolean
  metrics: ParseMetrics | null
  sourceJobId: string
}) {
  return (
    <aside className="flex flex-col gap-4">
      <section className="rounded-[var(--radius-card)] bg-card p-4 shadow-[0_2px_8px_rgba(15,23,42,0.06)]">
        <h2 className="text-[11px] font-semibold uppercase tracking-wider text-ink-secondary">
          Summary
        </h2>
        <dl className="mt-3 space-y-2 text-sm">
          {metrics?.model_spec ? (
            <Row
              label="Model"
              value={
                <span className="flex flex-col items-end">
                  <span className="font-mono text-[12px]">
                    {metrics.model_spec.model}
                  </span>
                  <span className="text-[11px] text-ink-muted">
                    {metrics.model_spec.provider}
                    {metrics.model_spec.reasoning_effort
                      ? ` · ${metrics.model_spec.reasoning_effort}`
                      : ''}
                  </span>
                </span>
              }
            />
          ) : null}
          <Row label="Uploaded" value={new Date(uploadedAt).toLocaleString()} />
          <Row
            label="Finished"
            value={finishedAt ? new Date(finishedAt).toLocaleString() : '—'}
          />
          {weekStartsOn ? (
            <Row
              label="Week"
              value={
                <Link
                  to="/training-weeks/$weekStartsOn"
                  params={{ weekStartsOn }}
                  className="font-mono text-byow-orange hover:text-byow-orange-dark"
                >
                  {weekStartsOn}
                </Link>
              }
            />
          ) : null}
          {metrics && metrics.tokens_input_total > 0 ? (
            <Row
              label="Input tokens"
              value={
                <span className="font-mono tabular-nums">
                  {metrics.tokens_input_total.toLocaleString()}
                  {metrics.tokens_cached_input_total &&
                  metrics.tokens_cached_input_total > 0 ? (
                    <span className="ml-1 text-[11px] text-ink-muted">
                      ({metrics.tokens_cached_input_total.toLocaleString()} cached)
                    </span>
                  ) : null}
                </span>
              }
            />
          ) : null}
          {metrics && metrics.tokens_output_total > 0 ? (
            <Row
              label="Output tokens"
              value={
                <span className="font-mono tabular-nums">
                  {metrics.tokens_output_total.toLocaleString()}
                </span>
              }
            />
          ) : null}
          {metrics?.cost_total_usd != null && metrics.cost_total_usd > 0 ? (
            <Row
              label="Cost"
              value={
                <span
                  className="font-mono tabular-nums underline decoration-dotted decoration-ink-muted/40 underline-offset-2"
                  title={[
                    metrics.cost_input_usd != null
                      ? `Input ${formatUsd(metrics.cost_input_usd)}`
                      : null,
                    metrics.cost_cached_input_usd != null &&
                    metrics.cost_cached_input_usd > 0
                      ? `Cached ${formatUsd(metrics.cost_cached_input_usd)}`
                      : null,
                    metrics.cost_output_usd != null
                      ? `Output ${formatUsd(metrics.cost_output_usd)}`
                      : null,
                  ]
                    .filter(Boolean)
                    .join(' · ')}
                >
                  {formatUsd(metrics.cost_total_usd)}
                </span>
              }
            />
          ) : null}
          {dryRunOnly ? (
            <Row label="Dry run" value={<Badge tone="neutral">segmenter only</Badge>} />
          ) : null}
        </dl>
        <div className="mt-3 border-t border-divider pt-3">
          <Link
            to="/upload-jobs/compare"
            search={{ a: sourceJobId }}
            className="text-[12px] font-semibold text-byow-orange hover:text-byow-orange-dark"
          >
            Compare with another run →
          </Link>
        </div>
      </section>

      <section className="rounded-[var(--radius-card)] bg-card p-4 shadow-[0_2px_8px_rgba(15,23,42,0.06)]">
        <h2 className="text-[11px] font-semibold uppercase tracking-wider text-ink-secondary">
          Parse warnings ({warnings.length})
        </h2>
        {warnings.length === 0 ? (
          <p className="mt-3 text-sm text-success">✓ No warnings</p>
        ) : (
          <ul className="mt-3 space-y-2">
            {warnings.map((w, i) => (
              <li
                key={`${w.code}-${i}`}
                className="rounded-md bg-warning/5 p-2.5 text-[13px]"
              >
                <div className="font-mono text-[11px] font-semibold text-warning">
                  {w.code}
                </div>
                <div className="mt-1 text-ink-secondary">{w.detail}</div>
                {w.locator ? (
                  <div className="mt-1 font-mono text-[11px] text-ink-muted">
                    {w.scope} · {w.locator}
                  </div>
                ) : null}
              </li>
            ))}
          </ul>
        )}
      </section>
    </aside>
  )
}

function formatUsd(usd: number): string {
  if (usd >= 0.1) return `$${usd.toFixed(3)}`
  if (usd >= 0.001) return `$${usd.toFixed(4)}`
  return `$${usd.toFixed(6)}`
}

function Row({
  label,
  value,
}: {
  label: string
  value: React.ReactNode
}) {
  return (
    <div className="flex items-baseline justify-between gap-3">
      <dt className="text-[11px] font-semibold uppercase tracking-wider text-ink-muted">
        {label}
      </dt>
      <dd className="min-w-0 text-right text-sm text-ink">{value}</dd>
    </div>
  )
}
