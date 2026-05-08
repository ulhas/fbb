import { createFileRoute } from '@tanstack/react-router'

import { UsersListPage } from '../../pages/UsersListPage'

export const Route = createFileRoute('/users/')({
  component: UsersListPage,
})
