import {
  type MiddlewareConsumer,
  Module,
  type NestModule,
} from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { DatabaseModule } from '../database/database.module';
import { RequestIdMiddleware } from '../logger/request-id.middleware';
import { AdminGuard } from '../training-weeks/admin.guard';
import { UsersAdminController } from './users-admin.controller';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';

@Module({
  imports: [AuthModule, DatabaseModule],
  controllers: [UsersController, UsersAdminController],
  providers: [UsersService, AdminGuard],
})
export class UsersModule implements NestModule {
  configure(consumer: MiddlewareConsumer): void {
    consumer
      .apply(RequestIdMiddleware)
      .forRoutes(UsersController, UsersAdminController);
  }
}
