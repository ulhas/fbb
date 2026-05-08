import {
  type MiddlewareConsumer,
  Module,
  type NestModule,
} from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { DatabaseModule } from '../database/database.module';
import { RequestIdMiddleware } from '../logger/request-id.middleware';
import { SystemPromptsModule } from '../system-prompts/system-prompts.module';
import { UploadJobsController } from '../upload-jobs/upload-jobs.controller';
import { AdminGuard } from './admin.guard';
import { DayParser } from './services/day.parser';
import { PdfTextService } from './services/pdf-text.service';
import { TrainingWeeksController } from './training-weeks.controller';
import { TrainingWeeksReadService } from './services/training-weeks-read.service';
import { TrainingWeeksService } from './services/training-weeks.service';
import { TrainingWeekPersister } from './services/training-week.persister';
import { UploadJobsService } from './services/upload-jobs.service';

// Both controllers live in this module because they share the parser stack.
// /training-weeks reads persisted week data (TrainingWeeksReadService);
// /upload-jobs owns the create/poll/retry workflow (TrainingWeeksService +
// UploadJobsService). Folder layout follows URL prefix to keep the controllers
// independently discoverable.
@Module({
  imports: [ConfigModule, DatabaseModule, SystemPromptsModule],
  controllers: [TrainingWeeksController, UploadJobsController],
  providers: [
    AdminGuard,
    DayParser,
    PdfTextService,
    TrainingWeekPersister,
    TrainingWeeksReadService,
    TrainingWeeksService,
    UploadJobsService,
  ],
})
export class TrainingWeeksModule implements NestModule {
  configure(consumer: MiddlewareConsumer): void {
    consumer
      .apply(RequestIdMiddleware)
      .forRoutes(TrainingWeeksController, UploadJobsController);
  }
}
