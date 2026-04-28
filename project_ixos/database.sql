-- =============================================================================
-- IXOS — PostgreSQL Schema  MVP
-- =============================================================================
-- Kept:  Core catalog, Mood engine, Users, Library, Playlists, Player
-- Cut:   Monetization, Social/Listening parties, DJ mode, Notifications,
--        Recommendations (similarity), Waveform data, Audio analysis fields,
--        Partitioned history, search_index view, trigram indexes
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- EXTENSIONS & ENUMS
-- ─────────────────────────────────────────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TYPE repeat_mode         AS ENUM ('none', 'one', 'all');
CREATE TYPE download_status     AS ENUM ('pending', 'downloading', 'completed', 'failed');
CREATE TYPE playlist_visibility AS ENUM ('private', 'public');

-- ─────────────────────────────────────────────────────────────────────────────
-- CORE CATALOG
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE artists (
    id          UUID    PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        TEXT    NOT NULL,
    image_url   TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE albums (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title        TEXT NOT NULL,
    artist_id    UUID NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
    cover_url    TEXT,
    release_year SMALLINT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE genres (
    id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name     TEXT NOT NULL UNIQUE,
    color_hex CHAR(7)
);

INSERT INTO genres (name, color_hex) VALUES
    ('Pop',         '#F72585'),
    ('Rock',        '#7B2D8B'),
    ('Hip-Hop',     '#F4A261'),
    ('Electronic',  '#4CC9F0'),
    ('Jazz',        '#E9C46A'),
    ('Clásica',     '#264653'),
    ('Reggaeton',   '#E76F51'),
    ('R&B / Soul',  '#9B5DE5'),
    ('Lo-Fi',       '#06D6A0'),
    ('Metal',       '#2B2D42'),
    ('Ambient',     '#80B3FF'),
    ('Latin',       '#FF6B6B'),
    ('Alternative', '#A8DADC');

-- Songs — fields driven by the YouTube ingest JSON
CREATE TABLE songs (
    id           UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    file_id      TEXT          NOT NULL UNIQUE,   -- "{uuid}.mp3" from ingest pipeline
    file_path    TEXT          NOT NULL,           -- "music/{uuid}.mp3"
    cdn_url      TEXT,
    title        TEXT          NOT NULL,
    artist_id    UUID          NOT NULL REFERENCES artists(id) ON DELETE RESTRICT,
    album_id     UUID          REFERENCES albums(id) ON DELETE SET NULL,
    cover_url    TEXT,
    release_year SMALLINT,
    duration_s   NUMERIC(10,2) NOT NULL,           -- seconds, e.g. 222.12
    explicit     BOOLEAN       NOT NULL DEFAULT FALSE,
    play_count   BIGINT        NOT NULL DEFAULT 0,
    created_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE TABLE song_genres (
    song_id  UUID NOT NULL REFERENCES songs(id)   ON DELETE CASCADE,
    genre_id UUID NOT NULL REFERENCES genres(id)  ON DELETE CASCADE,
    PRIMARY KEY (song_id, genre_id)
);

-- Time-synced lyrics (one row per line)
CREATE TABLE lyrics (
    id         UUID     PRIMARY KEY DEFAULT uuid_generate_v4(),
    song_id    UUID     NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
    line_index SMALLINT NOT NULL,
    start_ms   INT      NOT NULL,
    end_ms     INT      NOT NULL,
    text       TEXT     NOT NULL
);

-- ─────────────────────────────────────────────────────────────────────────────
-- MOOD ENGINE
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE moods (
    id             UUID     PRIMARY KEY DEFAULT uuid_generate_v4(),
    name           TEXT     NOT NULL UNIQUE,   -- slug: 'feliz', 'focus', …
    display_name   TEXT     NOT NULL,
    icon_name      TEXT     NOT NULL,
    gradient_start CHAR(7)  NOT NULL,
    gradient_end   CHAR(7)  NOT NULL,
    sort_order     SMALLINT NOT NULL DEFAULT 0
);

INSERT INTO moods (name, display_name, icon_name, gradient_start, gradient_end, sort_order) VALUES
    ('feliz',   'Feliz',   'sentiment_satisfied', '#FACC15', '#F97316', 1),
    ('triste',  'Triste',  'cloud',               '#475569', '#1E3A5F', 2),
    ('focus',   'Focus',   'headphones',          '#6366F1', '#7C3AED', 3),
    ('energia', 'Energía', 'bolt',                '#DC2626', '#18181B', 4),
    ('relax',   'Relax',   'spa',                 '#2DD4BF', '#059669', 5),
    ('fiesta',  'Fiesta',  'local_bar',           '#EC4899', '#E11D48', 6),
    ('dormir',  'Dormir',  'nightlight',          '#1C1917', '#000000', 7),
    ('romance', 'Romance', 'favorite',            '#FB7185', '#EF4444', 8);

-- Tag songs to moods (manually or by AI pipeline)
CREATE TABLE song_moods (
    song_id  UUID         NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
    mood_id  UUID         NOT NULL REFERENCES moods(id) ON DELETE CASCADE,
    score    NUMERIC(4,3) NOT NULL DEFAULT 1.0,  -- 1.0 = manual, <1.0 = AI confidence
    PRIMARY KEY (song_id, mood_id)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- USERS
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE users (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username     TEXT NOT NULL UNIQUE,
    email        TEXT NOT NULL UNIQUE,
    display_name TEXT,
    avatar_url   TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- LIBRARY
-- ─────────────────────────────────────────────────────────────────────────────

-- Feature 4 (Fabi) — liked songs
CREATE TABLE liked_songs (
    user_id  UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    song_id  UUID        NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
    liked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, song_id)
);

-- Feature 2 (Fernando) — offline downloads
CREATE TABLE downloads (
    id              UUID           PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID           NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    song_id         UUID           NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
    status          download_status NOT NULL DEFAULT 'pending',
    file_size_bytes BIGINT,
    local_path      TEXT,
    downloaded_at   TIMESTAMPTZ,
    UNIQUE (user_id, song_id)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- PLAYLISTS  (Feature 3 — Andrés)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE playlists (
    id             UUID                PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id       UUID                NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name           TEXT                NOT NULL,
    description    TEXT,
    cover_url      TEXT,
    visibility     playlist_visibility NOT NULL DEFAULT 'private',
    mood_id        UUID                REFERENCES moods(id) ON DELETE SET NULL,
    total_songs    INT                 NOT NULL DEFAULT 0,    -- kept by trigger
    total_duration_s NUMERIC(12,2)     NOT NULL DEFAULT 0,   -- kept by trigger
    created_at     TIMESTAMPTZ         NOT NULL DEFAULT NOW()
);

CREATE TABLE playlist_songs (
    playlist_id UUID        NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
    song_id     UUID        NOT NULL REFERENCES songs(id)     ON DELETE CASCADE,
    position    INT         NOT NULL,
    added_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (playlist_id, song_id),
    UNIQUE (playlist_id, position)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- PLAYER  (Feature 5 — Belén)
-- ─────────────────────────────────────────────────────────────────────────────

-- Persisted playback state — restored on app relaunch
CREATE TABLE player_state (
    user_id         UUID          PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    current_song_id UUID          REFERENCES songs(id) ON DELETE SET NULL,
    position_s      NUMERIC(10,2) NOT NULL DEFAULT 0,
    repeat          repeat_mode   NOT NULL DEFAULT 'none',
    shuffle         BOOLEAN       NOT NULL DEFAULT FALSE,
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Lightweight history — drives mood recommendations over time
CREATE TABLE listening_history (
    id          UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    song_id     UUID          NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
    mood_id     UUID          REFERENCES moods(id) ON DELETE SET NULL,
    duration_s  NUMERIC(10,2) NOT NULL,
    completed   BOOLEAN       NOT NULL DEFAULT FALSE,
    listened_at TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- INDEXES
-- ─────────────────────────────────────────────────────────────────────────────

-- Search
CREATE INDEX idx_songs_title    ON songs  (title);
CREATE INDEX idx_artists_name   ON artists (name);

-- Catalog joins
CREATE INDEX idx_songs_artist         ON songs           (artist_id);
CREATE INDEX idx_songs_album          ON songs           (album_id);
CREATE INDEX idx_albums_artist        ON albums          (artist_id);
CREATE INDEX idx_song_moods_mood      ON song_moods      (mood_id);
CREATE INDEX idx_playlist_songs_order ON playlist_songs  (playlist_id, position);
CREATE INDEX idx_liked_songs_user     ON liked_songs     (user_id, liked_at DESC);
CREATE INDEX idx_downloads_user       ON downloads       (user_id, status);
CREATE INDEX idx_history_user         ON listening_history (user_id, listened_at DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- TRIGGERS
-- ─────────────────────────────────────────────────────────────────────────────

-- Keep playlist totals accurate after any song insert/delete
CREATE OR REPLACE FUNCTION update_playlist_stats()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE playlists SET
        total_songs      = (SELECT COUNT(*)         FROM playlist_songs ps WHERE ps.playlist_id = COALESCE(NEW.playlist_id, OLD.playlist_id)),
        total_duration_s = (SELECT COALESCE(SUM(s.duration_s), 0) FROM playlist_songs ps JOIN songs s ON s.id = ps.song_id WHERE ps.playlist_id = COALESCE(NEW.playlist_id, OLD.playlist_id))
    WHERE id = COALESCE(NEW.playlist_id, OLD.playlist_id);
    RETURN NULL;
END; $$;

CREATE TRIGGER trg_playlist_stats
AFTER INSERT OR DELETE ON playlist_songs
FOR EACH ROW EXECUTE FUNCTION update_playlist_stats();

-- Bump play_count when a song is fully listened to
CREATE OR REPLACE FUNCTION increment_play_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.completed THEN
        UPDATE songs SET play_count = play_count + 1 WHERE id = NEW.song_id;
    END IF;
    RETURN NULL;
END; $$;

CREATE TRIGGER trg_play_count
AFTER INSERT ON listening_history
FOR EACH ROW EXECUTE FUNCTION increment_play_count();

-- ─────────────────────────────────────────────────────────────────────────────
-- USAGE EXAMPLES
-- ─────────────────────────────────────────────────────────────────────────────

/*
-- Insert a song from the ingest pipeline JSON
INSERT INTO songs (file_id, file_path, title, artist_id, album_id, release_year, duration_s)
VALUES (
    'b8f5c4be-c064-4a02-8e00-7228fe171cd1.mp3',
    'music/b8f5c4be-c064-4a02-8e00-7228fe171cd1.mp3',
    'Selfless', '<artist_uuid>', '<album_uuid>', 2020, 222.12
);

-- Top songs for a mood
SELECT s.id, s.title, a.name AS artist, sm.score
FROM song_moods sm
JOIN moods  m ON m.id = sm.mood_id AND m.name = 'focus'
JOIN songs  s ON s.id = sm.song_id
JOIN artists a ON a.id = s.artist_id
ORDER BY sm.score DESC, s.play_count DESC
LIMIT 50;

-- Search by title or artist
SELECT s.id, s.title, a.name AS artist, s.cover_url
FROM songs s JOIN artists a ON a.id = s.artist_id
WHERE s.title ILIKE '%selfless%' OR a.name ILIKE '%selfless%'
LIMIT 20;

-- User's liked songs
SELECT s.id, s.title, a.name AS artist, ls.liked_at
FROM liked_songs ls
JOIN songs s ON s.id = ls.song_id
JOIN artists a ON a.id = s.artist_id
WHERE ls.user_id = '<user_uuid>'
ORDER BY ls.liked_at DESC;
*/
