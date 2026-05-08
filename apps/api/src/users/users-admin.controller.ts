import { Controller, Get, UseGuards } from '@nestjs/common';

import { AdminGuard } from '../training-weeks/admin.guard';
import { type AdminUserRow, UsersService } from './users.service';

// Admin list of users for the admin console. Mounted at /users (not
// /admin/users) — admin authority is decided by the token, not the URL,
// matching how /upload-jobs and /training-weeks expose their admin surfaces.
// The user-scoped /me endpoints stay in users.controller.ts.
@Controller('users')
@UseGuards(AdminGuard)
export class UsersAdminController {
  constructor(private readonly users: UsersService) {}

  @Get()
  async list(): Promise<AdminUserRow[]> {
    return this.users.listAll();
  }
}
