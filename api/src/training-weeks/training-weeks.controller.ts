import {
  BadRequestException,
  Body,
  Controller,
  Post,
  Req,
  UnsupportedMediaTypeException,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Request } from 'express';
import { randomUUID } from 'node:crypto';

import { AdminGuard } from './admin.guard';
import type { UploadResponseDto } from './dto/parse-result.dto';
import { TrainingWeeksService } from './services/training-weeks.service';

const MAX_UPLOAD_BYTES = 10 * 1024 * 1024;

@Controller('training-weeks')
@UseGuards(AdminGuard)
export class TrainingWeeksController {
  constructor(private readonly service: TrainingWeeksService) {}

  @Post('upload')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: MAX_UPLOAD_BYTES },
      fileFilter: (_req, file, cb) => {
        if (file.mimetype !== 'application/pdf') {
          return cb(
            new UnsupportedMediaTypeException(
              `expected application/pdf, got ${file.mimetype}`,
            ),
            false,
          );
        }
        cb(null, true);
      },
    }),
  )
  async upload(
    @UploadedFile() file: Express.Multer.File,
    @Body('dry_run') dryRunRaw: string | undefined,
    @Req() req: Request,
  ): Promise<UploadResponseDto> {
    if (!file) {
      throw new BadRequestException('field "file" is required (multipart/form-data)');
    }
    // Magic-bytes check — multer mimetype is client-asserted.
    if (file.buffer.subarray(0, 5).toString('utf8') !== '%PDF-') {
      throw new UnsupportedMediaTypeException(
        'file does not look like a PDF (missing %PDF- magic header)',
      );
    }

    const dryRun = dryRunRaw === 'true' || dryRunRaw === '1';
    const requestId = req.requestId ?? randomUUID();

    return this.service.uploadAndParse({
      filename: file.originalname,
      buffer: file.buffer,
      dryRun,
      requestId,
    });
  }
}
