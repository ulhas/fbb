// TanStack Query wrappers around the training-weeks endpoints. Components
// consume these instead of calling fetch directly so caching, dedup, and
// invalidation are handled by the query client.

import { useQuery } from '@tanstack/react-query'

import {
  fetchTrainingWeek,
  fetchTrainingWeekDay,
  listTrainingWeeks,
  type TrainingWeekDayDetail,
  type TrainingWeekDetail,
  type TrainingWeekSummary,
} from '../api/training-weeks'

export const trainingWeeksKeys = {
  all: ['training-weeks'] as const,
  list: () => [...trainingWeeksKeys.all, 'list'] as const,
  detail: (weekStartsOn: string) =>
    [...trainingWeeksKeys.all, 'detail', weekStartsOn] as const,
  day: (weekStartsOn: string, scheduledOn: string) =>
    [...trainingWeeksKeys.all, 'day', weekStartsOn, scheduledOn] as const,
}

export function useTrainingWeeks(): {
  records: TrainingWeekSummary[]
  loading: boolean
  error: string | null
  refresh: () => void
} {
  const query = useQuery({
    queryKey: trainingWeeksKeys.list(),
    queryFn: ({ signal }) => listTrainingWeeks(signal),
  })

  return {
    records: query.data ?? [],
    loading: query.isLoading,
    error: query.error instanceof Error ? query.error.message : null,
    refresh: () => {
      void query.refetch()
    },
  }
}

// Detail-page hook keyed by `week_starts_on` (ISO date). Returns the slim
// index — tracks + days metadata, no exercise content. Pair with
// `useTrainingWeekDay` for the day's body.
export function useTrainingWeek(weekStartsOn: string | undefined): {
  record: TrainingWeekDetail | null
  loading: boolean
  error: string | null
} {
  const query = useQuery({
    queryKey: weekStartsOn
      ? trainingWeeksKeys.detail(weekStartsOn)
      : trainingWeeksKeys.detail('__none__'),
    queryFn: ({ signal }) => fetchTrainingWeek(weekStartsOn!, signal),
    enabled: Boolean(weekStartsOn),
  })

  return {
    record: query.data ?? null,
    loading: query.isLoading,
    error: query.error instanceof Error ? query.error.message : null,
  }
}

// Per-day full content. Cached per (weekStartsOn, scheduledOn) so toggling
// between Track and Day view on the same day reuses the same payload.
export function useTrainingWeekDay(
  weekStartsOn: string | undefined,
  scheduledOn: string | null,
): {
  record: TrainingWeekDayDetail | null
  loading: boolean
  error: string | null
} {
  const query = useQuery({
    queryKey:
      weekStartsOn && scheduledOn
        ? trainingWeeksKeys.day(weekStartsOn, scheduledOn)
        : trainingWeeksKeys.day('__none__', '__none__'),
    queryFn: ({ signal }) =>
      fetchTrainingWeekDay(weekStartsOn!, scheduledOn!, signal),
    enabled: Boolean(weekStartsOn && scheduledOn),
  })

  return {
    record: query.data ?? null,
    loading: query.isLoading,
    error: query.error instanceof Error ? query.error.message : null,
  }
}
