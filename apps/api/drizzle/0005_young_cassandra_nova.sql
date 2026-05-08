CREATE TABLE "system_prompts" (
	"id" uuid PRIMARY KEY DEFAULT uuidv7() NOT NULL,
	"slug" text NOT NULL,
	"body_markdown" text NOT NULL,
	"is_active" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"label" text DEFAULT '' NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX "system_prompts_active_unique" ON "system_prompts" USING btree ("slug") WHERE "system_prompts"."is_active" = true;--> statement-breakpoint
CREATE INDEX "system_prompts_slug_created_idx" ON "system_prompts" USING btree ("slug","created_at");