import { useEffect, useMemo, useState } from 'react'
import { useParams } from '@tanstack/react-router'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

import {
  activateSystemPrompt,
  fetchSystemPrompt,
  updateSystemPrompt,
  type SystemPromptDetail,
  type SystemPromptVersion,
} from '../api/system-prompts'
import { Badge } from '../components/ui/Badge'
import { Button } from '../components/ui/Button'

const detailKey = (slug: string) => ['system-prompts', slug] as const

export function SystemPromptEditorPage() {
  const { slug } = useParams({ from: '/system-prompts/$slug' })
  const queryClient = useQueryClient()
  const detailQuery = useQuery({
    queryKey: detailKey(slug),
    queryFn: ({ signal }) => fetchSystemPrompt(slug, signal),
  })

  const detail = detailQuery.data
  const active = detail?.active ?? null

  // Local-edit state. Synced from `active.body_markdown` whenever the active
  // version changes (e.g. after a successful save or rollback).
  const [body, setBody] = useState('')
  const [label, setLabel] = useState('')

  useEffect(() => {
    if (active) {
      setBody(active.body_markdown)
      setLabel('')
    }
  }, [active?.id])

  const isDirty = useMemo(
    () => active != null && body !== active.body_markdown,
    [active, body],
  )

  const saveMutation = useMutation({
    mutationFn: () =>
      updateSystemPrompt(slug, { body_markdown: body, label: label || undefined }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: detailKey(slug) })
    },
  })

  const activateMutation = useMutation({
    mutationFn: (versionId: string) => activateSystemPrompt(slug, versionId),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: detailKey(slug) })
    },
  })

  if (detailQuery.isLoading) {
    return <Loading />
  }
  if (detailQuery.error || !detail) {
    return <NotFound message={(detailQuery.error as Error | null)?.message} />
  }

  return (
    <>
      <div className="mb-6">
        <h1 className="text-[28px] font-bold leading-tight text-ink">
          System Prompt
        </h1>
        <p className="mt-1 text-sm text-ink-muted">
          Slug <span className="font-mono text-ink">{slug}</span>. Saving
          creates a new active version. The provider's prompt cache flips on
          first use of the new prefix and warms again over the next 50 calls.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-[minmax(0,1fr)_320px]">
        <Editor
          body={body}
          label={label}
          isDirty={isDirty}
          isSaving={saveMutation.isPending}
          error={
            saveMutation.error instanceof Error
              ? saveMutation.error.message
              : null
          }
          onBodyChange={setBody}
          onLabelChange={setLabel}
          onSave={() => saveMutation.mutate()}
          onReset={() => setBody(active?.body_markdown ?? '')}
        />
        <HistoryPanel
          detail={detail}
          activatingId={
            activateMutation.isPending
              ? (activateMutation.variables as string | undefined) ?? null
              : null
          }
          onActivate={(id) => activateMutation.mutate(id)}
          onPreview={(version) => setBody(version.body_markdown)}
        />
      </div>
    </>
  )
}

function Editor({
  body,
  label,
  isDirty,
  isSaving,
  error,
  onBodyChange,
  onLabelChange,
  onSave,
  onReset,
}: {
  body: string
  label: string
  isDirty: boolean
  isSaving: boolean
  error: string | null
  onBodyChange: (next: string) => void
  onLabelChange: (next: string) => void
  onSave: () => void
  onReset: () => void
}) {
  return (
    <section className="flex flex-col rounded-[var(--radius-card)] bg-card p-4 shadow-[0_2px_8px_rgba(15,23,42,0.06)]">
      <header className="mb-3 flex items-baseline justify-between">
        <h2 className="text-[11px] font-semibold uppercase tracking-wider text-ink-secondary">
          Active body (markdown)
        </h2>
        <span className="text-[11px] text-ink-muted">
          {body.length.toLocaleString()} chars
        </span>
      </header>
      <textarea
        value={body}
        onChange={(e) => onBodyChange(e.target.value)}
        spellCheck={false}
        className="min-h-[480px] w-full flex-1 resize-y rounded-[var(--radius-button)] border border-divider bg-surface p-3 font-mono text-[12px] leading-relaxed text-ink focus:border-byow-orange focus:outline-none"
      />
      <div className="mt-3 grid grid-cols-1 gap-2 sm:grid-cols-[1fr_auto_auto]">
        <input
          type="text"
          value={label}
          onChange={(e) => onLabelChange(e.target.value)}
          placeholder="Optional label (e.g. 'fix Spoto press')"
          className="rounded-[var(--radius-button)] border border-divider bg-card px-3 py-2 text-sm text-ink focus:border-byow-orange focus:outline-none"
        />
        <Button
          variant="secondary"
          size="sm"
          onClick={onReset}
          disabled={!isDirty || isSaving}
        >
          Reset
        </Button>
        <Button size="sm" onClick={onSave} disabled={!isDirty || isSaving}>
          {isSaving ? 'Saving…' : isDirty ? 'Save new version' : 'Saved'}
        </Button>
      </div>
      {error ? (
        <p className="mt-3 rounded-md bg-danger/10 px-3 py-2 text-sm text-danger">
          {error}
        </p>
      ) : null}
    </section>
  )
}

