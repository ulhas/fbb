import {
  createParamDecorator,
  type ExecutionContext,
  InternalServerErrorException,
} from '@nestjs/common';

import type { User } from '../database/schema/users';

// Pulls the user that `CurrentUserGuard` attached to the request. If the
// guard isn't applied to the route this throws — that's intentional: it
// surfaces wiring mistakes loudly at request time rather than silently
// returning undefined.
export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): User => {
    const req = ctx.switchToHttp().getRequest<{ currentUser?: User }>();
    if (!req.currentUser) {
      throw new InternalServerErrorException(
        '@CurrentUser() used on a route without CurrentUserGuard.',
      );
    }
    return req.currentUser;
  },
);
