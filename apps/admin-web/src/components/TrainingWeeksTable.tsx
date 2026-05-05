import { useMemo, useState } from 'react'
import type { ColumnDef, SortingState } from '@tanstack/react-table'
import {
  flexRender,
  getCoreRowModel,
  getSortedRowModel,
  useReactTable,
} from '@tanstack/react-table'
import { useNavigate } from 'react-router-dom'

import type { TrainingWeekSummary } from '@fbb/types'

import { Badge } from './ui/Badge'

// TanStack Table presentation. Single Responsibility: render a sortable,
// navigable table of week summaries. Delete is delegated to the parent so the
// confirm modal lives at page scope (state-management for the modal there
// avoids prop-drilling row identity through the cell).

function formatDate(iso: string | null): string {
  if (!iso) return '—'
  const d = new Date(`${iso}T00:00:00Z`)
  return d.toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    timeZone: 'UTC',
  })
}

function formatRelative(iso: string): string {
  if (!iso) return '—'
  const ms = Date.now() - Date.parse(iso)
  const sec = Math.floor(ms / 1000)
  if (sec < 60) return `${sec}s ago`
  const min = Math.floor(sec / 60)
  if (min < 60) return `${min}m ago`
  const hr = Math.floor(min / 60)
  if (hr < 24) return `${hr}h ago`
  const day = Math.floor(hr / 24)
  if (day < 7) return `${day}d ago`
  return new Date(iso).toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
  })
}

function humanize(s: string | null): string {
  if (!s) return ''
  return s
    .split('_')
    .map((w) => (w ? w.charAt(0).toUpperCase() + w.slice(1) : w))
    .join(' ')
}

