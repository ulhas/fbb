import type { GroupScoreDto, SetLogDto } from './create-workout-session.dto';

// Wire format returned by GET /workouts/sessions/:id and the POST upsert.
// Mirrors the request DTO shape (snake_case) so the iOS client uses one
// payload type round-trip.
export interface WorkoutSessionRowDto {
  id: string;
  client_session_id: string;
  track_code: string;
  scheduled_on: string;
  day_id: string | null;
  started_at: string;
  ended_at: string | null;
  total_elapsed_seconds: number;
  status: 'completed' | 'abandoned';
  notes: string | null;
  weight_unit: 'kg' | 'lb';
  set_logs: SetLogDto[];
  group_scores: GroupScoreDto[];
  created_at: string;
  updated_at: string;
}

// Lightweight summary used by the list endpoint. The mobile Stats tab and
// future history surfaces want a quick scan without hauling the full
// per-set log over the wire.
export interface WorkoutSessionSummaryRow {
  id: string;
  track_code: string;
  scheduled_on: string;
  started_at: string;
  ended_at: string | null;
  total_elapsed_seconds: number;
  status: 'completed' | 'abandoned';
}
