import {
  BadRequestException,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';

import { CurrentUser } from '../auth/current-user.decorator';
import { CurrentUserGuard } from '../auth/current-user.guard';
import type { User } from '../database/schema/users';
import {
  type FollowEventRow,
  type MeResponseRow,
  type TrackCatalogRow,
  UsersService,
} from './users.service';

const TRACK_CODE_RE = /^[a-z0-9_]+$/;

// Everything user-scoped lives behind /me. The collection lives at
// /me/tracks (not /tracks) because the resource being represented is
// "tracks I see in my picker, with my follow state" — the global track
// table has no public read endpoint yet (the iOS app doesn't need one).
@Controller('me')
@UseGuards(CurrentUserGuard)
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get()
  async me(@CurrentUser() user: User): Promise<MeResponseRow> {
    return this.users.getMe(user.id);
  }

  @Get('tracks')
  async tracks(@CurrentUser() user: User): Promise<TrackCatalogRow[]> {
    return this.users.listTrackCatalog(user.id);
  }

  // Full audit log of follow / unfollow events for this user, newest first.
  // Powers the "View past programs" surface; the iOS Today screen still
  // reads `GET /me` for the active set.
  @Get('tracks/history')
  async tracksHistory(@CurrentUser() user: User): Promise<FollowEventRow[]> {
    return this.users.getFollowHistory(user.id);
  }

  @Post('tracks/:code/follow')
  @HttpCode(HttpStatus.NO_CONTENT)
  async follow(
    @CurrentUser() user: User,
    @Param('code') code: string,
  ): Promise<void> {
    if (!TRACK_CODE_RE.test(code)) {
      throw new BadRequestException(
        `track code must match ${TRACK_CODE_RE.source}, got "${code}"`,
      );
    }
    await this.users.followTrack(user.id, code);
  }

  @Delete('tracks/:code/follow')
  @HttpCode(HttpStatus.NO_CONTENT)
  async unfollow(
    @CurrentUser() user: User,
    @Param('code') code: string,
  ): Promise<void> {
    if (!TRACK_CODE_RE.test(code)) {
      throw new BadRequestException(
        `track code must match ${TRACK_CODE_RE.source}, got "${code}"`,
      );
    }
    await this.users.unfollowTrack(user.id, code);
  }
}
