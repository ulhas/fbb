// Single Responsibility: persist the parsed training-week records in
// localStorage so the admin can refresh / share a tab without losing recent
// uploads. Pure functions; no React. This file knows nothing about HTTP.
//
// The schema is versioned (`STORAGE_KEY` ends in `:v1`) so a future API
// shape change can bump the key and start fresh without crashing on
// stale entries.

import type {
  ParseMetrics,
  ParseWarning,
  ParsedDocument,
  TrainingWeekRecord,
  UploadResponse,
} from '../types'

const STORAGE_KEY = 'fbb.admin.training-weeks:v1'

function readAll(): TrainingWeekRecord[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return []
    const parsed: unknown = JSON.parse(raw)
    if (!Array.isArray(parsed)) return []
    return parsed as TrainingWeekRecord[]
  } catch {
    // Corrupt JSON — drop it so the user isn't stuck with a broken state.
    return []
  }
}

function writeAll(records: TrainingWeekRecord[]): void {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(records))
}

export function listTrainingWeeks(): TrainingWeekRecord[] {
  return readAll().sort((a, b) => b.uploaded_at.localeCompare(a.uploaded_at))
}

export function getTrainingWeek(id: string): TrainingWeekRecord | null {
  return readAll().find((r) => r.id === id) ?? null
}

export function saveTrainingWeek(record: TrainingWeekRecord): void {
  const all = readAll().filter((r) => r.id !== record.id)
  all.push(record)
  writeAll(all)
}

export function deleteTrainingWeek(id: string): void {
  writeAll(readAll().filter((r) => r.id !== id))
}

export function clearTrainingWeeks(): void {
  localStorage.removeItem(STORAGE_KEY)
}

// Convenience: turn an UploadResponse into a TrainingWeekRecord. Done here
// so the controller (UploadDialog) doesn't need to know the wrap shape.
export function recordFromUpload(
  filename: string,
  response: UploadResponse,
): TrainingWeekRecord {
  const document: ParsedDocument | null = response.document
  const warnings: ParseWarning[] = response.parse_warnings ?? []
  const metrics: ParseMetrics = response.parse_metrics

  return {
    id: response.request_id,
    uploaded_at: new Date().toISOString(),
    source_filename: filename,
    week_starts_on:
      document?.week_starts_on ?? response.dry_run?.week_starts_on ?? '',
    document,
    parse_warnings: warnings,
    parse_metrics: metrics,
    dry_run_only: response.dry_run != null && document == null,
  }
}
