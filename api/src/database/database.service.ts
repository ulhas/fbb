import 'dotenv/config';

import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { drizzle } from 'drizzle-orm/node-postgres';
import { NodePgDatabase } from 'drizzle-orm/node-postgres';
import { Pool } from 'pg';
import * as schema from './schema';

@Injectable()
export class DatabaseService {
  public readonly db: NodePgDatabase<typeof schema>;

  constructor(private readonly configService: ConfigService) {
    // Initialize the database connection here
    const pool = new Pool({
      connectionString: configService.get('database.url'),
    });

    this.db = drizzle(pool, { schema });
  }
}
