import { Module } from '@nestjs/common';
import { WinstonModule, utilities as nestWinston } from 'nest-winston';
import * as winston from 'winston';

const isDev = process.env.NODE_ENV !== 'production';

// Redact secret-bearing fields before they reach a transport. Mirrors the
// pino redact paths but expressed as a winston format because winston has no
// first-class redact concept — we walk the meta object and rewrite values.
const REDACT_KEYS = new Set([
  'authorization',
  'cookie',
  'set-cookie',
  'x-api-key',
]);

const redactSecrets = winston.format((info) => {
  const visit = (obj: unknown): void => {
    if (!obj || typeof obj !== 'object') return;
    for (const [key, val] of Object.entries(obj as Record<string, unknown>)) {
      if (REDACT_KEYS.has(key.toLowerCase())) {
        (obj as Record<string, unknown>)[key] = '[REDACTED]';
        continue;
      }
      if (val && typeof val === 'object') visit(val);
    }
  };
  visit(info);
  return info;
});

// Call sites use pino-style `logger.info({ msg, ...fields })`. Winston wraps
// that object as `info.message`, so the line-formatter renders `[object Object]`
// and the fields never reach the metadata tail. Lift `msg`/`message` out as the
// log line and splat the rest onto `info` so nestLike's prettyPrint picks them up.
const liftStructuredMessage = winston.format((info) => {
  const msg = info.message;
  if (msg && typeof msg === 'object') {
    const obj = msg as Record<string, unknown>;
    const line =
      typeof obj.msg === 'string'
        ? obj.msg
        : typeof obj.message === 'string'
          ? obj.message
          : JSON.stringify(obj);
    info.message = line;
    for (const [k, v] of Object.entries(obj)) {
      if (k === 'msg' || k === 'message') continue;
      (info as Record<string, unknown>)[k] = v;
    }
  }
  return info;
});

@Module({
  imports: [
    WinstonModule.forRoot({
      level: process.env.LOG_LEVEL ?? (isDev ? 'debug' : 'info'),
      // JSON in production for log shippers; nest-winston pretty-print in dev.
      format: isDev
        ? winston.format.combine(
            liftStructuredMessage(),
            redactSecrets(),
            winston.format.timestamp({ format: 'HH:mm:ss.SSS' }),
            winston.format.ms(),
            nestWinston.format.nestLike('api', {
              colors: true,
              prettyPrint: true,
            }),
          )
        : winston.format.combine(
            liftStructuredMessage(),
            redactSecrets(),
            winston.format.timestamp(),
            winston.format.errors({ stack: true }),
            winston.format.json(),
          ),
      transports: [new winston.transports.Console()],
    }),
  ],
})
export class LoggerModule {}
