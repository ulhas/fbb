import {
  Inject,
  Injectable,
  type OnApplicationBootstrap,
} from '@nestjs/common';
import { and, asc, desc, eq } from 'drizzle-orm';
import { WINSTON_MODULE_PROVIDER } from 'nest-winston';
import type { Logger } from 'winston';

import { DatabaseService } from '../database/database.service';
import {
  type NewSystemPrompt,
  type SystemPrompt,
  systemPrompts,
} from '../database/schema/system-prompts';
import { SYSTEM_PROMPT as PARSE_DAY_DEFAULT } from '../training-weeks/prompts/parse-day.prompt';

// Slug-keyed registry of editable prompts. Each slug owns one active row at
// a time (enforced by partial unique index); inactive rows are kept as
// version history. The day-parser reads `getActiveBody('parse-day')` once
// per batch and the in-memory cache makes repeated reads within an upload
// near-free.

export const PARSE_DAY_SLUG = 'parse-day';

const KNOWN_SLUGS = [
  {
    slug: PARSE_DAY_SLUG,
    seedBody: PARSE_DAY_DEFAULT,
    seedLabel: 'initial',
  },
] as const;

export interface SystemPromptVersion {
  id: string;
  slug: string;
  body_markdown: string;
  is_active: boolean;
  created_at: string;
  label: string;
}

function toView(row: SystemPrompt): SystemPromptVersion {
  return {
    id: row.id,
    slug: row.slug,
    body_markdown: row.bodyMarkdown,
    is_active: row.isActive,
    created_at: row.createdAt.toISOString(),
    label: row.label,
  };
}

@Injectable()
export class SystemPromptsService implements OnApplicationBootstrap {
  // In-memory active-body cache keyed by slug. Invalidated on every
  // createVersion call (within this process). Single-instance deploys hit
  // the cache 49/50 times during a typical upload; if we ever scale out,
  // swap for LISTEN/NOTIFY against system_prompts so peer processes drop
  // their stale cache too.
  private activeBodyBySlug = new Map<string, string>();

  constructor(
    private readonly database: DatabaseService,
    @Inject(WINSTON_MODULE_PROVIDER) private readonly logger: Logger,
  ) {}

  // Seed any known slugs that have no active row yet. Idempotent — safe to
  // run on every boot. Lets us ship a new slug by adding a KNOWN_SLUGS entry
  // without writing a SQL seed script.
  async onApplicationBootstrap(): Promise<void> {
    for (const { slug, seedBody, seedLabel } of KNOWN_SLUGS) {
      const existing = await this.findActive(slug);
      if (existing) continue;
      await this.database.db.insert(systemPrompts).values({
        slug,
        bodyMarkdown: seedBody,
        isActive: true,
        label: seedLabel,
      } satisfies NewSystemPrompt);
      this.logger.info({
        msg: 'system_prompts.seeded',
        slug,
        bodyChars: seedBody.length,
      });
    }
  }

  // Hot path. Falls back to the module-level constant if the DB is offline
  // or the slug somehow has no active row — better to parse with a stale
  // prompt than to fail every per-day call.
  async getActiveBody(slug: string): Promise<string> {
    const cached = this.activeBodyBySlug.get(slug);
    if (cached !== undefined) return cached;
    try {
      const row = await this.findActive(slug);
      if (row) {
        this.activeBodyBySlug.set(slug, row.bodyMarkdown);
        return row.bodyMarkdown;
      }
    } catch (err) {
      this.logger.warn({
        msg: 'system_prompts.read_failed_falling_back',
        slug,
        error: err instanceof Error ? err.message : String(err),
      });
    }
    return this.fallbackBody(slug);
  }

  async listVersions(slug: string): Promise<SystemPromptVersion[]> {
    const rows = await this.database.db
      .select()
      .from(systemPrompts)
      .where(eq(systemPrompts.slug, slug))
      .orderBy(desc(systemPrompts.createdAt));
    return rows.map(toView);
  }

  async getActive(slug: string): Promise<SystemPromptVersion | null> {
    const row = await this.findActive(slug);
    return row ? toView(row) : null;
  }

  // Creates a new active version: deactivates any existing active row for
  // the slug, inserts the new row marked active, all inside one transaction
  // so the partial unique index never sees two actives. Returns the new
  // version. Empty bodies are rejected — silent breakage of the parser is
  // worse than a 400.
  async createVersion(input: {
    slug: string;
    bodyMarkdown: string;
    label?: string;
  }): Promise<SystemPromptVersion> {
    const { slug } = input;
    const body = input.bodyMarkdown.trim();
    if (body.length === 0) {
      throw new Error('body_markdown must not be empty');
    }

    const created = await this.database.db.transaction(async (tx) => {
      await tx
        .update(systemPrompts)
        .set({ isActive: false })
        .where(
          and(eq(systemPrompts.slug, slug), eq(systemPrompts.isActive, true)),
        );
      const [row] = await tx
        .insert(systemPrompts)
        .values({
          slug,
          bodyMarkdown: input.bodyMarkdown,
          isActive: true,
          label: input.label ?? '',
        } satisfies NewSystemPrompt)
        .returning();
      return row;
    });

    // Drop the cache so the next read hits the DB fresh.
    this.activeBodyBySlug.delete(slug);
    this.logger.info({
      msg: 'system_prompts.version_created',
      slug,
      versionId: created.id,
      bodyChars: created.bodyMarkdown.length,
    });
    return toView(created);
  }

  // Activates a past version (rollback). Same transaction pattern as
  // createVersion: deactivate everything for the slug, then flip just the
  // requested row. Idempotent if the row is already active.
  async activate(slug: string, versionId: string): Promise<SystemPromptVersion> {
    const updated = await this.database.db.transaction(async (tx) => {
      const [target] = await tx
        .select()
        .from(systemPrompts)
        .where(
          and(eq(systemPrompts.slug, slug), eq(systemPrompts.id, versionId)),
        )
        .limit(1);
      if (!target) {
        throw new Error(`system prompt ${versionId} not found for slug ${slug}`);
      }
      await tx
        .update(systemPrompts)
        .set({ isActive: false })
        .where(
          and(eq(systemPrompts.slug, slug), eq(systemPrompts.isActive, true)),
        );
      const [row] = await tx
        .update(systemPrompts)
        .set({ isActive: true })
        .where(eq(systemPrompts.id, versionId))
        .returning();
      return row;
    });
    this.activeBodyBySlug.delete(slug);
    this.logger.info({
      msg: 'system_prompts.version_activated',
      slug,
      versionId,
    });
    return toView(updated);
  }

  // Returns the full ordered slug list for the registry. Useful for the
  // admin UI's slug picker.
  knownSlugs(): readonly string[] {
    return KNOWN_SLUGS.map((k) => k.slug);
  }

  private async findActive(slug: string): Promise<SystemPrompt | null> {
    const rows = await this.database.db
      .select()
      .from(systemPrompts)
      .where(
        and(eq(systemPrompts.slug, slug), eq(systemPrompts.isActive, true)),
      )
      .orderBy(asc(systemPrompts.createdAt))
      .limit(1);
    return rows[0] ?? null;
  }

  private fallbackBody(slug: string): string {
    const known = KNOWN_SLUGS.find((k) => k.slug === slug);
    return known?.seedBody ?? '';
  }
}
