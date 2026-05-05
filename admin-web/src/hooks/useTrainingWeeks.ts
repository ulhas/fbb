// React-side facade over the storage module. Keeps useState + storage in
// sync via a window event so two tabs see the same list without a refresh.

import { useCallback, useEffect, useState } from 'react'

import {
  deleteTrainingWeek,
  getTrainingWeek,
  listTrainingWeeks,
  saveTrainingWeek,
} from '../storage/training-weeks'
import type { TrainingWeekRecord } from '../types'

const CHANGE_EVENT = 'fbb.admin.training-weeks:change'

function notifyChange(): void {
  window.dispatchEvent(new Event(CHANGE_EVENT))
}

export function useTrainingWeeks(): {
  records: TrainingWeekRecord[]
  add: (record: TrainingWeekRecord) => void
  remove: (id: string) => void
  refresh: () => void
} {
  const [records, setRecords] = useState<TrainingWeekRecord[]>(() =>
    listTrainingWeeks(),
  )

  const refresh = useCallback(() => {
    setRecords(listTrainingWeeks())
  }, [])

  useEffect(() => {
    const onChange = () => refresh()
    const onStorage = (e: StorageEvent) => {
      if (e.key && e.key.startsWith('fbb.admin.training-weeks')) refresh()
    }
    window.addEventListener(CHANGE_EVENT, onChange)
    window.addEventListener('storage', onStorage)
    return () => {
      window.removeEventListener(CHANGE_EVENT, onChange)
      window.removeEventListener('storage', onStorage)
    }
  }, [refresh])

  const add = useCallback((record: TrainingWeekRecord) => {
    saveTrainingWeek(record)
    notifyChange()
  }, [])

  const remove = useCallback((id: string) => {
    deleteTrainingWeek(id)
    notifyChange()
  }, [])

  return { records, add, remove, refresh }
}

// Single-record hook for the detail page. Lazily resolves the record by id
// from storage; returns null while the id isn't present (e.g., user pasted a
// stale URL after clearing storage).
export function useTrainingWeek(id: string | undefined): TrainingWeekRecord | null {
  const [record, setRecord] = useState<TrainingWeekRecord | null>(() =>
    id ? getTrainingWeek(id) : null,
  )

  useEffect(() => {
    setRecord(id ? getTrainingWeek(id) : null)
    const onChange = () => setRecord(id ? getTrainingWeek(id) : null)
    window.addEventListener(CHANGE_EVENT, onChange)
    return () => window.removeEventListener(CHANGE_EVENT, onChange)
  }, [id])

  return record
}
