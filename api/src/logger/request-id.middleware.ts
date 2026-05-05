import { randomUUID } from 'node:crypto';

import { Injectable, type NestMiddleware } from '@nestjs/common';
import type { NextFunction, Request, Response } from 'express';

// Stamps every request with a stable correlation id (X-Request-Id), echoed
// in the response header. Picks up an upstream id when a load balancer or
// reverse proxy already injects one. Services pull `req.requestId` for
// per-request log fields.
declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      requestId?: string;
    }
  }
}

@Injectable()
export class RequestIdMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction): void {
    const headerId = req.header('x-request-id');
    const id = headerId && headerId.length > 0 ? headerId : randomUUID();
    req.requestId = id;
    res.setHeader('X-Request-Id', id);
    next();
  }
}
