import type { ReactNode } from 'react'
import { Link, useRouterState } from '@tanstack/react-router'

// Persistent left rail. Active state is derived from the resolved location's
// pathname rather than NavLink-style active matching so we can highlight the
// section when a sub-route (e.g. /upload-jobs/:id) is active without
// re-declaring every leaf.

interface NavItem {
  to: string
  label: string
  icon: () => ReactNode
  matchPrefix: string
}

const NAV: NavItem[] = [
  { to: '/users', label: 'Users', icon: UsersIcon, matchPrefix: '/users' },
  {
    to: '/training-weeks',
    label: 'Training Weeks',
    icon: WeeksIcon,
    matchPrefix: '/training-weeks',
  },
  {
    to: '/upload-jobs',
    label: 'Upload Jobs',
    icon: UploadIcon,
    matchPrefix: '/upload-jobs',
  },
  {
    to: '/system-prompts',
    label: 'System Prompt',
    icon: PromptIcon,
    matchPrefix: '/system-prompts',
  },
]

export function Sidebar() {
  const pathname = useRouterState({ select: (s) => s.location.pathname })

  return (
    <aside className="sticky top-0 flex h-screen w-60 shrink-0 flex-col border-r border-fbb-teal-tint bg-card">
      <div className="flex h-16 items-center gap-2.5 px-5">
        <span className="grid h-9 w-9 place-items-center rounded-[10px] bg-fbb-orange text-white shadow-sm">
          <FBBMark />
        </span>
        <div className="flex flex-col leading-tight">
          <span className="text-[15px] font-semibold text-ink">FBB Persist</span>
          <span className="text-[11px] font-medium uppercase tracking-wider text-ink-muted">
            Admin Console
          </span>
        </div>
      </div>

      <nav className="flex flex-1 flex-col gap-0.5 px-3 py-2">
        {NAV.map((item) => {
          const Icon = item.icon
          const active = pathname === item.matchPrefix || pathname.startsWith(`${item.matchPrefix}/`)
          return (
            <Link
              key={item.to}
              to={item.to}
              className={`flex items-center gap-2.5 rounded-[var(--radius-button)] px-3 py-2 text-sm font-medium transition-colors ${
                active
                  ? 'bg-fbb-orange-tint text-fbb-orange-dark'
                  : 'text-ink-secondary hover:bg-surface'
              }`}
            >
              <Icon />
              <span>{item.label}</span>
            </Link>
          )
        })}
      </nav>

      <div className="px-5 py-4">
        <span className="inline-flex rounded-full bg-fbb-teal-tint px-3 py-1 text-[11px] font-medium text-ink-secondary">
          No-auth dev mode
        </span>
      </div>
    </aside>
  )
}

function FBBMark() {
  return (
    <svg viewBox="0 0 16 16" className="h-4 w-4" aria-hidden="true">
      <rect x="2" y="9" width="3" height="5" rx="1" fill="currentColor" />
      <rect x="6.5" y="6" width="3" height="8" rx="1" fill="currentColor" />
      <rect x="11" y="3" width="3" height="11" rx="1" fill="currentColor" />
    </svg>
  )
}

function UsersIcon() {
  return (
    <svg
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
    >
      <path d="M16 21v-2a4 4 0 00-4-4H6a4 4 0 00-4 4v2" />
      <circle cx="9" cy="7" r="4" />
      <path d="M22 21v-2a4 4 0 00-3-3.87" />
      <path d="M16 3.13a4 4 0 010 7.75" />
    </svg>
  )
}

function WeeksIcon() {
  return (
    <svg
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
    >
      <rect x="3" y="4" width="18" height="18" rx="2" />
      <path d="M16 2v4M8 2v4M3 10h18" />
    </svg>
  )
}

function UploadIcon() {
  return (
    <svg
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
    >
      <path d="M12 16V4M12 4L7 9M12 4L17 9M5 19H19" />
    </svg>
  )
}

function PromptIcon() {
  return (
    <svg
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
    >
      <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" />
      <path d="M14 2v6h6" />
      <path d="M16 13H8M16 17H8M10 9H8" />
    </svg>
  )
}
