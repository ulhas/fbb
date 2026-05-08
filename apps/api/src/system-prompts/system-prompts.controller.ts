import {
  BadRequestException,
  Body,
  Controller,
  Get,
  NotFoundException,
  Param,
  Post,
  Put,
  UseGuards,
} from '@nestjs/common';

import { AdminGuard } from '../training-weeks/admin.guard';
import {
  type SystemPromptVersion,
  SystemPromptsService,
} from './system-prompts.service';

interface UpdatePromptDto {
  body_markdown?: string;
  label?: string;
}

interface ActivateDto {
  version_id?: string;
}

// Admin-only — these endpoints power the system-prompt editor surface.
// Behind AdminGuard (currently a permit-and-warn stub).
@Controller('system-prompts')
@UseGuards(AdminGuard)
export class SystemPromptsController {
  constructor(private readonly prompts: SystemPromptsService) {}

  @Get()
  async slugs(): Promise<{ slugs: string[] }> {
    return { slugs: [...this.prompts.knownSlugs()] };
  }

  // Returns the active version + ordered history for a slug. Admin UI
  // displays both: the editor surfaces the active body; the history list
  // offers diff/restore on past versions.
  @Get(':slug')
  async detail(
    @Param('slug') slug: string,
  ): Promise<{ active: SystemPromptVersion | null; versions: SystemPromptVersion[] }> {
    const versions = await this.prompts.listVersions(slug);
    if (versions.length === 0) {
      throw new NotFoundException(`unknown slug ${slug}`);
    }
    return {
      active: versions.find((v) => v.is_active) ?? null,
      versions,
    };
  }

  // Creates a new active version (replaces the current one). Empty bodies
  // are rejected — silently breaking the parser is worse than a 400.
  @Put(':slug')
  async update(
    @Param('slug') slug: string,
    @Body() body: UpdatePromptDto | undefined,
  ): Promise<SystemPromptVersion> {
    const text = body?.body_markdown;
    if (typeof text !== 'string' || text.trim().length === 0) {
      throw new BadRequestException('body_markdown is required and non-empty');
    }
    try {
      return await this.prompts.createVersion({
        slug,
        bodyMarkdown: text,
        label: body?.label,
      });
    } catch (err) {
      throw new BadRequestException(
        err instanceof Error ? err.message : String(err),
      );
    }
  }

  // Rolls back to a past version. Same effect as PUT-ing the body of an old
  // version, but cheaper (no copy) and the version_id is the audit trail.
  @Post(':slug/activate')
  async activate(
    @Param('slug') slug: string,
    @Body() body: ActivateDto | undefined,
  ): Promise<SystemPromptVersion> {
    const versionId = body?.version_id;
    if (!versionId) {
      throw new BadRequestException('version_id is required');
    }
    try {
      return await this.prompts.activate(slug, versionId);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      if (message.includes('not found')) throw new NotFoundException(message);
      throw err;
    }
  }
}
