import type { HTMLAttributes, ReactNode } from 'react'

// White fill on the surface background, 16pt corner radius, 16pt internal
// padding (prd.docx §3.4). Subtle shadow tuned to the iOS spec (radius 8,
// opacity 8%, y-offset 2) — translated to Tailwind: shadow-sm + a custom
// drop-shadow won't render right; we use a hand-tuned `shadow-[...]` instead.

interface CardProps extends HTMLAttributes<HTMLDivElement> {
  as?: 'div' | 'section' | 'article'
  padded?: boolean
}

export function Card({
  as = 'div',
  padded = true,
  className = '',
  children,
  ...rest
}: CardProps) {
  const Tag = as
  return (
    <Tag
      {...rest}
      className={`rounded-[var(--radius-card)] bg-card shadow-[0_2px_8px_rgba(15,23,42,0.06)] ${
        padded ? 'p-4 sm:p-5' : ''
      } ${className}`}
    >
      {children}
    </Tag>
  )
}

export function CardHeader({
  title,
  description,
  action,
}: {
  title: ReactNode
  description?: ReactNode
  action?: ReactNode
}) {
  return (
    <div className="flex items-start justify-between gap-4 border-b border-divider pb-3 mb-4">
      <div>
        <h3 className="text-[20px] font-semibold leading-tight text-ink">
          {title}
        </h3>
        {description ? (
          <p className="mt-1 text-sm text-ink-muted">{description}</p>
        ) : null}
      </div>
      {action ? <div className="shrink-0">{action}</div> : null}
    </div>
  )
}
