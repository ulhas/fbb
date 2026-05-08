import { useEffect, useMemo, useRef, useState } from 'react'
import { Link, createFileRoute, useNavigate } from '@tanstack/react-router'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Document, Page, pdfjs } from 'react-pdf'
import 'react-pdf/dist/Page/AnnotationLayer.css'
import 'react-pdf/dist/Page/TextLayer.css'

import {
  listModelCatalog,
  reparseUploadJobAs,
  uploadJobPdfUrl,
  type ModelCatalogEntry,
} from '../../api/upload-jobs'
import { Badge } from '../../components/ui/Badge'
import { Button } from '../../components/ui/Button'
import { uploadJobsKeys, useUploadJob } from '../../hooks/useUploadJobs'
import type {
  ModelSpec,
  ParseMetrics,
  ParseWarning,
  ReasoningEffort,
  UploadJobStatus,
} from '@fbb/types'

// Bundle the worker through Vite so we don't ship a public/ asset. The worker
// must match the pdfjs-dist version that react-pdf re-exports as `pdfjs`,
// otherwise the runtime errors on `API/Worker version mismatch`. We pin the
// dep at exactly `react-pdf`'s expected version (see package.json) — touch
// both together when bumping.
import workerUrl from 'pdfjs-dist/build/pdf.worker.min.mjs?url'

pdfjs.GlobalWorkerOptions.workerSrc = workerUrl

export const Route = createFileRoute('/upload-jobs/$id')({
  component: UploadJobDetailPage,
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

function UploadJobDetailPage() {
  const { id } = Route.useParams()
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
            className="text-sm font-semibold text-fbb-orange hover:text-fbb-orange-dark"
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
            className="mb-2 inline-flex items-center gap-1 text-xs font-semibold text-fbb-orange hover:text-fbb-orange-dark"
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
  const catalogQuery = useQuery({
    queryKey: ['upload-jobs', 'models'],
    queryFn: ({ signal }) => listModelCatalog(signal),
  })

  // Pre-select the most recently used spec when possible, otherwise the
  // first catalog entry. Effort defaults to whatever the picked entry has on
  // its catalog default.
  const initialKey = (entry: ModelCatalogEntry) =>
    `${entry.spec.provider}/${entry.spec.model}`
  const [selectedKey, setSelectedKey] = useState<string | null>(
    currentSpec ? `${currentSpec.provider}/${currentSpec.model}` : null,
  )
  const [effort, setEffort] = useState<ReasoningEffort | null>(
    currentSpec?.reasoning_effort ?? null,
  )

  const catalog = catalogQuery.data ?? []
  const selected =
    catalog.find((e) => initialKey(e) === selectedKey) ?? catalog[0] ?? null

  const mutation = useMutation({
    mutationFn: (spec: ModelSpec) => reparseUploadJobAs(sourceJobId, spec),
    onSuccess: ({ job_id }) => {
      void queryClient.invalidateQueries({ queryKey: uploadJobsKeys.list() })
      onClose()
      void navigate({ to: '/upload-jobs/$id', params: { id: job_id } })
    },
  })

  const submit = () => {
    if (!selected) return
    const spec: ModelSpec = {
      provider: selected.spec.provider,
      model: selected.spec.model,
      reasoning_effort: selected.supports_reasoning_effort
        ? effort ?? selected.spec.reasoning_effort ?? 'medium'
        : null,
    }
    mutation.mutate(spec)
  }

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

        {catalogQuery.isLoading ? (
          <p className="mt-4 text-sm text-ink-muted">Loading models…</p>
        ) : catalog.length === 0 ? (
          <p className="mt-4 text-sm text-danger">
            No models available. Check API keys.
          </p>
        ) : (
          <div className="mt-4 space-y-3">
            <label className="block text-sm">
              <span className="mb-1 block text-[11px] font-semibold uppercase tracking-wider text-ink-muted">
                Model
              </span>
              <select
                value={selected ? initialKey(selected) : ''}
                onChange={(e) => setSelectedKey(e.target.value)}
                className="w-full cursor-pointer rounded-[var(--radius-button)] border border-divider bg-card px-3 py-2 text-sm text-ink focus:border-fbb-orange focus:outline-none"
              >
                {catalog.map((e) => (
                  <option key={initialKey(e)} value={initialKey(e)}>
                    {e.display_name} ({e.spec.provider}/{e.spec.model})
                  </option>
                ))}
              </select>
            </label>

            {selected?.supports_reasoning_effort ? (
              <label className="block text-sm">
                <span className="mb-1 block text-[11px] font-semibold uppercase tracking-wider text-ink-muted">
                  Reasoning effort
                </span>
                <select
                  value={effort ?? selected.spec.reasoning_effort ?? 'medium'}
                  onChange={(e) =>
                    setEffort(e.target.value as ReasoningEffort)
                  }
                  className="w-full cursor-pointer rounded-[var(--radius-button)] border border-divider bg-card px-3 py-2 text-sm text-ink focus:border-fbb-orange focus:outline-none"
                >
                  <option value="minimal">minimal — cheapest, fastest</option>
                  <option value="low">low</option>
                  <option value="medium">medium — balanced</option>
                  <option value="high">high — slowest, most accurate</option>
                </select>
              </label>
            ) : (
              <p className="text-[12px] text-ink-muted">
                Reasoning effort doesn't apply to this model.
              </p>
            )}
          </div>
        )}

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
            onClick={submit}
            disabled={!selected || mutation.isPending}
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
          className="text-[12px] font-semibold text-fbb-orange hover:text-fbb-orange-dark"
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
                  className="font-mono text-fbb-orange hover:text-fbb-orange-dark"
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
          {dryRunOnly ? (
            <Row label="Dry run" value={<Badge tone="neutral">segmenter only</Badge>} />
          ) : null}
        </dl>
        <div className="mt-3 border-t border-divider pt-3">
          <Link
            to="/upload-jobs/compare"
            search={{ a: sourceJobId }}
            className="text-[12px] font-semibold text-fbb-orange hover:text-fbb-orange-dark"
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
