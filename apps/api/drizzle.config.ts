import 'dotenv/config';
import { defineConfig } from 'drizzle-kit';

export default defineConfig({
  out: './drizzle',
  schema: './src/database/schema/index.ts',
  dialect: 'postgresql',
  dbCredentials: {
    url: 'postgresql://ulhas@localhost:5432/byow',
  },
});

