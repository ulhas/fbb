import { createFileRoute } from '@tanstack/react-router'

import { UploadJobDetailPage } from '../../pages/UploadJobDetailPage'

export const Route = createFileRoute('/upload-jobs/$id')({
  component: UploadJobDetailPage,
})
