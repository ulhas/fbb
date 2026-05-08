import type { ReactNode } from 'react'

// Tiny, opinionated badge — no variants beyond the four BYOW semantic states
// plus a neutral chrome state for metadata pills. Anything more elaborate
// belongs in a full design system, not this admin tool (YAGNI).

type Tone = 'neutral' | 'info' | 'success' | 'warning' | 'danger' | 'orange'

const toneClass: Record<Tone, string> = {
  neutral: 'bg-surface text-ink-secondary border-divider',
  info: 'bg-byow-teal-tint text-ink border-byow-teal',
  success: 'bg-[#E6F6EE] text-success border-success/40',
  warning: 'bg-[#FCEFD9] text-warning border-warning/40',
  danger: 'bg-[#FCE7E7] text-danger border-danger/40',
  orange: 'bg-byow-orange-tint text-byow-orange-dark border-byow-orange/40',
}

export function Badge({
  tone = 'neutral',
  children,
  className = '',
}: {
  tone?: Tone
  children: ReactNode
  className?: string
}) {
  return (
    <span
      className={`inline-flex items-center gap-1 rounded-full border px-2.5 py-0.5 text-xs font-medium leading-5 ${toneClass[tone]} ${className}`}
    >
      {children}
    </span>
  )
}