export function TrainingWeeksTable({
  records,
  onRequestDelete,
}: {
  records: TrainingWeekSummary[]
  onRequestDelete: (record: TrainingWeekSummary) => void
}) {
  const navigate = useNavigate()
  const [sorting, setSorting] = useState<SortingState>([
    { id: 'week_starts_on', desc: true },
  ])

  const columns = useMemo<ColumnDef<TrainingWeekSummary>[]>(
    () => [
      {
        id: 'week_starts_on',
        accessorKey: 'week_starts_on',
        header: 'Week',
        cell: ({ row }) => (
          <div className="flex flex-col">
            <span className="text-[15px] font-semibold text-ink">
              {formatDate(row.original.week_starts_on)}
            </span>
            <span className="font-mono text-[11px] text-ink-muted">
              {row.original.week_starts_on} → {row.original.week_ends_on}
            </span>
          </div>
        ),
      },
      {
        id: 'cycle',
        accessorKey: 'week_position',
        header: 'Cycle',
        cell: ({ row }) =>
          row.original.week_position != null ? (
            <Badge tone="neutral">W{row.original.week_position}</Badge>
          ) : (
            <span className="text-[12px] text-ink-muted">—</span>
          ),
      },
      {
        id: 'kind',
        accessorKey: 'microcycle_kind',
        header: 'Kind',
        cell: ({ row }) => {
          const k = row.original.microcycle_kind
          if (!k) return <span className="text-[12px] text-ink-muted">—</span>
          // Deload weeks are programmatically meaningful — call them out.
          const tone = k === 'deload' ? 'orange' : 'info'
          return <Badge tone={tone}>{humanize(k)}</Badge>
        },
      },
      {
        id: 'coverage',
        accessorKey: 'parsed_day_count',
        header: 'Coverage',
        cell: ({ row }) => {
          const { parsed_day_count, day_count, underparsed_day_count } =
            row.original
          const allClean = underparsed_day_count === 0
          return (
            <div className="flex items-center gap-2">
              <span
                className={`tabular-nums text-[13px] font-semibold ${
                  allClean ? 'text-success' : 'text-warning'
                }`}
              >
                {parsed_day_count}/{day_count}
              </span>
              {underparsed_day_count > 0 ? (
                <Badge tone="warning">⚠ {underparsed_day_count}</Badge>
              ) : null}
            </div>
          )
        },
      },
      {
        id: 'last_persisted_at',
        accessorKey: 'last_persisted_at',
        header: 'Updated',
        cell: ({ getValue }) => (
          <span
            className="text-xs text-ink-muted"
            title={new Date(String(getValue())).toLocaleString()}
          >
            {formatRelative(String(getValue()))}
          </span>
        ),
      },
      {
        id: 'actions',
        header: '',
        enableSorting: false,
        cell: ({ row }) => (
          <button
            type="button"
            onClick={(e) => {
              e.stopPropagation()
              onRequestDelete(row.original)
            }}
            aria-label={`Delete week of ${row.original.week_starts_on}`}
            className="grid h-8 w-8 cursor-pointer place-items-center rounded-full text-ink-muted transition-colors hover:bg-danger/10 hover:text-danger"
          >
            <TrashIcon />
          </button>
        ),
      },
    ],
    [onRequestDelete],
  )

  const table = useReactTable({
    data: records,
    columns,
    state: { sorting },
    onSortingChange: setSorting,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
  })

  return (
    <div className="overflow-hidden rounded-[var(--radius-card)] bg-card shadow-[0_2px_8px_rgba(15,23,42,0.06)]">
      <table className="w-full">
        <thead>
          {table.getHeaderGroups().map((hg) => (
            <tr key={hg.id} className="bg-fbb-teal-tint/60">
              {hg.headers.map((h) => {
                const sort = h.column.getIsSorted()
                const sortable = h.column.getCanSort()
                return (
                  <th
                    key={h.id}
                    className="px-4 py-3 text-left text-[11px] font-semibold uppercase tracking-wider text-ink-secondary"
                  >
                    {sortable ? (
                      <button
                        type="button"
                        onClick={h.column.getToggleSortingHandler()}
                        className="inline-flex cursor-pointer items-center gap-1 hover:text-ink"
                      >
                        {flexRender(h.column.columnDef.header, h.getContext())}
                        <SortIndicator sort={sort} />
                      </button>
                    ) : (
                      flexRender(h.column.columnDef.header, h.getContext())
                    )}
                  </th>
                )
              })}
            </tr>
          ))}
        </thead>
        <tbody>
          {table.getRowModel().rows.map((row, i) => (
            <tr
              key={row.id}
              tabIndex={0}
              role="link"
              onClick={() =>
                navigate(`/training-weeks/${row.original.week_starts_on}`)
              }
              onKeyDown={(e) => {
                if (e.key === 'Enter' || e.key === ' ') {
                  e.preventDefault()
                  navigate(`/training-weeks/${row.original.week_starts_on}`)
                }
              }}
              className={`cursor-pointer transition-colors hover:bg-fbb-orange-tint/40 focus-visible:bg-fbb-orange-tint/60 focus-visible:outline-none ${
                i !== 0 ? 'border-t border-divider' : ''
              }`}
            >
              {row.getVisibleCells().map((cell) => (
                <td key={cell.id} className="px-4 py-3 align-middle">
                  {flexRender(cell.column.columnDef.cell, cell.getContext())}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

function SortIndicator({ sort }: { sort: 'asc' | 'desc' | false }) {
  if (sort === 'asc') return <span className="text-fbb-orange">↑</span>
  if (sort === 'desc') return <span className="text-fbb-orange">↓</span>
  return null
}

function TrashIcon() {
  return (
    <svg
      width="16"
      height="16"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
    >
      <path d="M3 6h18" />
      <path d="M19 6l-1 14a2 2 0 01-2 2H8a2 2 0 01-2-2L5 6" />
      <path d="M10 11v6" />
      <path d="M14 11v6" />
      <path d="M9 6V4a1 1 0 011-1h4a1 1 0 011 1v2" />
    </svg>
  )
}