function HistoryPanel({
  detail,
  activatingId,
  onActivate,
  onPreview,
}: {
  detail: SystemPromptDetail
  activatingId: string | null
  onActivate: (versionId: string) => void
  onPreview: (version: SystemPromptVersion) => void
}) {
  return (
    <aside className="flex flex-col gap-3">
      <section className="rounded-[var(--radius-card)] bg-card p-4 shadow-[0_2px_8px_rgba(15,23,42,0.06)]">
        <h2 className="text-[11px] font-semibold uppercase tracking-wider text-ink-secondary">
          Active version
        </h2>
        {detail.active ? (
          <div className="mt-3 flex flex-col gap-1 text-sm">
            <span className="font-mono text-[11px] text-ink-muted">
              {detail.active.id.slice(0, 8)}…
            </span>
            <span className="text-ink">
              {new Date(detail.active.created_at).toLocaleString()}
            </span>
            {detail.active.label ? (
              <span className="text-[12px] text-ink-secondary">
                "{detail.active.label}"
              </span>
            ) : null}
          </div>
        ) : (
          <p className="mt-3 text-sm text-ink-muted">No active version.</p>
        )}
      </section>

      <section className="rounded-[var(--radius-card)] bg-card p-4 shadow-[0_2px_8px_rgba(15,23,42,0.06)]">
        <h2 className="text-[11px] font-semibold uppercase tracking-wider text-ink-secondary">
          History ({detail.versions.length})
        </h2>
        <ul className="mt-3 flex max-h-[420px] flex-col gap-2 overflow-y-auto pr-1">
          {detail.versions.map((v) => (
            <li
              key={v.id}
              className={`rounded-md border p-2.5 text-sm ${
                v.is_active
                  ? 'border-byow-orange bg-byow-orange-tint/40'
                  : 'border-divider bg-surface'
              }`}
            >
              <div className="flex items-baseline justify-between gap-2">
                <span className="font-mono text-[11px] text-ink-muted">
                  {v.id.slice(0, 8)}…
                </span>
                {v.is_active ? <Badge tone="success">active</Badge> : null}
              </div>
              <div className="mt-1 text-[12px] text-ink-secondary">
                {new Date(v.created_at).toLocaleString()}
              </div>
              {v.label ? (
                <div className="mt-0.5 truncate text-[12px] text-ink">
                  {v.label}
                </div>
              ) : null}
              <div className="mt-2 flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => onPreview(v)}
                  className="cursor-pointer text-[11px] font-semibold text-byow-orange hover:text-byow-orange-dark"
                >
                  Load into editor
                </button>
                {!v.is_active ? (
                  <button
                    type="button"
                    onClick={() => onActivate(v.id)}
                    disabled={activatingId === v.id}
                    className="cursor-pointer text-[11px] font-semibold text-ink hover:text-byow-orange-dark disabled:cursor-not-allowed disabled:opacity-60"
                  >
                    {activatingId === v.id ? 'Activating…' : 'Restore'}
                  </button>
                ) : null}
              </div>
            </li>
          ))}
        </ul>
      </section>
    </aside>
  )
}

function Loading() {
  return (
    <div className="rounded-[var(--radius-card)] bg-card p-12 text-center shadow-[0_2px_8px_rgba(15,23,42,0.06)]">
      <p className="text-sm text-ink-muted">Loading…</p>
    </div>
  )
}

function NotFound({ message }: { message?: string }) {
  return (
    <div className="rounded-[var(--radius-card)] bg-card p-12 text-center shadow-[0_2px_8px_rgba(15,23,42,0.06)]">
      <h2 className="text-xl font-semibold text-ink">Prompt not found</h2>
      <p className="mt-2 text-sm text-ink-muted">{message ?? 'Unknown slug.'}</p>
    </div>
  )
}
