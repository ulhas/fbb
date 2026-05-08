import { createFileRoute } from '@tanstack/react-router'

import { TrainingWeeksListPage } from '../../pages/TrainingWeeksListPage'

export const Route = createFileRoute('/training-weeks/')({
  component: TrainingWeeksListPage,
})
