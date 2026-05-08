import { useMemo, useState } from 'react'
import type { ColumnDef, SortingState } from '@tanstack/react-table'
import {
  flexRender,
  getCoreRowModel,
  getSortedRowModel,
  useReactTable,
} from '@tanstack/react-table'

import type { AdminUserRow } from '@byow/types'

import { Badge } from './ui/Badge'

// Single Responsibility: render a sortable table of users for the admin
// console. No row-click navigation yet — there's no per-user detail page.

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

export function UsersTable({ records }: { records: AdminUserRow[] }) {
  const [sorting, setSorting] = useState<SortingState>([
    { id: 'created_at', desc: true },
  ])

  const columns = useMemo<ColumnDef<AdminUserRow>[]>(
    () => [
      {
        id: 'display_name',
        accessorFn: (r) => r.display_name ?? r.email ?? r.id,
        header: 'User',
        cell: ({ row }) => {
          const r = row.original
          const primary = r.display_name ?? r.email ?? '—'
          return (
            <div className="flex flex-col">
              <span className="text-[14px] font-semibold text-ink">
                {primary}
              </span>
              <span className="font-mono text-[11px] text-ink-muted">
                {r.id}
              </span>
            </div>
          )
        },
      },
      {
        id: 'email',
        accessorKey: 'email',
        header: 'Email',
        cell: ({ row }) =>
          row.original.email ? (
            <span className="text-[13px] text-ink-secondary">
              {row.original.email}
            </span>
          ) : (
            <span className="text-[12px] text-ink-muted">—</span>
          ),
      },
      {
        id: 'active_follow_count',
        accessorKey: 'active_follow_count',
        header: 'Active follows',
        cell: ({ row }) => {
          const n = row.original.active_follow_count
          return (
            <Badge tone={n > 0 ? 'info' : 'neutral'}>
              {n} {n === 1 ? 'track' : 'tracks'}
            </Badge>
          )
        },
      },
      {
        id: 'created_at',
        accessorKey: 'created_at',
        header: 'Joined',
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
            <tr key={hg.id} className="bg-byow-teal-tint/60">
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
              className={i !== 0 ? 'border-t border-divider' : ''}
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
  if (sort === 'asc') return <span className="text-byow-orange">↑</span>
  if (sort === 'desc') return <span className="text-byow-orange">↓</span>
  return null
}
