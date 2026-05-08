import { useQuery } from '@tanstack/react-query'

import {
  fetchUploadJob,
  listUploadJobs,
  type UploadJobDetail,
  type UploadJobSummary,
} from '../api/upload-jobs'

export const uploadJobsKeys = {
  all: ['upload-jobs'] as const,
  list: () => [...uploadJobsKeys.all, 'list'] as const,
  detail: (id: string) => [...uploadJobsKeys.all, 'detail', id] as const,
}

export function useUploadJobs(): {
  records: UploadJobSummary[]
  loading: boolean
  error: string | null
} {
  const query = useQuery({
    queryKey: uploadJobsKeys.list(),
    queryFn: ({ signal }) => listUploadJobs(signal),
  })

  return {
    records: query.data ?? [],
    loading: query.isLoading,
    error: query.error instanceof Error ? query.error.message : null,
  }
}

export function useUploadJob(id: string | undefined): {
  record: UploadJobDetail | null
  loading: boolean
  error: string | null
} {
  const query = useQuery({
    queryKey: id ? uploadJobsKeys.detail(id) : uploadJobsKeys.detail('__none__'),
    queryFn: ({ signal }) => fetchUploadJob(id!, signal),
    enabled: Boolean(id),
  })

  return {
    record: query.data ?? null,
    loading: query.isLoading,
    error: query.error instanceof Error ? query.error.message : null,
  }
}
