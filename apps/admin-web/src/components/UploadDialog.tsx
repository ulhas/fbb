import { useCallback, useEffect, useRef, useState } from 'react'
import type { ChangeEvent, DragEvent } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'

import {
  UploadError,
  uploadTrainingWeek,
  type UploadJobStatus,
  type UploadOptions,
} from '../api/upload-jobs'
import type { ModelSpec } from '@byow/types'

function errorMessage(err: unknown): string {
  if (err instanceof UploadError) return `${err.status}: ${err.message}`
  if (err instanceof Error) return err.message
  return 'unknown error'
}
import { trainingWeeksKeys } from '../hooks/useTrainingWeeks'
import { ModelPicker } from './ModelPicker'
import { Badge } from './ui/Badge'
import { Button } from './ui/Button'

// Modal dialog with drag-and-drop. Three states: idle (file picker), parsing
// (progress + ms-by-ms stage hint), result (warnings + a "View detail" CTA
// that closes the dialog and navigates to the new record). The component
// owns its own state — the parent passes `open` and `onClose` only.

const MAX_BYTES = 10 * 1024 * 1024 // matches API; extra magic-bytes check happens server-side

// State the dialog needs *in addition* to the mutation's status: the filename
// of the in-flight or completed upload, and the live `jobStatus` that the
// long-poll surfaces via onStatus. The mutation itself owns pending/success/
// error transitions.
interface InFlight {
  filename: string
  startedAt: number
  dryRun: boolean
  jobStatus: UploadJobStatus
}

interface UploadResult {
  filename: string
  // Persisted week the upload landed on (null for dry-runs, which don't write
  // anything to the relational tables). The list page navigates to the new
  // week's detail when present.
  weekStartsOn: string | null
  tracks: number
  days: number
  warnings: number
}

