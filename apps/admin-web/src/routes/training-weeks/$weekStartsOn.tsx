import { createFileRoute } from '@tanstack/react-router'

import {
  TrainingWeekDetailPage,
  type WeekSearch,
} from '../../pages/TrainingWeekDetailPage'
import type { TrackFamily } from '@byow/types'

export const Route = createFileRoute('/training-weeks/$weekStartsOn')({
  component: TrainingWeekDetailPage,
  validateSearch: (raw): WeekSearch => {
    const out: WeekSearch = {}
    const view = raw.view
    if (view === 'matrix' || view === 'day' || view === 'track') out.view = view
    if (typeof raw.family === 'string') out.family = raw.family as TrackFamily
    if (typeof raw.cadence === 'string') out.cadence = raw.cadence
    if (typeof raw.track === 'string') out.track = raw.track
    if (typeof raw.day === 'string') out.day = raw.day
    return out
  },
})
