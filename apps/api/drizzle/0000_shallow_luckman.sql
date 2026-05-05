CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE "tracks" (
	"id" uuid PRIMARY KEY DEFAULT uuidv7() NOT NULL,
	"code" text NOT NULL,
	"family" text NOT NULL,
	"cadence" text,
	"display_name" text NOT NULL,
	"short_name" text,
	"description" text,
	"required_equipment" text[] DEFAULT '{}'::text[] NOT NULL,
	"default_for_quiz" boolean DEFAULT false NOT NULL,
	"active" boolean DEFAULT true NOT NULL,
	"sort_order" integer DEFAULT 100 NOT NULL,
	"metadata" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "tracks_code_unique" UNIQUE("code"),
	CONSTRAINT "tracks_family_check" CHECK ("tracks"."family" in ('pump_lift', 'pump_condition', 'perform', 'minimalist', 'hybrid_running', 'workshop', 'onramp')),
	CONSTRAINT "tracks_cadence_check" CHECK ("tracks"."cadence" is null or "tracks"."cadence" in ('3x', '4x', '5x', 'custom'))
);
--> statement-breakpoint
CREATE TABLE "programs" (
	"id" uuid PRIMARY KEY DEFAULT uuidv7() NOT NULL,
	"track_id" uuid NOT NULL,
	"code" text NOT NULL,
	"display_name" text NOT NULL,
	"starts_on" date NOT NULL,
	"ends_on" date NOT NULL,
	"state" text DEFAULT 'draft' NOT NULL,
	"cms_source_id" text,
	"cms_revision" text,
	"metadata" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "programs_track_code_unique" UNIQUE("track_id","code"),
	CONSTRAINT "programs_state_check" CHECK ("programs"."state" in ('draft', 'scheduled', 'live', 'archived')),
	CONSTRAINT "programs_dates_check" CHECK ("programs"."ends_on" >= "programs"."starts_on")
);
--> statement-breakpoint
CREATE TABLE "mesocycles" (
	"id" uuid PRIMARY KEY DEFAULT uuidv7() NOT NULL,
	"program_id" uuid NOT NULL,
	"position" integer NOT NULL,
	"display_name" text NOT NULL,
	"intent" text,
	"starts_on" date NOT NULL,
	"ends_on" date NOT NULL,
	"cms_source_id" text,
	"cms_revision" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "mesocycles_program_position_unique" UNIQUE("program_id","position"),
	CONSTRAINT "mesocycles_intent_check" CHECK ("mesocycles"."intent" is null or "mesocycles"."intent" in ('hypertrophy', 'strength', 'conditioning', 'mixed', 'deload')),
	CONSTRAINT "mesocycles_dates_check" CHECK ("mesocycles"."ends_on" >= "mesocycles"."starts_on")
);
--> statement-breakpoint
CREATE TABLE "microcycles" (
	"id" uuid PRIMARY KEY DEFAULT uuidv7() NOT NULL,
	"program_id" uuid NOT NULL,
	"mesocycle_id" uuid,
	"position" integer NOT NULL,
	"kind" text DEFAULT 'standard' NOT NULL,
	"display_name" text NOT NULL,
	"starts_on" date NOT NULL,
	"ends_on" date NOT NULL,
	"deload_intensity_pct" integer,
	"cms_source_id" text,
	"cms_revision" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "microcycles_kind_check" CHECK ("microcycles"."kind" in ('standard', 'bridge_week', 'deload', 'orphan_bridge')),
	CONSTRAINT "microcycles_dates_check" CHECK ("microcycles"."ends_on" = "microcycles"."starts_on" + interval '6 days'),
	CONSTRAINT "microcycles_deload_pct_check" CHECK ("microcycles"."deload_intensity_pct" is null or "microcycles"."deload_intensity_pct" between 40 and 100),
	CONSTRAINT "microcycles_standard_requires_meso_check" CHECK (("microcycles"."kind" = 'standard' and "microcycles"."mesocycle_id" is not null) or ("microcycles"."kind" <> 'standard'))
);
--> statement-breakpoint
CREATE TABLE "media_assets" (
	"id" uuid PRIMARY KEY DEFAULT uuidv7() NOT NULL,
	"kind" text NOT NULL,
	"provider" text NOT NULL,
	"provider_asset_id" text NOT NULL,
	"bunny_library_id" text,
	"poster_url" text,
	"duration_seconds" integer,
	"aspect_ratio" text,
	"width_px" integer,
	"height_px" integer,
	"language" text DEFAULT 'en' NOT NULL,
	"caption" text,
	"transcript" text,
	"active" boolean DEFAULT true NOT NULL,
	"cms_source_id" text,
	"cms_revision" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "media_assets_provider_asset_unique" UNIQUE("provider","provider_asset_id"),
	CONSTRAINT "media_assets_kind_check" CHECK ("media_assets"."kind" in ('video', 'audio', 'image')),
	CONSTRAINT "media_assets_provider_check" CHECK ("media_assets"."provider" in ('bunny', 'mux', 'sanity')),
	CONSTRAINT "media_assets_aspect_check" CHECK ("media_assets"."aspect_ratio" is null or "media_assets"."aspect_ratio" in ('16:9', '9:16', '1:1', '4:3', '21:9')),
	CONSTRAINT "media_assets_bunny_lib_check" CHECK (("media_assets"."provider" = 'bunny') = ("media_assets"."bunny_library_id" is not null))
);
--> statement-breakpoint
CREATE TABLE "movement_media" (
	"movement_id" uuid NOT NULL,
	"media_asset_id" uuid NOT NULL,
	"role" text DEFAULT 'primary_demo' NOT NULL,
	"position" integer DEFAULT 0 NOT NULL,
	"notes" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "movement_media_movement_id_media_asset_id_role_pk" PRIMARY KEY("movement_id","media_asset_id","role"),
	CONSTRAINT "movement_media_role_check" CHECK ("movement_media"."role" in ('primary_demo', 'alternate_angle', 'tutorial', 'cue', 'common_mistake', 'setup', 'coach_intro'))
);
--> statement-breakpoint
CREATE TABLE "movements" (
	"id" uuid PRIMARY KEY DEFAULT uuidv7() NOT NULL,
	"cms_source_id" text,
	"cms_revision" text,
	"name" text NOT NULL,
	"alternate_names" text[] DEFAULT '{}'::text[] NOT NULL,
	"primary_muscle" text,
	"secondary_muscles" text[] DEFAULT '{}'::text[] NOT NULL,
	"equipment" text NOT NULL,
	"movement_pattern" text,
	"plane" text,
	"joint_action" text,
	"unilateral" boolean DEFAULT false NOT NULL,
	"difficulty" integer,
	"coach_cues" text,
	"primary_video_provider" text,
	"primary_video_id" text,
	"primary_video_poster_url" text,
	"primary_video_duration_seconds" integer,
	"active" boolean DEFAULT true NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "movements_equipment_check" CHECK ("movements"."equipment" in ('barbell', 'db', 'kb', 'bodyweight', 'machine', 'bands', 'cable', 'mixed', 'sled', 'plate', 'rings', 'specialty')),
	CONSTRAINT "movements_pattern_check" CHECK ("movements"."movement_pattern" is null or "movements"."movement_pattern" in ('squat', 'hinge', 'push_horizontal', 'push_vertical', 'pull_horizontal', 'pull_vertical', 'carry', 'locomotion', 'rotation', 'isometric', 'complex', 'jump', 'olympic', 'accessory')),
	CONSTRAINT "movements_plane_check" CHECK ("movements"."plane" is null or "movements"."plane" in ('sagittal', 'frontal', 'transverse', 'multi')),
	CONSTRAINT "movements_difficulty_check" CHECK ("movements"."difficulty" is null or "movements"."difficulty" between 1 and 5),
	CONSTRAINT "movements_video_provider_check" CHECK ("movements"."primary_video_provider" is null or "movements"."primary_video_provider" in ('bunny', 'mux'))
);
--> statement-breakpoint
CREATE TABLE "days" (
	"id" uuid PRIMARY KEY DEFAULT uuidv7() NOT NULL,
	"microcycle_id" uuid NOT NULL,
	"position" integer NOT NULL,
	"scheduled_on" date NOT NULL,
	"display_name" text NOT NULL,
	"kind" text DEFAULT 'workout' NOT NULL,
	"is_optional" boolean DEFAULT false NOT NULL,
	"default_activity_type" text,
	"hero_movement_id" uuid,
	"cms_source_id" text,
	"cms_revision" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "days_microcycle_position_unique" UNIQUE("microcycle_id","position"),
	CONSTRAINT "days_kind_check" CHECK ("days"."kind" in ('workout', 'active_recovery', 'mobility', 'rest', 'lesson')),
	CONSTRAINT "days_position_check" CHECK ("days"."position" between 1 and 7),
	CONSTRAINT "days_activity_type_check" CHECK ("days"."default_activity_type" is null or "days"."default_activity_type" in ('functional_strength_training', 'traditional_strength_training', 'high_intensity_interval_training', 'cross_training', 'cycling', 'running', 'rowing', 'mind_and_body', 'flexibility', 'other'))
);
--> statement-breakpoint
CREATE TABLE "sections" (
	"id" uuid PRIMARY KEY DEFAULT uuidv7() NOT NULL,
	"day_id" uuid NOT NULL,
	"position" integer NOT NULL,
	"letter" text NOT NULL,
	"kind" text NOT NULL,
	"display_name" text NOT NULL,
	"target_duration_min" integer,
	"target_duration_max" integer,
	"prescription_mode" text DEFAULT 'straight_sets' NOT NULL,
	"daily_focus_note" text,
	"effort_note" text,
	"cms_source_id" text,
	"cms_revision" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "sections_day_position_unique" UNIQUE("day_id","position"),
	CONSTRAINT "sections_letter_check" CHECK (length("sections"."letter") = 1 and "sections"."letter" ~ '^[A-Z]$'),
	CONSTRAINT "sections_kind_check" CHECK ("sections"."kind" in ('focus_note', 'warmup', 'speed_strength', 'strength_intensity', 'strength_balance', 'finisher', 'conditioning', 'intervals', 'mobility', 'cooldown', 'active_recovery', 'lesson', 'engine_hot_start', 'kettlebell_hot_start', 'upper_couplets', 'interval_pyramid', 'high_turnover_cardio')),
	CONSTRAINT "sections_prescription_mode_check" CHECK ("sections"."prescription_mode" in ('straight_sets', 'every_x_minutes', 'emom', 'e2mom', 'e3mom', 'amrap', 'for_time', 'tabata', 'density', 'rounds', 'interval_pyramid', 'continuous_effort', 'free')),
	CONSTRAINT "sections_duration_min_check" CHECK ("sections"."target_duration_min" is null or "sections"."target_duration_min" > 0),
	CONSTRAINT "sections_duration_max_check" CHECK ("sections"."target_duration_max" is null or "sections"."target_duration_max" >= coalesce("sections"."target_duration_min", 0))
);
--> statement-breakpoint
CREATE TABLE "prescribed_groups" (
	"id" uuid PRIMARY KEY DEFAULT uuidv7() NOT NULL,
	"section_id" uuid NOT NULL,
	"position" integer NOT NULL,
	"round_count_min" integer,
	"round_count_max" integer,
	"interval_seconds" integer,
	"cap_seconds" integer,
	"rest_between_rounds_seconds_min" integer,
	"rest_between_rounds_seconds_max" integer,
	"rest_between_rounds_text" text,
	"loading_note" text,
	"effort_note" text,
	"short_on_time_remove" boolean DEFAULT false NOT NULL,
	"scoring" text,
	"metadata" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"cms_source_id" text,
	"cms_revision" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "prescribed_groups_section_position_unique" UNIQUE("section_id","position"),
	CONSTRAINT "prescribed_groups_round_min_check" CHECK ("prescribed_groups"."round_count_min" is null or "prescribed_groups"."round_count_min" > 0),
	CONSTRAINT "prescribed_groups_round_max_check" CHECK ("prescribed_groups"."round_count_max" is null or "prescribed_groups"."round_count_max" >= coalesce("prescribed_groups"."round_count_min", 0)),
	CONSTRAINT "prescribed_groups_rest_max_check" CHECK ("prescribed_groups"."rest_between_rounds_seconds_max" is null or "prescribed_groups"."rest_between_rounds_seconds_max" >= coalesce("prescribed_groups"."rest_between_rounds_seconds_min", 0)),
	CONSTRAINT "prescribed_groups_scoring_check" CHECK ("prescribed_groups"."scoring" is null or "prescribed_groups"."scoring" in ('reps', 'time', 'rounds_plus_reps', 'distance', 'calories'))
);
--> statement-breakpoint
CREATE TABLE "prescribed_exercises" (
	"id" uuid PRIMARY KEY DEFAULT uuidv7() NOT NULL,
	"group_id" uuid NOT NULL,
	"position" integer NOT NULL,
	"movement_id" uuid NOT NULL,
	"alternate_of_exercise_id" uuid,
	"chained_into_next" boolean DEFAULT false NOT NULL,
	"rest_after_seconds_min" integer,
	"rest_after_seconds_max" integer,
	"rest_after_text" text,
	"is_unilateral" boolean DEFAULT false NOT NULL,
	"per_side_starts" text,
	"notes" text,
	"cms_source_id" text,
	"cms_revision" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "prescribed_exercises_self_ref_check" CHECK ("prescribed_exercises"."alternate_of_exercise_id" is null or "prescribed_exercises"."alternate_of_exercise_id" <> "prescribed_exercises"."id"),
	CONSTRAINT "prescribed_exercises_per_side_check" CHECK ("prescribed_exercises"."per_side_starts" is null or "prescribed_exercises"."per_side_starts" in ('left', 'right', 'either')),
	CONSTRAINT "prescribed_exercises_rest_max_check" CHECK ("prescribed_exercises"."rest_after_seconds_max" is null or "prescribed_exercises"."rest_after_seconds_max" >= coalesce("prescribed_exercises"."rest_after_seconds_min", 0))
);
--> statement-breakpoint
CREATE TABLE "prescribed_sets" (
	"id" uuid PRIMARY KEY DEFAULT uuidv7() NOT NULL,
	"exercise_id" uuid NOT NULL,
	"position" integer NOT NULL,
	"set_kind" text DEFAULT 'working' NOT NULL,
	"reps_kind" text DEFAULT 'fixed' NOT NULL,
	"reps_min" integer,
	"reps_max" integer,
	"reps_text" text,
	"duration_seconds_min" integer,
	"duration_seconds_max" integer,
	"per_side" boolean DEFAULT false NOT NULL,
	"tempo" text,
	"rpe_min" numeric(3, 1),
	"rpe_max" numeric(3, 1),
	"rpe_text" text,
	"weight_ref" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"rest_after_seconds_min" integer,
	"rest_after_seconds_max" integer,
	"rest_after_text" text,
	"has_drop_set" boolean DEFAULT false NOT NULL,
	"drop_set_descriptor" jsonb,
	"notes" text,
	"cms_source_id" text,
	"cms_revision" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "prescribed_sets_exercise_position_unique" UNIQUE("exercise_id","position"),
	CONSTRAINT "prescribed_sets_set_kind_check" CHECK ("prescribed_sets"."set_kind" in ('warmup', 'working', 'max_unbroken', 'drop', 'back_off', 'isometric_hold', 'complex', 'primer')),
	CONSTRAINT "prescribed_sets_reps_kind_check" CHECK ("prescribed_sets"."reps_kind" in ('fixed', 'range', 'max_unbroken', 'time', 'per_side_fixed', 'per_side_range', 'per_side_time', 'complex_unit')),
	CONSTRAINT "prescribed_sets_reps_min_check" CHECK ("prescribed_sets"."reps_min" is null or "prescribed_sets"."reps_min" > 0),
	CONSTRAINT "prescribed_sets_reps_max_check" CHECK ("prescribed_sets"."reps_max" is null or "prescribed_sets"."reps_max" >= coalesce("prescribed_sets"."reps_min", 0)),
	CONSTRAINT "prescribed_sets_duration_min_check" CHECK ("prescribed_sets"."duration_seconds_min" is null or "prescribed_sets"."duration_seconds_min" > 0),
	CONSTRAINT "prescribed_sets_duration_max_check" CHECK ("prescribed_sets"."duration_seconds_max" is null or "prescribed_sets"."duration_seconds_max" >= coalesce("prescribed_sets"."duration_seconds_min", 0)),
	CONSTRAINT "prescribed_sets_tempo_check" CHECK ("prescribed_sets"."tempo" is null or (length("prescribed_sets"."tempo") = 4 and "prescribed_sets"."tempo" ~ '^[0-9XA]{4}$')),
	CONSTRAINT "prescribed_sets_rpe_min_check" CHECK ("prescribed_sets"."rpe_min" is null or ("prescribed_sets"."rpe_min" >= 1 and "prescribed_sets"."rpe_min" <= 10)),
	CONSTRAINT "prescribed_sets_rpe_max_check" CHECK ("prescribed_sets"."rpe_max" is null or ("prescribed_sets"."rpe_max" >= coalesce("prescribed_sets"."rpe_min", 0) and "prescribed_sets"."rpe_max" <= 10)),
	CONSTRAINT "prescribed_sets_rest_max_check" CHECK ("prescribed_sets"."rest_after_seconds_max" is null or "prescribed_sets"."rest_after_seconds_max" >= coalesce("prescribed_sets"."rest_after_seconds_min", 0))
);
--> statement-breakpoint
CREATE TABLE "coaching_notes" (
	"id" uuid PRIMARY KEY DEFAULT uuidv7() NOT NULL,
	"scope" text NOT NULL,
	"scope_id" uuid NOT NULL,
	"kind" text NOT NULL,
	"title" text,
	"body_markdown" text NOT NULL,
	"cms_source_id" text,
	"cms_revision" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "coaching_notes_scope_check" CHECK ("coaching_notes"."scope" in ('day', 'section', 'group', 'program', 'lesson', 'mesocycle', 'block', 'microcycle')),
	CONSTRAINT "coaching_notes_kind_check" CHECK ("coaching_notes"."kind" in ('focus', 'loading', 'effort', 'lesson', 'short_on_time', 'intro', 'outro'))
);
--> statement-breakpoint
CREATE TABLE "mobility_flow_steps" (
	"id" uuid PRIMARY KEY DEFAULT uuidv7() NOT NULL,
	"flow_id" uuid NOT NULL,
	"position" integer NOT NULL,
	"movement_id" uuid,
	"display_text" text NOT NULL,
	"duration_seconds_min" integer,
	"duration_seconds_max" integer,
	"reps_min" integer,
	"reps_max" integer,
	"per_side" boolean DEFAULT false NOT NULL,
	"notes" text,
	CONSTRAINT "mobility_flow_steps_flow_position_unique" UNIQUE("flow_id","position")
);
--> statement-breakpoint
CREATE TABLE "mobility_flows" (
	"id" uuid PRIMARY KEY DEFAULT uuidv7() NOT NULL,
	"code" text NOT NULL,
	"display_name" text NOT NULL,
	"description" text,
	"target_duration_min" integer,
	"target_duration_max" integer,
	"active" boolean DEFAULT true NOT NULL,
	"cms_source_id" text,
	"cms_revision" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "mobility_flows_code_unique" UNIQUE("code")
);
--> statement-breakpoint
CREATE TABLE "upload_jobs" (
	"id" uuid PRIMARY KEY DEFAULT uuidv7() NOT NULL,
	"status" text DEFAULT 'queued' NOT NULL,
	"filename" text NOT NULL,
	"size_bytes" bigint NOT NULL,
	"dry_run" boolean DEFAULT false NOT NULL,
	"request_id" text NOT NULL,
	"result_payload" jsonb,
	"error_message" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"started_at" timestamp with time zone,
	"finished_at" timestamp with time zone,
	CONSTRAINT "upload_jobs_status_check" CHECK ("upload_jobs"."status" in ('queued', 'running', 'succeeded', 'failed'))
);
--> statement-breakpoint
ALTER TABLE "programs" ADD CONSTRAINT "programs_track_id_tracks_id_fk" FOREIGN KEY ("track_id") REFERENCES "public"."tracks"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "mesocycles" ADD CONSTRAINT "mesocycles_program_id_programs_id_fk" FOREIGN KEY ("program_id") REFERENCES "public"."programs"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "microcycles" ADD CONSTRAINT "microcycles_program_id_programs_id_fk" FOREIGN KEY ("program_id") REFERENCES "public"."programs"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "microcycles" ADD CONSTRAINT "microcycles_mesocycle_id_mesocycles_id_fk" FOREIGN KEY ("mesocycle_id") REFERENCES "public"."mesocycles"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "movement_media" ADD CONSTRAINT "movement_media_movement_id_movements_id_fk" FOREIGN KEY ("movement_id") REFERENCES "public"."movements"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "movement_media" ADD CONSTRAINT "movement_media_media_asset_id_media_assets_id_fk" FOREIGN KEY ("media_asset_id") REFERENCES "public"."media_assets"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "days" ADD CONSTRAINT "days_microcycle_id_microcycles_id_fk" FOREIGN KEY ("microcycle_id") REFERENCES "public"."microcycles"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "days" ADD CONSTRAINT "days_hero_movement_id_movements_id_fk" FOREIGN KEY ("hero_movement_id") REFERENCES "public"."movements"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "sections" ADD CONSTRAINT "sections_day_id_days_id_fk" FOREIGN KEY ("day_id") REFERENCES "public"."days"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "prescribed_groups" ADD CONSTRAINT "prescribed_groups_section_id_sections_id_fk" FOREIGN KEY ("section_id") REFERENCES "public"."sections"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "prescribed_exercises" ADD CONSTRAINT "prescribed_exercises_group_id_prescribed_groups_id_fk" FOREIGN KEY ("group_id") REFERENCES "public"."prescribed_groups"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "prescribed_exercises" ADD CONSTRAINT "prescribed_exercises_movement_id_movements_id_fk" FOREIGN KEY ("movement_id") REFERENCES "public"."movements"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "prescribed_exercises" ADD CONSTRAINT "prescribed_exercises_alternate_fk" FOREIGN KEY ("alternate_of_exercise_id") REFERENCES "public"."prescribed_exercises"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "prescribed_sets" ADD CONSTRAINT "prescribed_sets_exercise_id_prescribed_exercises_id_fk" FOREIGN KEY ("exercise_id") REFERENCES "public"."prescribed_exercises"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "mobility_flow_steps" ADD CONSTRAINT "mobility_flow_steps_flow_id_mobility_flows_id_fk" FOREIGN KEY ("flow_id") REFERENCES "public"."mobility_flows"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "mobility_flow_steps" ADD CONSTRAINT "mobility_flow_steps_movement_id_movements_id_fk" FOREIGN KEY ("movement_id") REFERENCES "public"."movements"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "tracks_family_idx" ON "tracks" USING btree ("family");--> statement-breakpoint
CREATE INDEX "tracks_active_idx" ON "tracks" USING btree ("sort_order") WHERE "tracks"."active" = true;--> statement-breakpoint
CREATE INDEX "programs_track_id_idx" ON "programs" USING btree ("track_id");--> statement-breakpoint
CREATE INDEX "programs_live_window_idx" ON "programs" USING btree ("starts_on","ends_on") WHERE "programs"."state" = 'live';--> statement-breakpoint
CREATE INDEX "programs_cms_source_idx" ON "programs" USING btree ("cms_source_id") WHERE "programs"."cms_source_id" is not null;--> statement-breakpoint
CREATE INDEX "mesocycles_program_id_idx" ON "mesocycles" USING btree ("program_id");--> statement-breakpoint
CREATE INDEX "mesocycles_window_idx" ON "mesocycles" USING btree ("starts_on","ends_on");--> statement-breakpoint
CREATE INDEX "microcycles_program_id_idx" ON "microcycles" USING btree ("program_id");--> statement-breakpoint
CREATE INDEX "microcycles_mesocycle_id_idx" ON "microcycles" USING btree ("mesocycle_id");--> statement-breakpoint
CREATE INDEX "microcycles_window_idx" ON "microcycles" USING btree ("starts_on","ends_on");--> statement-breakpoint
CREATE INDEX "microcycles_bridge_idx" ON "microcycles" USING btree ("program_id","starts_on") WHERE "microcycles"."kind" <> 'standard';--> statement-breakpoint
CREATE INDEX "media_assets_kind_active_idx" ON "media_assets" USING btree ("kind") WHERE "media_assets"."active" = true;--> statement-breakpoint
CREATE INDEX "media_assets_cms_source_idx" ON "media_assets" USING btree ("cms_source_id") WHERE "media_assets"."cms_source_id" is not null;--> statement-breakpoint
CREATE INDEX "movement_media_movement_idx" ON "movement_media" USING btree ("movement_id","role","position");--> statement-breakpoint
CREATE INDEX "movement_media_asset_idx" ON "movement_media" USING btree ("media_asset_id");--> statement-breakpoint
CREATE UNIQUE INDEX "movement_media_one_primary" ON "movement_media" USING btree ("movement_id") WHERE role = 'primary_demo';--> statement-breakpoint
CREATE INDEX "movements_active_idx" ON "movements" USING btree ("name") WHERE "movements"."active" = true;--> statement-breakpoint
CREATE INDEX "movements_equipment_idx" ON "movements" USING btree ("equipment") WHERE "movements"."active" = true;--> statement-breakpoint
CREATE INDEX "movements_pattern_idx" ON "movements" USING btree ("movement_pattern") WHERE "movements"."active" = true;--> statement-breakpoint
CREATE INDEX "movements_with_video_idx" ON "movements" USING btree ("name") WHERE "movements"."active" = true and "movements"."primary_video_id" is not null;--> statement-breakpoint
CREATE INDEX "movements_alt_names_idx" ON "movements" USING gin ("alternate_names");--> statement-breakpoint
CREATE INDEX "movements_secondary_idx" ON "movements" USING gin ("secondary_muscles");--> statement-breakpoint
CREATE INDEX "movements_name_trgm_idx" ON "movements" USING gin ("name" gin_trgm_ops);--> statement-breakpoint
CREATE INDEX "days_microcycle_id_idx" ON "days" USING btree ("microcycle_id");--> statement-breakpoint
CREATE INDEX "days_scheduled_on_idx" ON "days" USING btree ("scheduled_on");--> statement-breakpoint
CREATE INDEX "days_hero_movement_id_idx" ON "days" USING btree ("hero_movement_id") WHERE "days"."hero_movement_id" is not null;--> statement-breakpoint
CREATE INDEX "sections_day_id_idx" ON "sections" USING btree ("day_id");--> statement-breakpoint
CREATE INDEX "sections_kind_idx" ON "sections" USING btree ("kind");--> statement-breakpoint
CREATE INDEX "prescribed_groups_section_id_idx" ON "prescribed_groups" USING btree ("section_id");--> statement-breakpoint
CREATE INDEX "prescribed_groups_short_on_time_idx" ON "prescribed_groups" USING btree ("section_id") WHERE "prescribed_groups"."short_on_time_remove";--> statement-breakpoint
CREATE UNIQUE INDEX "prescribed_exercises_primary_unique" ON "prescribed_exercises" USING btree ("group_id","position") WHERE alternate_of_exercise_id is null;--> statement-breakpoint
CREATE UNIQUE INDEX "prescribed_exercises_alternate_unique" ON "prescribed_exercises" USING btree ("group_id","position","alternate_of_exercise_id") WHERE alternate_of_exercise_id is not null;--> statement-breakpoint
CREATE INDEX "prescribed_exercises_group_id_idx" ON "prescribed_exercises" USING btree ("group_id");--> statement-breakpoint
CREATE INDEX "prescribed_exercises_movement_id_idx" ON "prescribed_exercises" USING btree ("movement_id");--> statement-breakpoint
CREATE INDEX "prescribed_exercises_alternate_idx" ON "prescribed_exercises" USING btree ("alternate_of_exercise_id") WHERE "prescribed_exercises"."alternate_of_exercise_id" is not null;--> statement-breakpoint
CREATE INDEX "prescribed_sets_exercise_id_idx" ON "prescribed_sets" USING btree ("exercise_id");--> statement-breakpoint
CREATE INDEX "prescribed_sets_weight_ref_gin" ON "prescribed_sets" USING gin (weight_ref jsonb_path_ops);--> statement-breakpoint
CREATE INDEX "coaching_notes_scope_idx" ON "coaching_notes" USING btree ("scope","scope_id");--> statement-breakpoint
CREATE INDEX "mobility_flow_steps_flow_id_idx" ON "mobility_flow_steps" USING btree ("flow_id");--> statement-breakpoint
CREATE INDEX "mobility_flow_steps_movement_id_idx" ON "mobility_flow_steps" USING btree ("movement_id");--> statement-breakpoint
CREATE INDEX "upload_jobs_status_idx" ON "upload_jobs" USING btree ("status","created_at");