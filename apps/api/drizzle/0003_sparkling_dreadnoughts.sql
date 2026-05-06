ALTER TABLE "user_track_follows" DROP CONSTRAINT "user_track_follows_user_id_track_id_pk";--> statement-breakpoint
ALTER TABLE "user_track_follows" ADD CONSTRAINT "user_track_follows_user_id_track_id_followed_at_pk" PRIMARY KEY("user_id","track_id","followed_at");--> statement-breakpoint
ALTER TABLE "user_track_follows" ADD COLUMN "unfollowed_at" timestamp with time zone;--> statement-breakpoint
CREATE UNIQUE INDEX "user_track_follows_active_unique" ON "user_track_follows" USING btree ("user_id","track_id") WHERE "user_track_follows"."unfollowed_at" is null;