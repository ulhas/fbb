CREATE TABLE "workout_sessions" (
	"id" uuid PRIMARY KEY DEFAULT uuidv7() NOT NULL,
	"user_id" uuid NOT NULL,
	"track_code" text NOT NULL,
	"scheduled_on" text NOT NULL,
	"day_id" uuid,
	"client_session_id" uuid NOT NULL,
	"started_at" timestamp with time zone NOT NULL,
	"ended_at" timestamp with time zone,
	"total_elapsed_seconds" integer DEFAULT 0 NOT NULL,
	"status" text DEFAULT 'completed' NOT NULL,
	"notes" text,
	"weight_unit" text DEFAULT 'kg' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "workout_sessions_client_session_id_unique" UNIQUE("client_session_id"),
	CONSTRAINT "workout_sessions_status_check" CHECK ("workout_sessions"."status" in ('completed', 'abandoned')),
	CONSTRAINT "workout_sessions_weight_unit_check" CHECK ("workout_sessions"."weight_unit" in ('kg', 'lb')),
	CONSTRAINT "workout_sessions_total_elapsed_check" CHECK ("workout_sessions"."total_elapsed_seconds" >= 0),
	CONSTRAINT "workout_sessions_scheduled_on_check" CHECK ("workout_sessions"."scheduled_on" ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$')
);
--> statement-breakpoint
CREATE TABLE "workout_set_logs" (
	"id" uuid PRIMARY KEY DEFAULT uuidv7() NOT NULL,
	"session_id" uuid NOT NULL,
	"section_position" integer NOT NULL,
	"group_position" integer NOT NULL,
	"exercise_position" integer NOT NULL,
	"set_position" integer NOT NULL,
	"per_side" text,
	"outcome" text NOT NULL,
	"actual_reps" integer,
	"actual_weight_kg" numeric(7, 2),
	"actual_rpe" numeric(3, 1),
	"rest_taken_seconds" integer,
	"completed_at" timestamp with time zone NOT NULL,
	CONSTRAINT "workout_set_logs_outcome_check" CHECK ("workout_set_logs"."outcome" in ('completed', 'skipped', 'partial')),
	CONSTRAINT "workout_set_logs_per_side_check" CHECK ("workout_set_logs"."per_side" is null or "workout_set_logs"."per_side" in ('first', 'second', 'done')),
	CONSTRAINT "workout_set_logs_actual_reps_check" CHECK ("workout_set_logs"."actual_reps" is null or "workout_set_logs"."actual_reps" >= 0),
	CONSTRAINT "workout_set_logs_actual_weight_check" CHECK ("workout_set_logs"."actual_weight_kg" is null or "workout_set_logs"."actual_weight_kg" >= 0),
	CONSTRAINT "workout_set_logs_actual_rpe_check" CHECK ("workout_set_logs"."actual_rpe" is null or ("workout_set_logs"."actual_rpe" >= 1 and "workout_set_logs"."actual_rpe" <= 10)),
	CONSTRAINT "workout_set_logs_rest_taken_check" CHECK ("workout_set_logs"."rest_taken_seconds" is null or "workout_set_logs"."rest_taken_seconds" >= 0)
);
--> statement-breakpoint
CREATE TABLE "workout_group_scores" (
	"id" uuid PRIMARY KEY DEFAULT uuidv7() NOT NULL,
	"session_id" uuid NOT NULL,
	"section_position" integer NOT NULL,
	"group_position" integer NOT NULL,
	"prescription_mode" text NOT NULL,
	"rounds" integer,
	"partial_reps" integer,
	"finish_seconds" integer,
	"total_reps" integer,
	CONSTRAINT "workout_group_scores_session_group_unique" UNIQUE("session_id","section_position","group_position"),
	CONSTRAINT "workout_group_scores_prescription_mode_check" CHECK ("workout_group_scores"."prescription_mode" in ('straight_sets', 'every_x_minutes', 'emom', 'e2mom', 'e3mom', 'amrap', 'for_time', 'tabata', 'density', 'rounds', 'interval_pyramid', 'continuous_effort', 'free')),
	CONSTRAINT "workout_group_scores_rounds_check" CHECK ("workout_group_scores"."rounds" is null or "workout_group_scores"."rounds" >= 0),
	CONSTRAINT "workout_group_scores_partial_reps_check" CHECK ("workout_group_scores"."partial_reps" is null or "workout_group_scores"."partial_reps" >= 0),
	CONSTRAINT "workout_group_scores_finish_seconds_check" CHECK ("workout_group_scores"."finish_seconds" is null or "workout_group_scores"."finish_seconds" >= 0),
	CONSTRAINT "workout_group_scores_total_reps_check" CHECK ("workout_group_scores"."total_reps" is null or "workout_group_scores"."total_reps" >= 0)
);
--> statement-breakpoint
ALTER TABLE "workout_sessions" ADD CONSTRAINT "workout_sessions_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "workout_sessions" ADD CONSTRAINT "workout_sessions_day_id_days_id_fk" FOREIGN KEY ("day_id") REFERENCES "public"."days"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "workout_set_logs" ADD CONSTRAINT "workout_set_logs_session_id_workout_sessions_id_fk" FOREIGN KEY ("session_id") REFERENCES "public"."workout_sessions"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "workout_group_scores" ADD CONSTRAINT "workout_group_scores_session_id_workout_sessions_id_fk" FOREIGN KEY ("session_id") REFERENCES "public"."workout_sessions"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "workout_sessions_user_scheduled_idx" ON "workout_sessions" USING btree ("user_id","scheduled_on");--> statement-breakpoint
CREATE INDEX "workout_sessions_user_started_idx" ON "workout_sessions" USING btree ("user_id","started_at");--> statement-breakpoint
CREATE INDEX "workout_set_logs_session_idx" ON "workout_set_logs" USING btree ("session_id");