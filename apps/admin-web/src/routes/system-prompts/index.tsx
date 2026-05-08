import { createFileRoute, redirect } from '@tanstack/react-router'

// Single-slug shortcut: there's only one prompt today (parse-day) so the
// sidebar entry redirects directly into its editor. When more slugs land,
// this becomes a slug picker.
export const Route = createFileRoute('/system-prompts/')({
  beforeLoad: () => {
    throw redirect({
      to: '/system-prompts/$slug',
      params: { slug: 'parse-day' },
    })
  },
})
