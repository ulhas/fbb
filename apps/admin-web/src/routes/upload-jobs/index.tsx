import { createFileRoute } from '@tanstack/react-router'

import { UploadJobsListPage } from '../../pages/UploadJobsListPage'

export const Route = createFileRoute('/upload-jobs/')({
  component: UploadJobsListPage,
})
