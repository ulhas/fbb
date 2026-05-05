import { useCallback, useEffect, useRef, useState } from 'react'
import type { ChangeEvent, DragEvent } from 'react'

import { uploadTrainingWeek, UploadError } from '../api/training-weeks'
import { recordFromUpload } from '../storage/training-weeks'
import { useTrainingWeeks } from '../hooks/useTrainingWeeks'
import { Badge } from './ui/Badge'
import { Button } from './ui/Button'

// Modal dialog with drag-and-drop. Three states: idle (file picker), parsing
// (progress + ms-by-ms stage hint), result (warnings + a "View detail" CTA
// that closes the dialog and navigates to the new record). The component
// owns its own state — the parent passes `open` and `onClose` only.

const MAX_BYTES = 10 * 1024 * 1024 // matches API; extra magic-bytes check happens server-side

type DialogState =
  | { kind: 'idle' }
  | { kind: 'parsing'; filename: string; dryRun: boolean; startedAt: number }
  | {
      kind: 'done'
      filename: string
      newRecordId: string
      tracks: number
      days: number
      warnings: number
    }
  | { kind: 'error'; filename: string; message: string }

export function UploadDialog({
  open,
  onClose,
  onUploaded,
}: {
  open: boolean
  onClose: () => void
  onUploaded: (recordId: string) => void
}) {
  const { add } = useTrainingWeeks()
  const [state, setState] = useState<DialogState>({ kind: 'idle' })
  const [dragActive, setDragActive] = useState(false)
  const [dryRun, setDryRun] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)
  const abortRef = useRef<AbortController | null>(null)

  // Reset to idle whenever the dialog reopens — leaves "done" / "error"
  // visible until the user dismisses, which is a more forgiving UX than
  // blowing away the result.
  useEffect(() => {
    if (open && state.kind === 'idle') return
    if (!open) {
      abortRef.current?.abort()
      setState({ kind: 'idle' })
      setDryRun(false)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open])

  const startUpload = useCallback(
    async (file: File) => {
      if (file.size > MAX_BYTES) {
        setState({
          kind: 'error',
          filename: file.name,
          message: `file is ${(file.size / 1024 / 1024).toFixed(1)}MB, over the 10MB cap`,
        })
        return
      }
      abortRef.current?.abort()
      const ctl = new AbortController()
      abortRef.current = ctl
      const startedAt = Date.now()
      setState({ kind: 'parsing', filename: file.name, dryRun, startedAt })
      try {
        const response = await uploadTrainingWeek({
          file,
          dryRun,
          signal: ctl.signal,
        })
        const record = recordFromUpload(file.name, response)
        add(record)
        const days =
          response.document?.tracks.reduce((s, t) => s + t.days.length, 0) ??
          response.dry_run?.day_count ??
          0
        const tracks =
          response.document?.tracks.length ??
          response.dry_run?.track_count ??
          0
        setState({
          kind: 'done',
          filename: file.name,
          newRecordId: record.id,
          tracks,
          days,
          warnings: response.parse_warnings.length,
        })
      } catch (err) {
        if (ctl.signal.aborted) return
        const message =
          err instanceof UploadError
            ? `${err.status}: ${err.message}`
            : err instanceof Error
              ? err.message
              : 'unknown error'
        setState({ kind: 'error', filename: file.name, message })
      }
    },
    [add, dryRun],
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
          {state.kind === 'idle' ? (
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
                    ? 'border-fbb-orange bg-fbb-orange-tint'
                    : 'border-divider bg-surface hover:border-fbb-orange/60 hover:bg-fbb-orange-tint/40'
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

              <label className="mt-4 flex cursor-pointer items-start gap-2 text-sm text-ink-secondary">
                <input
                  type="checkbox"
                  checked={dryRun}
                  onChange={(e) => setDryRun(e.target.checked)}
                  className="mt-1 h-4 w-4 accent-fbb-orange"
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

          {state.kind === 'parsing' ? <ParsingView state={state} /> : null}

          {state.kind === 'done' ? (
            <DoneView
              state={state}
              onView={() => {
                onUploaded(state.newRecordId)
                onClose()
              }}
              onAnother={() => setState({ kind: 'idle' })}
            />
          ) : null}

          {state.kind === 'error' ? (
            <ErrorView
              state={state}
              onRetry={() => setState({ kind: 'idle' })}
            />
          ) : null}
        </div>
      </div>
    </div>
  )
}

function ParsingView({
  state,
}: {
  state: { kind: 'parsing'; filename: string; dryRun: boolean; startedAt: number }
}) {
  const [elapsed, setElapsed] = useState(0)
  useEffect(() => {
    const id = window.setInterval(() => {
      setElapsed(Date.now() - state.startedAt)
    }, 200)
    return () => window.clearInterval(id)
  }, [state.startedAt])
  return (
    <div className="rounded-[var(--radius-card)] bg-surface px-6 py-8 text-center">
      <Spinner />
      <div className="mt-4 text-sm font-semibold text-ink">
        Parsing {state.filename}
      </div>
      <div className="mt-1 text-xs text-ink-muted">
        {state.dryRun
          ? 'Extracting text and segmenting (dry run)…'
          : 'Extracting → segmenting → calling the model per day…'}
      </div>
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
  state: {
    kind: 'done'
    filename: string
    newRecordId: string
    tracks: number
    days: number
    warnings: number
  }
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
  state: { kind: 'error'; filename: string; message: string }
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
      className="text-fbb-orange"
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
      className="mx-auto h-9 w-9 animate-spin text-fbb-orange"
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
