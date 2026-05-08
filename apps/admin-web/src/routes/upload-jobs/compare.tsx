import { createFileRoute } from '@tanstack/react-router'

import { UploadJobsComparePage } from '../../pages/UploadJobsComparePage'

interface CompareSearch {
  a?: string
  b?: string
}

export const Route = createFileRoute('/upload-jobs/compare')({
  component: UploadJobsComparePage,
  validateSearch: (raw): CompareSearch => ({
    a: typeof raw.a === 'string' ? raw.a : undefined,
    b: typeof raw.b === 'string' ? raw.b : undefined,
  }),
})
