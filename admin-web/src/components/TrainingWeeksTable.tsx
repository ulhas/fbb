import { useMemo, useState } from 'react'
import type { ColumnDef, SortingState } from '@tanstack/react-table'
import {
  flexRender,
  getCoreRowModel,
  getSortedRowModel,
  useReactTable,
} from '@tanstack/react-table'
import { useNavigate } from 'react-router-dom'

import type { TrainingWeekRecord } from '../types'
import { Badge } from './ui/Badge'

// TanStack Table presentation. Single Responsibility: take an array of
// records and render a sortable, navigable table. No fetching, no storage.

function formatDate(iso: string): string {
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
  onDelete,
}: {
  records: TrainingWeekRecord[]
  onDelete: (id: string) => void
}) {
  const navigate = useNavigate()
  const [sorting, setSorting] = useState<SortingState>([
    { id: 'week_starts_on', desc: true },
  ])

  const columns = useMemo<ColumnDef<TrainingWeekRecord>[]>(
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
              {row.original.week_starts_on}
            </span>
          </div>
        ),
      },
      {
        id: 'source_filename',
        accessorKey: 'source_filename',
        header: 'Source',
        cell: ({ getValue }) => (
          <span className="font-mono text-xs text-ink-secondary">
            {String(getValue())}
          </span>
        ),
      },
      {
        id: 'tracks',
        header: 'Tracks',
        accessorFn: (r) =>
          r.document?.tracks.length ?? (r.dry_run_only ? '—' : 0),
        cell: ({ getValue }) => (
          <span className="tabular-nums text-ink">{String(getValue())}</span>
        ),
      },
      {
        id: 'days',
        header: 'Days',
        accessorFn: (r) =>
          r.document
            ? r.document.tracks.reduce((s, t) => s + t.days.length, 0)
            : '—',
        cell: ({ getValue }) => (
          <span className="tabular-nums text-ink">{String(getValue())}</span>
        ),
      },
      {
        id: 'warnings',
        header: 'Warnings',
        accessorFn: (r) => r.parse_warnings.length,
        cell: ({ getValue }) => {
          const n = Number(getValue())
          if (n === 0) return <Badge tone="success">0</Badge>
          return <Badge tone="warning">{n}</Badge>
        },
      },
      {
        id: 'tokens',
        header: 'Tokens',
        accessorFn: (r) => r.parse_metrics.tokens_total,
        cell: ({ getValue }) => {
          const n = Number(getValue())
          if (!n) return <span className="text-ink-muted">—</span>
          return (
            <span className="font-mono text-xs tabular-nums text-ink-secondary">
              {n.toLocaleString()}
            </span>
          )
        },
      },
      {
        id: 'uploaded_at',
        accessorKey: 'uploaded_at',
        header: 'Uploaded',
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
              if (
                confirm(
                  `Delete this record?\n${row.original.source_filename}\n(local only — does not affect the API)`,
                )
              ) {
                onDelete(row.original.id)
              }
            }}
            className="rounded-md p-1 text-ink-muted hover:bg-surface hover:text-danger"
            aria-label="Delete record"
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
              <path
                d="M3 6H21M9 6V4C9 3.4 9.4 3 10 3H14C14.6 3 15 3.4 15 4V6M19 6L18 20C18 20.6 17.6 21 17 21H7C6.4 21 6 20.6 6 20L5 6"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
          </button>
        ),
      },
    ],
    [onDelete],
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
              onClick={() => navigate(`/training-weeks/${row.original.id}`)}
              onKeyDown={(e) => {
                if (e.key === 'Enter' || e.key === ' ') {
                  e.preventDefault()
                  navigate(`/training-weeks/${row.original.id}`)
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
  return <span className="text-ink-muted/50">↕</span>
}
