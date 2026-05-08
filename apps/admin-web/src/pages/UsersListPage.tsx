import { UsersTable } from '../components/UsersTable'
import { EmptyState } from '../components/ui/EmptyState'
import { useAdminUsers } from '../hooks/useAdminUsers'

export function UsersListPage() {
  const { records, loading, error } = useAdminUsers()
  const empty = !loading && records.length === 0

  return (
    <>
      <div className="mb-6">
        <h1 className="text-[28px] font-bold leading-tight text-ink">Users</h1>
        <p className="mt-1 text-sm text-ink-muted">
          Every registered account, with the number of tracks they currently
          follow.
        </p>
      </div>

      {error ? (
        <div className="mb-4 rounded-[var(--radius-card)] bg-danger/10 px-4 py-3 text-sm text-danger">
          Failed to load users: {error}
        </div>
      ) : null}

      {loading ? (
        <div className="rounded-[var(--radius-card)] bg-card px-6 py-12 text-center text-sm text-ink-muted shadow-[0_2px_8px_rgba(15,23,42,0.06)]">
          Loading…
        </div>
      ) : empty ? (
        <div className="rounded-[var(--radius-card)] bg-card shadow-[0_2px_8px_rgba(15,23,42,0.06)]">
          <EmptyState
            icon={<UsersIcon size={28} />}
            title="No users yet"
            description="Users are created on first request from the iOS app. Once someone signs in, they'll show up here."
          />
        </div>
      ) : (
        <UsersTable records={records} />
      )}
    </>
  )
}

function UsersIcon({ size = 18 }: { size?: number }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M16 21v-2a4 4 0 00-4-4H6a4 4 0 00-4 4v2" />
      <circle cx="9" cy="7" r="4" />
      <path d="M22 21v-2a4 4 0 00-3-3.87" />
      <path d="M16 3.13a4 4 0 010 7.75" />
    </svg>
  )
}
