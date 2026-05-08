import {
  type MiddlewareConsumer,
  Module,
  type NestModule,
} from '@nestjs/common';

import { DatabaseModule } from '../database/database.module';
import { RequestIdMiddleware } from '../logger/request-id.middleware';
import { AdminGuard } from '../training-weeks/admin.guard';
import { SystemPromptsController } from './system-prompts.controller';
import { SystemPromptsService } from './system-prompts.service';

@Module({
  imports: [DatabaseModule],
  controllers: [SystemPromptsController],
  providers: [SystemPromptsService, AdminGuard],
  exports: [SystemPromptsService],
})
export class SystemPromptsModule implements NestModule {
  configure(consumer: MiddlewareConsumer): void {
    consumer.apply(RequestIdMiddleware).forRoutes(SystemPromptsController);
  }
}
