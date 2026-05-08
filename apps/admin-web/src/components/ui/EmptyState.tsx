import type { ReactNode } from 'react'

// Empty state used by the table when no weeks have been uploaded yet. The
// guidance is explicit: empty states are not blank — they are coaching
// surfaces. Show what to do next, with the primary CTA front and centre.

export function EmptyState({
  title,
  description,
  action,
  icon,
}: {
  title: string
  description?: string
  action?: ReactNode
  icon?: ReactNode
}) {
  return (
    <div className="flex flex-col items-center justify-center px-6 py-16 text-center">
      {icon ? (
        <div className="mb-5 flex h-14 w-14 items-center justify-center rounded-full bg-byow-orange-tint text-byow-orange-dark">
          {icon}
        </div>
      ) : null}
      <h3 className="text-xl font-semibold text-ink">{title}</h3>
      {description ? (
        <p className="mt-1.5 max-w-md text-sm text-ink-muted">{description}</p>
      ) : null}
      {action ? <div className="mt-6">{action}</div> : null}
    </div>
  )
}
