import { useQuery } from '@tanstack/react-query'

import { listAdminUsers, type AdminUserRow } from '../api/users'

export const adminUsersKeys = {
  all: ['admin-users'] as const,
  list: () => [...adminUsersKeys.all, 'list'] as const,
}

export function useAdminUsers(): {
  records: AdminUserRow[]
  loading: boolean
  error: string | null
} {
  const query = useQuery({
    queryKey: adminUsersKeys.list(),
    queryFn: ({ signal }) => listAdminUsers(signal),
  })

  return {
    records: query.data ?? [],
    loading: query.isLoading,
    error: query.error instanceof Error ? query.error.message : null,
  }
}
