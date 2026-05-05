import { createBrowserRouter } from 'react-router-dom'

import { AppShell } from './components/AppShell'
import { TrainingWeekDetailPage } from './pages/TrainingWeekDetailPage'
import { TrainingWeeksListPage } from './pages/TrainingWeeksListPage'

// Single Responsibility: route definitions only. The shell wraps every route
// so the header is consistent. Adding a new page = one entry here, no shell
// changes — Open/Closed.

export const router = createBrowserRouter([
  {
    path: '/',
    element: (
      <AppShell>
        <TrainingWeeksListPage />
      </AppShell>
    ),
  },
  {
    path: '/training-weeks/:id',
    element: (
      <AppShell>
        <TrainingWeekDetailPage />
      </AppShell>
    ),
  },
])
