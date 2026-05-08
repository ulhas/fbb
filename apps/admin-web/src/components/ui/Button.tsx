import type { ButtonHTMLAttributes, ReactNode } from 'react'

// Two button variants per prd.docx §3.4: primary (orange fill / white text /
// 12pt radius / orangeDark on press) and secondary (white fill / ink-primary
// text / 1pt orange border).
//
// We intentionally don't ship a third "ghost" variant — when an action is
// neither primary nor destructive-affirmation it should be a link, not a
// button. The brand language explicitly favours fewer button shapes.

type Variant = 'primary' | 'secondary'
type Size = 'md' | 'sm'

interface Props extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant
  size?: Size
  loading?: boolean
  icon?: ReactNode
}

const baseClass =
  'inline-flex items-center justify-center gap-2 rounded-[var(--radius-button)] font-semibold transition-colors duration-150 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-byow-orange focus-visible:ring-offset-2 focus-visible:ring-offset-card disabled:cursor-not-allowed disabled:opacity-60'

const variantClass: Record<Variant, string> = {
  primary:
    'bg-byow-orange text-white hover:bg-byow-orange-dark active:bg-byow-orange-dark shadow-sm',
  secondary:
    'bg-card text-ink border border-byow-orange hover:bg-byow-orange-tint active:bg-byow-orange-tint',
}

const sizeClass: Record<Size, string> = {
  md: 'h-11 px-5 text-[15px]',
  sm: 'h-9 px-3.5 text-sm',
}

export function Button({
  variant = 'primary',
  size = 'md',
  loading = false,
  icon,
  className = '',
  children,
  disabled,
  ...rest
}: Props) {
  return (
    <button
      {...rest}
      disabled={disabled || loading}
      className={`${baseClass} ${variantClass[variant]} ${sizeClass[size]} ${className}`}
    >
      {loading ? <Spinner /> : icon}
      <span>{children}</span>
    </button>
  )
}

function Spinner() {
  return (
    <svg
      className="h-4 w-4 animate-spin"
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
    >
      <circle
        className="opacity-25"
        cx="12"
        cy="12"
        r="10"
        stroke="currentColor"
        strokeWidth="4"
      />
      <path
        className="opacity-75"
        fill="currentColor"
        d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"
      />
    </svg>
  )
}
