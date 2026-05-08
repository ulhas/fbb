import { useMemo, useState } from 'react'
import type { ColumnDef, SortingState } from '@tanstack/react-table'
import {
  flexRender,
  getCoreRowModel,
  getSortedRowModel,
  useReactTable,
} from '@tanstack/react-table'
import { useNavigate } from '@tanstack/react-router'

import type { UploadJobStatus, UploadJobSummary } from '@fbb/types'

import { Badge } from './ui/Badge'

// Single Responsibility: render a sortable table of upload jobs. Row click
// opens the detail page, where the PDF preview lives.

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

const STATUS_TONE: Record<
  UploadJobStatus,
  'success' | 'warning' | 'info' | 'neutral'
> = {
  succeeded: 'success',
  failed: 'warning',
  running: 'info',
  queued: 'neutral',
}

export function UploadJobsTable({
  records,
}: {
  records: UploadJobSummary[]
}) {
  const navigate = useNavigate()
  const [sorting, setSorting] = useState<SortingState>([
    { id: 'uploaded_at', desc: true },
  ])

  const columns = useMemo<ColumnDef<UploadJobSummary>[]>(
    () => [
      {
        id: 'source_filename',
        accessorKey: 'source_filename',
        header: 'File',
        cell: ({ row }) => (
          <div className="flex flex-col">
            <span className="truncate text-[14px] font-semibold text-ink">
              {row.original.source_filename}
            </span>
            <span className="font-mono text-[11px] text-ink-muted">
              {row.original.id.slice(0, 8)}…
            </span>
          </div>
        ),
      },
      {
        id: 'status',
        accessorKey: 'status',
        header: 'Status',
        cell: ({ row }) => (
          <Badge tone={STATUS_TONE[row.original.status]}>
            {row.original.status}
          </Badge>
        ),
      },
      {
        id: 'model',
        accessorFn: (r) =>
          r.model_spec
            ? `${r.model_spec.provider}/${r.model_spec.model}`
            : '',
        header: 'Model',
        cell: ({ row }) => {
          const spec = row.original.model_spec
          if (!spec) return <span className="text-[12px] text-ink-muted">—</span>
          // Compress provider/model into a tight pill. Effort sits next to it
          // when it applies (OpenAI reasoning models).
          return (
            <div className="flex flex-col gap-0.5">
              <span className="font-mono text-[11px] text-ink">{spec.model}</span>
              <span className="text-[10px] text-ink-muted">
                {spec.provider}
                {spec.reasoning_effort ? ` · ${spec.reasoning_effort}` : ''}
              </span>
            </div>
          )
        },
      },
      {
        id: 'week_starts_on',
        accessorKey: 'week_starts_on',
        header: 'Week',
        cell: ({ row }) =>
          row.original.week_starts_on ? (
            <span className="font-mono text-[12px] text-ink">
              {row.original.week_starts_on}
            </span>
          ) : (
            <span className="text-[12px] text-ink-muted">—</span>
          ),
      },
      {
        id: 'tracks_days',
        header: 'Tracks · Days',
        cell: ({ row }) => {
          const { track_count, day_count } = row.original
          if (track_count === 0 && day_count === 0)
            return <span className="text-[12px] text-ink-muted">—</span>
          return (
            <span className="tabular-nums text-[13px] text-ink">
              {track_count} · {day_count}
            </span>
          )
        },
      },
      {
        id: 'warnings',
        accessorKey: 'warning_count',
        header: 'Warnings',
        cell: ({ row }) => {
          const n = row.original.warning_count
          if (n === 0)
            return <span className="text-[12px] text-ink-muted">0</span>
          return <Badge tone="warning">⚠ {n}</Badge>
        },
      },
      {
        id: 'tokens_total',
        accessorKey: 'tokens_total',
        header: 'Tokens',
        cell: ({ row }) => {
          const r = row.original
          if (r.tokens_total <= 0)
            return <span className="text-[12px] text-ink-muted">—</span>
          // Native title tooltip — cheap, accessible, and the breakdown is
          // secondary info that doesn't warrant a popover library.
          const tip = `Input ${r.tokens_input_total.toLocaleString()} · Output ${r.tokens_output_total.toLocaleString()}`
          return (
            <span
              className="tabular-nums font-mono text-[12px] text-ink-muted underline decoration-dotted decoration-ink-muted/40 underline-offset-2"
              title={tip}
            >
              {r.tokens_total.toLocaleString()}
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
                navigate({
                  to: '/upload-jobs/$id',
                  params: { id: row.original.id },
                })
              }
              onKeyDown={(e) => {
                if (e.key === 'Enter' || e.key === ' ') {
                  e.preventDefault()
                  navigate({
                    to: '/upload-jobs/$id',
                    params: { id: row.original.id },
                  })
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
