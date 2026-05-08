import { useEffect } from 'react'
import { useQuery } from '@tanstack/react-query'

import {
  listModelCatalog,
  type ModelCatalogEntry,
} from '../api/upload-jobs'
import type { ModelSpec, ReasoningEffort } from '@byow/types'

// Provider/model + reasoning-effort dropdowns used by both UploadDialog (new
// upload) and the upload-jobs/$id reparse modal. Owns its own catalog fetch
// so callers don't have to plumb the catalog through. Initial selection
// rules: caller-supplied initialSpec wins; otherwise the catalog's marked
// `is_default` entry; otherwise the first entry.

interface ModelPickerProps {
  // Currently-selected ModelSpec. Caller is the source of truth; the picker
  // is purely controlled. `null` means "no selection yet" — the picker
  // calls `onChange` with the resolved default once the catalog loads.
  value: ModelSpec | null
  onChange: (spec: ModelSpec | null) => void
  // When true, the picker is disabled (e.g. while a parse is in flight).
  disabled?: boolean
}

const initialKey = (entry: ModelCatalogEntry) =>
  `${entry.spec.provider}/${entry.spec.model}`

const specKey = (spec: ModelSpec) => `${spec.provider}/${spec.model}`

export function ModelPicker({ value, onChange, disabled }: ModelPickerProps) {
  const catalogQuery = useQuery({
    queryKey: ['upload-jobs', 'models'],
    queryFn: ({ signal }) => listModelCatalog(signal),
  })

  const catalog = catalogQuery.data?.models ?? []

  // Resolve the catalog entry that matches the current value (if any), else
  // the env default, else the first entry. Falls back to null when the
  // catalog is still loading or empty.
  const resolved =
    (value
      ? catalog.find((e) => initialKey(e) === specKey(value))
      : null) ??
    catalog.find((e) => e.is_default) ??
    catalog[0] ??
    null

  // Sync caller state once we resolve to a value. Important when the parent
  // mounts with `null` and we need to inform it of the env-default pick.
  // Also when the catalog comes back AFTER mount (cold cache) — the parent
  // would otherwise stay at null forever.
  useEffect(() => {
    if (!resolved) return
    const next: ModelSpec = {
      provider: resolved.spec.provider,
      model: resolved.spec.model,
      reasoning_effort: resolved.supports_reasoning_effort
        ? value?.reasoning_effort ?? resolved.spec.reasoning_effort ?? 'medium'
        : null,
    }
    if (
      !value ||
      value.provider !== next.provider ||
      value.model !== next.model ||
      (resolved.supports_reasoning_effort &&
        value.reasoning_effort !== next.reasoning_effort)
    ) {
      onChange(next)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [resolved?.spec.provider, resolved?.spec.model])

  if (catalogQuery.isLoading) {
    return <p className="text-sm text-ink-muted">Loading models…</p>
  }
  if (catalog.length === 0) {
    return (
      <p className="text-sm text-danger">
        No models available. Check API keys.
      </p>
    )
  }

  const onModelChange = (key: string) => {
    const entry = catalog.find((e) => initialKey(e) === key)
    if (!entry) return
    onChange({
      provider: entry.spec.provider,
      model: entry.spec.model,
      reasoning_effort: entry.supports_reasoning_effort
        ? entry.spec.reasoning_effort ?? 'medium'
        : null,
    })
  }

  const onEffortChange = (next: ReasoningEffort) => {
    if (!resolved || !value) return
    onChange({ ...value, reasoning_effort: next })
  }

  return (
    <div className="space-y-3">
      <label className="block text-sm">
        <span className="mb-1 block text-[11px] font-semibold uppercase tracking-wider text-ink-muted">
          Model
        </span>
        <select
          value={resolved ? initialKey(resolved) : ''}
          onChange={(e) => onModelChange(e.target.value)}
          disabled={disabled}
          className="w-full cursor-pointer rounded-[var(--radius-button)] border border-divider bg-card px-3 py-2 text-sm text-ink focus:border-byow-orange focus:outline-none disabled:cursor-not-allowed disabled:opacity-60"
        >
          {catalog.map((e) => (
            <option key={initialKey(e)} value={initialKey(e)}>
              {e.display_name} ({e.spec.provider}/{e.spec.model})
              {e.is_default ? ' — default' : ''}
            </option>
          ))}
        </select>
      </label>

      {resolved?.supports_reasoning_effort ? (
        <label className="block text-sm">
          <span className="mb-1 block text-[11px] font-semibold uppercase tracking-wider text-ink-muted">
            Reasoning effort
          </span>
          <select
            value={
              value?.reasoning_effort ??
              resolved.spec.reasoning_effort ??
              'medium'
            }
            onChange={(e) => onEffortChange(e.target.value as ReasoningEffort)}
            disabled={disabled}
            className="w-full cursor-pointer rounded-[var(--radius-button)] border border-divider bg-card px-3 py-2 text-sm text-ink focus:border-byow-orange focus:outline-none disabled:cursor-not-allowed disabled:opacity-60"
          >
            <option value="minimal">minimal — cheapest, fastest</option>
            <option value="low">low</option>
            <option value="medium">medium — balanced</option>
            <option value="high">high — slowest, most accurate</option>
          </select>
        </label>
      ) : (
        <p className="text-[12px] text-ink-muted">
          Reasoning effort doesn't apply to this model.
        </p>
      )}
    </div>
  )
}