export function UploadDialog({
  open,
  onClose,
  onUploaded,
}: {
  open: boolean
  onClose: () => void
  onUploaded: (weekStartsOn: string | null) => void
}) {
  const queryClient = useQueryClient()
  const [inFlight, setInFlight] = useState<InFlight | null>(null)
  const [oversizeError, setOversizeError] = useState<string | null>(null)
  const [dragActive, setDragActive] = useState(false)
  const [dryRun, setDryRun] = useState(false)
  // Selected model. ModelPicker resolves the env-default catalog entry on
  // mount and pushes it up via onChange — start at null so the user can see
  // the default appear once the catalog loads.
  const [modelSpec, setModelSpec] = useState<ModelSpec | null>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)
  const abortRef = useRef<AbortController | null>(null)

  const mutation = useMutation<UploadResult, unknown, { file: File; dryRun: boolean; modelSpec: ModelSpec | null }>({
    mutationFn: async ({ file, dryRun: dr, modelSpec: spec }) => {
      const ctl = new AbortController()
      abortRef.current = ctl
      const opts: UploadOptions = {
        file,
        dryRun: dr,
        modelSpec: spec ?? undefined,
        signal: ctl.signal,
        onStatus: (jobStatus) => {
          setInFlight((prev) => (prev ? { ...prev, jobStatus } : prev))
        },
      }
      const response = await uploadTrainingWeek(opts)
      const days =
        response.document?.tracks.reduce((s, t) => s + t.days.length, 0) ??
        response.dry_run?.day_count ??
        0
      const tracks =
        response.document?.tracks.length ??
        response.dry_run?.track_count ??
        0
      return {
        filename: file.name,
        weekStartsOn:
          response.document?.week_starts_on ??
          response.dry_run?.week_starts_on ??
          null,
        tracks,
        days,
        warnings: response.parse_warnings.length,
      }
    },
    onSuccess: () => {
      // List page should pick up the new row immediately.
      void queryClient.invalidateQueries({ queryKey: trainingWeeksKeys.list() })
    },
  })

  // Reset to idle whenever the dialog closes — leaves "done" / "error"
  // visible until the user dismisses, which is a more forgiving UX than
  // blowing away the result.
  useEffect(() => {
    if (!open) {
      abortRef.current?.abort()
      mutation.reset()
      setInFlight(null)
      setOversizeError(null)
      setDryRun(false)
      setModelSpec(null)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open])

  const startUpload = useCallback(
    (file: File) => {
      setOversizeError(null)
      if (file.size > MAX_BYTES) {
        setOversizeError(
          `file is ${(file.size / 1024 / 1024).toFixed(1)}MB, over the 10MB cap`,
        )
        setInFlight({
          filename: file.name,
          startedAt: Date.now(),
          dryRun,
          jobStatus: 'queued',
        })
        return
      }
      setInFlight({
        filename: file.name,
        startedAt: Date.now(),
        dryRun,
        jobStatus: 'queued',
      })
      mutation.mutate({ file, dryRun, modelSpec })
    },
    [dryRun, modelSpec, mutation],
  )

  const onFileSelected = (e: ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (file) void startUpload(file)
    e.target.value = ''
  }

  const onDrop = (e: DragEvent<HTMLDivElement>) => {
    e.preventDefault()
    e.stopPropagation()
    setDragActive(false)
    const file = e.dataTransfer.files?.[0]
    if (file) void startUpload(file)
  }

  if (!open) return null

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-ink/40 backdrop-blur-sm"
      role="dialog"
      aria-modal="true"
      aria-labelledby="upload-title"
      onClick={onClose}
    >
      <div
        className="w-full max-w-lg rounded-[var(--radius-card)] bg-card shadow-[0_24px_48px_rgba(15,23,42,0.18)]"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between px-6 pt-6 pb-2">
          <div>
            <h2
              id="upload-title"
              className="text-[22px] font-semibold leading-tight text-ink"
            >
              Upload a training week
            </h2>
            <p className="mt-1 text-sm text-ink-muted">
              Persist weekly newsletter PDF — parsed into a structured training week.
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="rounded-md p-1 text-ink-muted hover:bg-surface"
            aria-label="Close"
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
              <path
                d="M6 6L18 18M18 6L6 18"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
              />
            </svg>
          </button>
        </div>

        <div className="px-6 pb-6">
          {mutation.isIdle && !oversizeError ? (
            <>
              <div
                onDragOver={(e) => {
                  e.preventDefault()
                  setDragActive(true)
                }}
                onDragLeave={() => setDragActive(false)}
                onDrop={onDrop}
                onClick={() => fileInputRef.current?.click()}
                className={`flex cursor-pointer flex-col items-center justify-center rounded-[var(--radius-card)] border-2 border-dashed px-6 py-10 text-center transition-colors ${
                  dragActive
                    ? 'border-byow-orange bg-byow-orange-tint'
                    : 'border-divider bg-surface hover:border-byow-orange/60 hover:bg-byow-orange-tint/40'
                }`}
              >
                <DropIcon />
                <div className="mt-3 text-sm font-semibold text-ink">
                  Drop a PDF here or click to browse
                </div>
                <div className="mt-1 text-xs text-ink-muted">
                  application/pdf · up to 10 MB
                </div>
                <input
                  ref={fileInputRef}
                  type="file"
                  accept="application/pdf"
                  className="hidden"
                  onChange={onFileSelected}
                />
              </div>

              <div className="mt-4 rounded-[var(--radius-card)] border border-divider bg-surface p-3">
                <ModelPicker value={modelSpec} onChange={setModelSpec} />
              </div>

              <label className="mt-4 flex cursor-pointer items-start gap-2 text-sm text-ink-secondary">
                <input
                  type="checkbox"
                  checked={dryRun}
                  onChange={(e) => setDryRun(e.target.checked)}
                  className="mt-1 h-4 w-4 accent-byow-orange"
                />
                <span>
                  <span className="font-medium text-ink">Dry run</span>
                  <span className="ml-2 text-ink-muted">
                    segmenter only, no LLM cost
                  </span>
                </span>
              </label>
            </>
          ) : null}

          {mutation.isPending && inFlight ? <ParsingView state={inFlight} /> : null}

          {mutation.isSuccess && mutation.data ? (
            <DoneView
              state={mutation.data}
              onView={() => {
                onUploaded(mutation.data.weekStartsOn)
                onClose()
              }}
              onAnother={() => {
                mutation.reset()
                setInFlight(null)
              }}
            />
          ) : null}

          {oversizeError && inFlight ? (
            <ErrorView
              state={{ filename: inFlight.filename, message: oversizeError }}
              onRetry={() => {
                setOversizeError(null)
                setInFlight(null)
              }}
            />
          ) : null}

          {mutation.isError && inFlight ? (
            <ErrorView
              state={{
                filename: inFlight.filename,
                message: errorMessage(mutation.error),
              }}
              onRetry={() => {
                mutation.reset()
                setInFlight(null)
              }}
            />
          ) : null}
        </div>
      </div>
    </div>
  )
}

