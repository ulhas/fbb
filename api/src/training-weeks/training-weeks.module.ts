import {
  type MiddlewareConsumer,
  Module,
  type NestModule,
} from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { RequestIdMiddleware } from '../logger/request-id.middleware';
import { AdminGuard } from './admin.guard';
import { DayParser } from './services/day.parser';
import { PdfTextService } from './services/pdf-text.service';
import { TrainingWeeksController } from './training-weeks.controller';
import { TrainingWeeksService } from './services/training-weeks.service';

@Module({
  imports: [ConfigModule],
  controllers: [TrainingWeeksController],
  providers: [
    AdminGuard,
    DayParser,
    PdfTextService,
    TrainingWeeksService,
  ],
})
export class TrainingWeeksModule implements NestModule {
  configure(consumer: MiddlewareConsumer): void {
    consumer.apply(RequestIdMiddleware).forRoutes(TrainingWeeksController);
  }
}
