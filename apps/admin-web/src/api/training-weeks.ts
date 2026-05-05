// Single Responsibility: HTTP transport for the training-weeks read endpoints.
// /training-weeks reads persisted week data (relational tables); the upload
// pipeline that creates that data lives in api/upload-jobs.ts.

import type {
  TrainingWeekDayDetail,
  TrainingWeekDetail,
  TrainingWeekSummary,
} from '@fbb/types'

export type { TrainingWeekDayDetail, TrainingWeekDetail, TrainingWeekSummary }

export class ApiError extends Error {
  readonly status: number
  readonly body: unknown

  constructor(message: string, status: number, body?: unknown) {
    super(message)
    this.name = 'ApiError'
    this.status = status
    this.body = body
  }
}

export async function listTrainingWeeks(
  signal?: AbortSignal,
): Promise<TrainingWeekSummary[]> {
  const res = await fetch('/api/v1/training-weeks', { signal })
  if (!res.ok) throw await readError(res)
  return (await res.json()) as TrainingWeekSummary[]
}

export async function fetchTrainingWeek(
  weekStartsOn: string,
  signal?: AbortSignal,
): Promise<TrainingWeekDetail> {
  const res = await fetch(
    `/api/v1/training-weeks/${encodeURIComponent(weekStartsOn)}`,
    { signal },
  )
  if (!res.ok) throw await readError(res)
  return (await res.json()) as TrainingWeekDetail
}

// Heavy lift: full sections/groups/exercises/sets across every track for one
// calendar day. The slim index (`fetchTrainingWeek`) carries no body content
// so any view that needs to render exercise data hits this endpoint.
export async function fetchTrainingWeekDay(
  weekStartsOn: string,
  scheduledOn: string,
  signal?: AbortSignal,
): Promise<TrainingWeekDayDetail> {
  const res = await fetch(
    `/api/v1/training-weeks/${encodeURIComponent(weekStartsOn)}/days/${encodeURIComponent(scheduledOn)}`,
    { signal },
  )
  if (!res.ok) throw await readError(res)
  return (await res.json()) as TrainingWeekDayDetail
}

// Wipes the persisted week (microcycles + cascades). Idempotent on the
// upload-job side — the job + PDF stay intact, so re-uploading rebuilds.
export async function deleteTrainingWeek(weekStartsOn: string): Promise<void> {
  const res = await fetch(
    `/api/v1/training-weeks/${encodeURIComponent(weekStartsOn)}`,
    { method: 'DELETE' },
  )
  if (!res.ok) throw await readError(res)
}

async function readError(res: Response): Promise<ApiError> {
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
  return new ApiError(message, res.status, body)
}
