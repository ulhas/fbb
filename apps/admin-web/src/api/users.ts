// HTTP transport for the admin /users list. Admin-scope is decided server-side
// by AdminGuard against the bearer token; this module is unaware of auth.

import type { AdminUserRow } from '@fbb/types'

export type { AdminUserRow }

export class UsersApiError extends Error {
  readonly status: number
  readonly body: unknown

  constructor(message: string, status: number, body?: unknown) {
    super(message)
    this.name = 'UsersApiError'
    this.status = status
    this.body = body
  }
}

export async function listAdminUsers(
  signal?: AbortSignal,
): Promise<AdminUserRow[]> {
  const res = await fetch('/api/v1/users', { signal })
  if (!res.ok) throw await readError(res)
  return (await res.json()) as AdminUserRow[]
}

async function readError(res: Response): Promise<UsersApiError> {
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
  return new UsersApiError(message, res.status, body)
}
