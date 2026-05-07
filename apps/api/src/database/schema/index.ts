// Barrel re-exporting every content-domain table.
//
// `DatabaseService` consumes this via `drizzle(pool, { schema })` so the typed
// query builder sees every table without a per-call generic. New tables land
// here in dependency order (parents before children) so circular FK chains
// stay debuggable.

export * from './enums';

export * from './tracks';
export * from './programs';
export * from './mesocycles';
export * from './microcycles';

export * from './users';
export * from './user-track-follows';

export * from './media-assets';
export * from './movements';

export * from './days';
export * from './sections';
export * from './prescribed-groups';
export * from './prescribed-exercises';
export * from './prescribed-sets';

export * from './coaching-notes';
export * from './mobility-flows';

export * from './upload-jobs';

export * from './workout-sessions';
export * from './workout-set-logs';
export * from './workout-group-scores';
