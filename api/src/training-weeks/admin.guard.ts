import {
  type CanActivate,
  type ExecutionContext,
  Inject,
  Injectable,
} from '@nestjs/common';
import { WINSTON_MODULE_PROVIDER } from 'nest-winston';
import type { Logger } from 'winston';

// TODO(admin-auth): replace this stub with real admin auth (RevenueCat /
// Supabase JWT verification + role check) when the admin panel ships.
// Until then the guard PERMITS but logs a warning per call so we can spot
// any production exposure during the gap.
@Injectable()
export class AdminGuard implements CanActivate {
  constructor(
    @Inject(WINSTON_MODULE_PROVIDER) private readonly logger: Logger,
  ) {}

  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest();
    this.logger.warn({
      msg: 'admin.guard.stub.permitting',
      requestId: req.requestId,
      method: req.method,
      url: req.originalUrl ?? req.url,
    });
    return true;
  }
}
