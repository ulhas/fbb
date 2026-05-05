// Single Responsibility: HTTP transport for /upload-jobs. Owns the entire
// upload lifecycle (POST → long-poll status → terminal). /training-weeks
// handles reads of the persisted training-week data only.
//
// The API runs the parse asynchronously: POST returns a job id, the client
// then long-polls the status endpoint until the job is terminal. Each poll
// holds the connection up to ~25s, so a happy-path parse takes one or two
// round-trips. The poll loop keeps reopening until the signal aborts.

import type {
  UploadJobStatus,
  UploadResponse,
} from '@fbb/types'

export type { UploadJobStatus, UploadResponse }

export interface UploadOptions {
  file: File
  dryRun?: boolean
  signal?: AbortSignal
  // Optional progress hook fired on each poll cycle. Useful for showing
  // "still working…" hints; the UI is free to ignore it.
  onStatus?: (status: UploadJobStatus) => void
}

interface UploadAcceptedResponse {
  job_id: string
  status: UploadJobStatus
}

interface UploadStatusResponse {
  job_id: string
  status: UploadJobStatus
  result: UploadResponse | null
  error: string | null
  created_at: string
  started_at: string | null
  finished_at: string | null
}

export class UploadError extends Error {
  readonly status: number
  readonly body: unknown

  constructor(message: string, status: number, body?: unknown) {
    super(message)
    this.name = 'UploadError'
    this.status = status
    this.body = body
  }
}

export async function uploadTrainingWeek(
  opts: UploadOptions,
): Promise<UploadResponse> {
  const accepted = await postUpload(opts)
  opts.onStatus?.(accepted.status)
  return pollUntilDone(accepted.job_id, opts)
}

async function postUpload(opts: UploadOptions): Promise<UploadAcceptedResponse> {
  const form = new FormData()
  form.append('file', opts.file)
  if (opts.dryRun) form.append('dry_run', 'true')

  const res = await fetch('/api/v1/upload-jobs', {
    method: 'POST',
    body: form,
    signal: opts.signal,
  })

  if (!res.ok) throw await readUploadError(res)
  return (await res.json()) as UploadAcceptedResponse
}

async function pollUntilDone(
  jobId: string,
  opts: UploadOptions,
): Promise<UploadResponse> {
  // Loop until the server returns succeeded/failed or the caller aborts. Each
  // iteration is a fresh long-poll request, so the server gets to drop a stale
  // socket and the browser gets a fresh keepalive.
  for (;;) {
    if (opts.signal?.aborted) {
      throw new DOMException('Aborted', 'AbortError')
    }

    const res = await fetch(
      `/api/v1/upload-jobs/${encodeURIComponent(jobId)}/status?wait_ms=25000`,
      { signal: opts.signal },
    )
    if (!res.ok) throw await readUploadError(res)
    const status = (await res.json()) as UploadStatusResponse
    opts.onStatus?.(status.status)

    if (status.status === 'succeeded') {
      if (!status.result) {
        throw new UploadError(
          'job succeeded but server returned no result payload',
          500,
        )
      }
      return status.result
    }
    if (status.status === 'failed') {
      throw new UploadError(status.error ?? 'parse failed', 500, status)
    }
    // queued | running — server timed out the long-poll without completion;
    // loop straight back into the next poll. No client-side delay needed.
  }
}

// Kicks off a re-parse of only the days that failed last time. The server
// flips the job status back to 'running' and returns immediately; clients
// reuse the existing long-poll status endpoint to follow progress.
export async function retryUploadJob(
  jobId: string,
): Promise<{ job_id: string; failed_day_count: number }> {
  const res = await fetch(
    `/api/v1/upload-jobs/${encodeURIComponent(jobId)}/retry`,
    { method: 'POST' },
  )
  if (!res.ok) throw await readUploadError(res)
  return (await res.json()) as { job_id: string; failed_day_count: number }
}

async function readUploadError(res: Response): Promise<UploadError> {
  let body: unknown
  try {
    body = await res.json()
  } catch {
    body = await res.text()
  }
  const message =
    typeof body === 'object' && body !== null && 'message' in body
      ? String((body as { message: unknown }).message)
      : `request failed (${res.status})`
  return new UploadError(message, res.status, body)
}
