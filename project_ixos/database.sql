BEGIN;

CREATE TYPE plan_type_enum AS ENUM (
    'free',
    'premium_monthly',
    'premium_yearly'
);

CREATE TYPE audio_format_enum AS ENUM (
    'mp3',
    'wav',
    'flac',
    'aac',
    'ogg'
);

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(150) NOT NULL,
    password_hash TEXT NOT NULL,
    plan_type plan_type_enum NOT NULL DEFAULT 'free',
    premium_expires_at TIMESTAMPTZ NULL,
    is_admin BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_users_username_length
        CHECK (char_length(trim(username)) >= 3),
    CONSTRAINT chk_users_email_not_empty
        CHECK (char_length(trim(email)) > 0)
);

CREATE UNIQUE INDEX uq_users_username_lower
    ON users (LOWER(username));

CREATE UNIQUE INDEX uq_users_email_lower
    ON users (LOWER(email));

CREATE TABLE moods (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(80) NOT NULL,
    slug VARCHAR(80) NOT NULL,
    description TEXT,
    cover_image TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    display_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_moods_display_order
        CHECK (display_order >= 0)
);

CREATE UNIQUE INDEX uq_moods_name_lower
    ON moods (LOWER(name));

CREATE UNIQUE INDEX uq_moods_slug_lower
    ON moods (LOWER(slug));

CREATE TABLE tracks (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    artist_name VARCHAR(150) NOT NULL,
    album_name VARCHAR(150),
    duration_seconds INTEGER NOT NULL,
    cover_image TEXT,
    audio_path TEXT NOT NULL,
    audio_format audio_format_enum NOT NULL DEFAULT 'mp3',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_tracks_duration
        CHECK (duration_seconds > 0)
);

CREATE TABLE mood_tracks (
    id BIGSERIAL PRIMARY KEY,
    mood_id BIGINT NOT NULL REFERENCES moods(id) ON DELETE CASCADE,
    track_id BIGINT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
    display_order INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT uq_mood_track UNIQUE (mood_id, track_id),
    CONSTRAINT chk_mood_tracks_display_order
        CHECK (display_order >= 0)
);

CREATE INDEX idx_mood_tracks_mood_id
    ON mood_tracks(mood_id);

CREATE INDEX idx_mood_tracks_track_id
    ON mood_tracks(track_id);

CREATE TABLE playlists (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(120) NOT NULL,
    description TEXT,
    is_public BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_playlists_user_id
    ON playlists(user_id);

CREATE TABLE playlist_tracks (
    id BIGSERIAL PRIMARY KEY,
    playlist_id BIGINT NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
    track_id BIGINT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
    position INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_playlist_track UNIQUE (playlist_id, track_id),
    CONSTRAINT uq_playlist_position UNIQUE (playlist_id, position),
    CONSTRAINT chk_playlist_tracks_position
        CHECK (position > 0)
);

CREATE INDEX idx_playlist_tracks_playlist_id
    ON playlist_tracks(playlist_id);

CREATE INDEX idx_playlist_tracks_track_id
    ON playlist_tracks(track_id);

CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_moods_updated_at
BEFORE UPDATE ON moods
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_tracks_updated_at
BEFORE UPDATE ON tracks
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_playlists_updated_at
BEFORE UPDATE ON playlists
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

COMMIT;
