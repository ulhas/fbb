import { Module } from '@nestjs/common';

import { DatabaseModule } from '../database/database.module';
import { CurrentUserGuard } from './current-user.guard';

@Module({
  imports: [DatabaseModule],
  providers: [CurrentUserGuard],
  exports: [CurrentUserGuard],
})
export class AuthModule {}
