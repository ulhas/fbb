import { createFileRoute } from '@tanstack/react-router'

import { SystemPromptEditorPage } from '../../pages/SystemPromptEditorPage'

export const Route = createFileRoute('/system-prompts/$slug')({
  component: SystemPromptEditorPage,
})