function ParsingView({ state }: { state: InFlight }) {
  const [elapsed, setElapsed] = useState(0)
  useEffect(() => {
    const id = window.setInterval(() => {
      setElapsed(Date.now() - state.startedAt)
    }, 200)
    return () => window.clearInterval(id)
  }, [state.startedAt])
  const phase =
    state.jobStatus === 'queued'
      ? 'Queued — waiting for worker'
      : state.dryRun
        ? 'Extracting text and segmenting (dry run)…'
        : 'Extracting → segmenting → calling the model per day…'
  return (
    <div className="rounded-[var(--radius-card)] bg-surface px-6 py-8 text-center">
      <Spinner />
      <div className="mt-4 text-sm font-semibold text-ink">
        Parsing {state.filename}
      </div>
      <div className="mt-1 text-xs text-ink-muted">{phase}</div>
      <div className="mt-4 font-mono text-xs text-ink-muted tabular-nums">
        {(elapsed / 1000).toFixed(1)}s elapsed
      </div>
    </div>
  )
}

function DoneView({
  state,
  onView,
  onAnother,
}: {
  state: UploadResult
  onView: () => void
  onAnother: () => void
}) {
  return (
    <div className="rounded-[var(--radius-card)] border border-success/30 bg-[#E6F6EE] px-5 py-5">
      <div className="flex items-start gap-3">
        <CheckIcon />
        <div className="flex-1">
          <div className="text-sm font-semibold text-ink">Parsed successfully</div>
          <div className="mt-1 text-sm text-ink-secondary">
            {state.filename} · {state.tracks} tracks · {state.days} days
          </div>
          <div className="mt-3 flex flex-wrap gap-1.5">
            <Badge tone="success">{state.tracks} tracks</Badge>
            <Badge tone="info">{state.days} days</Badge>
            {state.warnings > 0 ? (
              <Badge tone="warning">{state.warnings} warnings</Badge>
            ) : (
              <Badge tone="success">0 warnings</Badge>
            )}
          </div>
        </div>
      </div>
      <div className="mt-5 flex justify-end gap-2">
        <Button variant="secondary" size="sm" onClick={onAnother}>
          Upload another
        </Button>
        <Button size="sm" onClick={onView}>
          View detail
        </Button>
      </div>
    </div>
  )
}

function ErrorView({
  state,
  onRetry,
}: {
  state: { filename: string; message: string }
  onRetry: () => void
}) {
  return (
    <div className="rounded-[var(--radius-card)] border border-danger/30 bg-[#FCE7E7] px-5 py-5">
      <div className="text-sm font-semibold text-ink">Upload failed</div>
      <div className="mt-1 text-sm text-ink-secondary">
        {state.filename} — {state.message}
      </div>
      <div className="mt-4 flex justify-end">
        <Button variant="secondary" size="sm" onClick={onRetry}>
          Try again
        </Button>
      </div>
    </div>
  )
}

function DropIcon() {
  return (
    <svg
      width="40"
      height="40"
      viewBox="0 0 24 24"
      fill="none"
      className="text-byow-orange"
    >
      <path
        d="M12 16V4M12 4L7 9M12 4L17 9"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M5 19H19"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
      />
    </svg>
  )
}

function CheckIcon() {
  return (
    <svg
      width="22"
      height="22"
      viewBox="0 0 24 24"
      fill="none"
      className="text-success shrink-0"
    >
      <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="2" />
      <path
        d="M8 12L11 15L16 9"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  )
}

function Spinner() {
  return (
    <svg
      className="mx-auto h-9 w-9 animate-spin text-byow-orange"
      viewBox="0 0 24 24"
      fill="none"
    >
      <circle
        className="opacity-20"
        cx="12"
        cy="12"
        r="10"
        stroke="currentColor"
        strokeWidth="4"
      />
      <path
        className="opacity-90"
        fill="currentColor"
        d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"
      />
    </svg>
  )
}
