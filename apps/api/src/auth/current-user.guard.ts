import {
  type CanActivate,
  type ExecutionContext,
  Inject,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { eq, sql } from 'drizzle-orm';
import { WINSTON_MODULE_PROVIDER } from 'nest-winston';
import type { Logger } from 'winston';

import { DatabaseService } from '../database/database.service';
import { users, type User } from '../database/schema/users';

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Phase-1 identity stub. Resolves the caller from `X-User-Id` (a UUID minted
// on the iOS keychain at first launch) and upserts the row on first hit so
// the rest of the system can rely on a stable user_id without a separate
// signup endpoint. When real auth lands (Supabase JWT + RevenueCat
// entitlements), this guard is the only thing that changes — controllers
// keep using `@CurrentUser()` unchanged.
declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      currentUser?: User;
    }
  }
}

@Injectable()
export class CurrentUserGuard implements CanActivate {
  constructor(
    private readonly database: DatabaseService,
    @Inject(WINSTON_MODULE_PROVIDER) private readonly logger: Logger,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest();
    const headerId = req.header('x-user-id');
    if (!headerId || !UUID_RE.test(headerId)) {
      throw new UnauthorizedException(
        'Missing or invalid X-User-Id header (Phase-1 auth stub).',
      );
    }

    // Idempotent upsert keyed on the client-supplied id. The first request
    // from a fresh device creates the row; every subsequent request is a
    // no-op insert that returns nothing, so we follow with a select.
    await this.database.db
      .insert(users)
      .values({ id: headerId })
      .onConflictDoNothing({ target: users.id });

    const [user] = await this.database.db
      .select()
      .from(users)
      .where(eq(users.id, headerId))
      .limit(1);

    if (!user) {
      // Race-condition fallback: the row exists by the time we re-select in
      // every realistic scenario. If we ever get here it means the upsert
      // silently dropped — log loudly so we can find out.
      this.logger.error({
        msg: 'auth.current-user.guard.row-missing-after-upsert',
        userId: headerId,
        requestId: req.requestId,
      });
      throw new UnauthorizedException('User row could not be resolved.');
    }

    // Touch updated_at so we have a cheap "last seen" without a separate
    // table. Fire-and-forget — failure here must not block the request.
    void this.database.db
      .update(users)
      .set({ updatedAt: sql`now()` })
      .where(eq(users.id, headerId))
      .catch((err) => {
        this.logger.warn({
          msg: 'auth.current-user.guard.touch-failed',
          userId: headerId,
          requestId: req.requestId,
          error: err instanceof Error ? err.message : String(err),
        });
      });

    req.currentUser = user;
    return true;
  }
}
