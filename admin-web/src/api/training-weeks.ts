// Single Responsibility: HTTP transport for the training-weeks endpoint. No
// caching, no storage side-effects — those live in storage/ and hooks/.

import type { UploadResponse } from '../types'

export interface UploadOptions {
  file: File
  dryRun?: boolean
  signal?: AbortSignal
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
  const form = new FormData()
  form.append('file', opts.file)
  if (opts.dryRun) form.append('dry_run', 'true')

  const res = await fetch('/api/v1/training-weeks/upload', {
    method: 'POST',
    body: form,
    signal: opts.signal,
  })

  if (!res.ok) {
    let body: unknown
    try {
      body = await res.json()
    } catch {
      body = await res.text()
    }
    const message =
      typeof body === 'object' && body !== null && 'message' in body
        ? String((body as { message: unknown }).message)
        : `upload failed (${res.status})`
    throw new UploadError(message, res.status, body)
  }

  return (await res.json()) as UploadResponse
}
