import type {
  ParseMetrics,
  ParseWarning,
  ParsedDocument,
  ParsedTrack,
} from '../schemas/parsed-document.schema';

export interface UploadResponseDto {
  request_id: string;
  document: ParsedDocument | null;
  parse_warnings: ParseWarning[];
  parse_metrics: ParseMetrics;
  // Populated when `dry_run=true` was passed — surfaces the deterministic
  // segmenter output without any LLM cost so the segmenter can be iterated on
  // independently of prompt tuning.
  dry_run?: {
    week_starts_on: string | null;
    page_count: number;
    track_count: number;
    day_count: number;
    tracks: Array<Pick<ParsedTrack, 'track_code' | 'family' | 'cadence' | 'display_name'> & {
      day_count: number;
    }>;
    chunks: Array<{
      track_code: string;
      scheduled_on: string;
      position: number;
      kind: string;
      week_position: number | null;
      day_position: number | null;
      raw_text_preview: string;
    }>;
  };
}
