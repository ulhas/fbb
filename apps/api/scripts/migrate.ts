import 'dotenv/config';
import { drizzle } from 'drizzle-orm/node-postgres';
import { migrate } from 'drizzle-orm/node-postgres/migrator';
import { Pool } from 'pg';

async function main() {
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error('DATABASE_URL not set');

  const pool = new Pool({ connectionString: url });
  const db = drizzle(pool);

  console.log(`migrating against ${url.replace(/:[^:@/]*@/, ':***@')}`);
  await migrate(db, { migrationsFolder: './drizzle' });
  console.log('migrations applied');

  await pool.end();
}

main().catch((err) => {
  console.error('migration failed:', err);
  process.exit(1);
});
