// HTTP transport for the editable system-prompt registry. Slug is part of
// the URL because we expect to grow this beyond `parse-day` (week-segmenter
// hints, weight_ref disambiguators, etc.).

export interface SystemPromptVersion {
  id: string
  slug: string
  body_markdown: string
  is_active: boolean
  created_at: string
  label: string
}

export interface SystemPromptDetail {
  active: SystemPromptVersion | null
  versions: SystemPromptVersion[]
}

export class SystemPromptsApiError extends Error {
  readonly status: number
  readonly body: unknown

  constructor(message: string, status: number, body?: unknown) {
    super(message)
    this.name = 'SystemPromptsApiError'
    this.status = status
    this.body = body
  }
}

export async function listSlugs(signal?: AbortSignal): Promise<string[]> {
  const res = await fetch('/api/v1/system-prompts', { signal })
  if (!res.ok) throw await readError(res)
  const body = (await res.json()) as { slugs: string[] }
  return body.slugs
}

export async function fetchSystemPrompt(
  slug: string,
  signal?: AbortSignal,
): Promise<SystemPromptDetail> {
  const res = await fetch(
    `/api/v1/system-prompts/${encodeURIComponent(slug)}`,
    { signal },
  )
  if (!res.ok) throw await readError(res)
  return (await res.json()) as SystemPromptDetail
}

export async function updateSystemPrompt(
  slug: string,
  input: { body_markdown: string; label?: string },
): Promise<SystemPromptVersion> {
  const res = await fetch(
    `/api/v1/system-prompts/${encodeURIComponent(slug)}`,
    {
      method: 'PUT',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(input),
    },
  )
  if (!res.ok) throw await readError(res)
  return (await res.json()) as SystemPromptVersion
}

export async function activateSystemPrompt(
  slug: string,
  versionId: string,
): Promise<SystemPromptVersion> {
  const res = await fetch(
    `/api/v1/system-prompts/${encodeURIComponent(slug)}/activate`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ version_id: versionId }),
    },
  )
  if (!res.ok) throw await readError(res)
  return (await res.json()) as SystemPromptVersion
}

async function readError(res: Response): Promise<SystemPromptsApiError> {
  let body: unknown
  try {
    body = await res.json()
  } catch {
    body = await res.text()
  }
  const message =
    typeof body === 'object' && body !== null && 'message' in body
      ? String((body as { message: unknown }).message)
      : `request failed (${res.status})`
  return new SystemPromptsApiError(message, res.status, body)
}
