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

// TanStack Table presentation. Single Responsibility: take an array of week
// summaries and render a sortable, navigable table. No fetching, no storage.

function formatDate(iso: string | null): string {
  if (!iso) return '—'
  const d = new Date(`${iso}T00:00:00`)
  return d.toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
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

export function TrainingWeeksTable({
  records,
}: {
  records: TrainingWeekSummary[]
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
        header: 'Week of',
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
        id: 'tracks',
        accessorKey: 'track_count',
        header: 'Tracks',
        cell: ({ getValue }) => (
          <span className="tabular-nums text-ink">{String(getValue())}</span>
        ),
      },
      {
        id: 'days',
        accessorKey: 'day_count',
        header: 'Days',
        cell: ({ getValue }) => (
          <span className="tabular-nums text-ink">{String(getValue())}</span>
        ),
      },
      {
        id: 'last_persisted_at',
        accessorKey: 'last_persisted_at',
        header: 'Last persisted',
        cell: ({ getValue }) => (
          <span
            className="text-xs text-ink-muted"
            title={new Date(String(getValue())).toLocaleString()}
          >
            {formatRelative(String(getValue()))}
          </span>
        ),
      },
    ],
    [],
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
                        className="inline-flex items-center gap-1 hover:text-ink"
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
