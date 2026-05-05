import type { ReactNode } from 'react'

// Display stat used in the page hero. Big numeric, small label, optional
// secondary metadata line. Sized at type.display (32pt) for the value to
// match the prd.docx §3.2 type scale.

export function Stat({
  label,
  value,
  hint,
  accent,
}: {
  label: string
  value: ReactNode
  hint?: ReactNode
  accent?: 'orange' | 'teal' | 'success' | 'warning'
}) {
  const accentClass: Record<NonNullable<typeof accent>, string> = {
    orange: 'border-l-fbb-orange',
    teal: 'border-l-fbb-teal',
    success: 'border-l-success',
    warning: 'border-l-warning',
  }
  const ringClass = accent ? `border-l-4 ${accentClass[accent]}` : ''
  return (
    <div
      className={`rounded-[var(--radius-card)] bg-card p-5 shadow-[0_2px_8px_rgba(15,23,42,0.06)] ${ringClass}`}
    >
      <div className="text-xs font-medium uppercase tracking-wider text-ink-muted">
        {label}
      </div>
      <div className="mt-2 text-[32px] font-bold leading-none text-ink tabular-nums">
        {value}
      </div>
      {hint ? <div className="mt-2 text-xs text-ink-muted">{hint}</div> : null}
    </div>
  )
}
