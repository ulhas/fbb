import type { ReactNode } from 'react'
import { Link, NavLink } from 'react-router-dom'

// White header with a thin teal underline — uses the chrome teal for a quiet
// brand cue without overpowering the orange CTAs that live in the page body.
// Wordmark uses the same orange as the primary action so the brand "owner"
// feels consistent end-to-end.

export function AppShell({ children }: { children: ReactNode }) {
  return (
    <div className="min-h-screen bg-surface">
      <header className="sticky top-0 z-40 border-b border-fbb-teal-tint bg-card/80 backdrop-blur supports-[backdrop-filter]:bg-card/70">
        <div className="mx-auto flex h-16 max-w-7xl items-center justify-between gap-6 px-6">
          <Link to="/" className="flex items-center gap-2.5">
            <span className="grid h-9 w-9 place-items-center rounded-[10px] bg-fbb-orange text-white shadow-sm">
              <FBBMark />
            </span>
            <div className="flex flex-col leading-tight">
              <span className="text-[15px] font-semibold text-ink">
                FBB Persist
              </span>
              <span className="text-[11px] font-medium uppercase tracking-wider text-ink-muted">
                Admin Console
              </span>
            </div>
          </Link>

          <nav className="hidden items-center gap-1 md:flex">
            <NavTab to="/" label="Training Weeks" />
          </nav>

          <div className="flex items-center gap-3">
            <span className="hidden rounded-full bg-fbb-teal-tint px-3 py-1 text-xs font-medium text-ink-secondary md:inline-flex">
              No-auth dev mode
            </span>
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-7xl px-6 py-8">{children}</main>
    </div>
  )
}

function NavTab({ to, label }: { to: string; label: string }) {
  return (
    <NavLink
      to={to}
      end
      className={({ isActive }) =>
        `rounded-full px-3 py-1.5 text-sm font-medium transition-colors ${
          isActive
            ? 'bg-fbb-orange-tint text-fbb-orange-dark'
            : 'text-ink-secondary hover:bg-surface'
        }`
      }
    >
      {label}
    </NavLink>
  )
}

function FBBMark() {
  // Tiny custom mark — three ascending bars (a strength-progression motif
  // that fits the FBB programming language). No external SVG file; cheap.
  return (
    <svg viewBox="0 0 16 16" className="h-4 w-4" aria-hidden="true">
      <rect x="2" y="9" width="3" height="5" rx="1" fill="currentColor" />
      <rect x="6.5" y="6" width="3" height="8" rx="1" fill="currentColor" />
      <rect x="11" y="3" width="3" height="11" rx="1" fill="currentColor" />
    </svg>
  )
}
