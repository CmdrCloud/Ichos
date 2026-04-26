-- =============================================================================
-- MOOD MUSIC APP — PostgreSQL Schema  v2.0
-- Flutter / Android Music Player
-- =============================================================================
--
-- CHANGES FROM v1 → v2:
--
--   [JSON-driven]
--   1. songs.id            stays clean UUID (PK)
--   2. songs.file_id       NEW — stores the full filename as returned by the
--                          YouTube source: "b8f5c4be-...mp3"
--   3. songs.file_path     NEW (was file_url) — storage route "music/{uuid}.mp3"
--   4. songs.cdn_url       NEW — optional CDN URL once file is published
--   5. songs.duration_s    NEW — duration in SECONDS as NUMERIC(10,2)
--                          matching JSON field "duracion": 222.12
--                          (replaces the old duration_ms INT)
--   6. songs.bitrate       NEW — from JSON "bitrate": 192000  (bps)
--   7. songs.sample_rate   NEW — from JSON "sample_rate": 48000  (Hz)
--   8. songs.channels      NEW — from JSON "canales": 2
--   9. songs.release_year  NEW — from JSON metadata "anio": "2020"
--                          (albums already have release_date but JSON only
--                           gives us the year)
--  10. albums.release_year NEW — quick year lookup without parsing release_date
--
--   [Medium article]
--  11. similarity          NEW — pre-computed user↔song similarity scores
--                          (collaborative filtering for mood recommendations)
--  12. subscription_plans  NEW — Free / Premium tiers
--  13. user_subscriptions  NEW — which plan a user is on + start/end dates
--  14. payments            NEW — payment history
--  15. notifications       NEW — push / in-app notifications
--
-- =============================================================================
-- Sections:
--   1. Extensions & Enums
--   2. Core Catalog        (artists, albums, genres, songs, lyrics)
--   3. Mood Engine         (moods, song_moods, mood_sessions)
--   4. Users & Auth
--   5. Monetization        (subscription_plans, user_subscriptions, payments)
--   6. Library             (liked_songs, downloads)
--   7. Playlists           (playlists, playlist_songs)
--   8. Player              (queue, player_state, listening_history)
--   9. Recommendations     (similarity)
--  10. Social              (listening_parties, party_members, party_chat)
--  11. DJ Mode             (dj_sessions, dj_tracks)
--  12. Notifications
--  13. Search support      (unified view + full-text indexes)
--  14. Indexes
--  15. Triggers
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. EXTENSIONS & ENUMS
-- ─────────────────────────────────────────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;    -- fuzzy / trigram search
CREATE EXTENSION IF NOT EXISTS unaccent;   -- accent-insensitive search

CREATE TYPE repeat_mode         AS ENUM ('none', 'one', 'all');
CREATE TYPE stream_quality      AS ENUM ('low', 'normal', 'high', 'lossless');
CREATE TYPE playlist_visibility AS ENUM ('private', 'friends', 'public');
CREATE TYPE download_status     AS ENUM ('pending', 'downloading', 'completed', 'failed', 'deleted');
CREATE TYPE party_role          AS ENUM ('host', 'listener');
CREATE TYPE notification_type   AS ENUM ('new_release', 'listening_party', 'system', 'social');

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. CORE CATALOG
-- ─────────────────────────────────────────────────────────────────────────────

-- -----------------------------------------------------------------------------
-- artists
-- -----------------------------------------------------------------------------
CREATE TABLE artists (
    id                UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    name              TEXT        NOT NULL,
    bio               TEXT,
    image_url         TEXT,
    country           CHAR(2),                    -- ISO 3166-1 alpha-2
    verified          BOOLEAN     NOT NULL DEFAULT FALSE,
    monthly_listeners INT         NOT NULL DEFAULT 0,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    search_vector     tsvector GENERATED ALWAYS AS (
        to_tsvector('spanish', coalesce(name,'') || ' ' || coalesce(bio,''))
    ) STORED
);

-- -----------------------------------------------------------------------------
-- albums
-- -----------------------------------------------------------------------------
CREATE TABLE albums (
    id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    title           TEXT        NOT NULL,
    artist_id       UUID        NOT NULL REFERENCES artists(id) ON DELETE CASCADE,

    -- [v2] Both kept: release_date for full precision, release_year for fast
    --      lookups when the source only provides a year (like the JSON "anio")
    release_date    DATE,
    release_year    SMALLINT    GENERATED ALWAYS AS (
        EXTRACT(YEAR FROM release_date)::SMALLINT
    ) STORED,

    cover_url       TEXT,
    total_tracks    SMALLINT,
    label           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    search_vector   tsvector GENERATED ALWAYS AS (
        to_tsvector('spanish', coalesce(title,'') || ' ' || coalesce(label,''))
    ) STORED
);

-- -----------------------------------------------------------------------------
-- genres
-- -----------------------------------------------------------------------------
CREATE TABLE genres (
    id          UUID    PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        TEXT    NOT NULL UNIQUE,
    description TEXT,
    color_hex   CHAR(7),
    icon_name   TEXT
);

INSERT INTO genres (name, color_hex, icon_name) VALUES
    ('Pop',           '#F72585', 'fa-star'),
    ('Rock',          '#7B2D8B', 'fa-guitar'),
    ('Hip-Hop',       '#F4A261', 'fa-microphone'),
    ('Electronic',    '#4CC9F0', 'fa-wave-square'),
    ('Jazz',          '#E9C46A', 'fa-saxophone'),
    ('Clásica',       '#264653', 'fa-music'),
    ('Reggaeton',     '#E76F51', 'fa-fire'),
    ('R&B / Soul',    '#9B5DE5', 'fa-heart'),
    ('Lo-Fi',         '#06D6A0', 'fa-cloud'),
    ('Metal',         '#2B2D42', 'fa-skull'),
    ('Ambient',       '#80B3FF', 'fa-leaf'),
    ('Latin',         '#FF6B6B', 'fa-martini-glass'),
    ('Alternative',   '#A8DADC', 'fa-guitar');  -- added from JSON metadata

-- -----------------------------------------------------------------------------
-- songs  ← heavily updated in v2
--
-- JSON example that drives this structure:
-- {
--   "id":          "b8f5c4be-c064-4a02-8e00-7228fe171cd1.mp3",  ← file_id
--   "ruta":        "music/b8f5c4be-...mp3",                     ← file_path
--   "duracion":    222.12,                                       ← duration_s
--   "bitrate":     192000,                                       ← bitrate
--   "sample_rate": 48000,                                        ← sample_rate
--   "canales":     2,                                            ← channels
--   "metadata": {
--     "titulo":  "Selfless",      ← title
--     "artista": "The Strokes",   ← artist_id (FK after lookup/insert)
--     "album":   "The New Abnormal", ← album_id (FK)
--     "genero":  "Alternative",   ← genre via song_genres
--     "anio":    "2020"           ← release_year
--   }
-- }
-- -----------------------------------------------------------------------------
CREATE TABLE songs (
    id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- ── File identity (from YouTube ingest pipeline) ─────────────────────────
    -- The source API returns the file with extension as its ID:
    -- "id": "b8f5c4be-c064-4a02-8e00-7228fe171cd1.mp3"
    -- We store this verbatim so we can match API responses back to DB rows.
    file_id         TEXT        NOT NULL UNIQUE,  -- "{uuid}.mp3"
    file_path       TEXT        NOT NULL,          -- "music/{uuid}.mp3"  (storage bucket path)
    cdn_url         TEXT,                          -- full CDN URL once published (nullable)
    preview_url     TEXT,                          -- 30-sec clip for browse/search preview

    -- ── Metadata (from JSON "metadata" object) ───────────────────────────────
    title           TEXT        NOT NULL,
    artist_id       UUID        NOT NULL REFERENCES artists(id) ON DELETE RESTRICT,
    album_id        UUID        REFERENCES albums(id) ON DELETE SET NULL,
    track_number    SMALLINT,
    cover_url       TEXT,                          -- song-level art (overrides album art)
    release_year    SMALLINT,                      -- from "anio": "2020" — year only
    isrc            CHAR(12),
    explicit        BOOLEAN     NOT NULL DEFAULT FALSE,
    play_count      BIGINT      NOT NULL DEFAULT 0,

    -- ── Audio technical specs (from JSON root fields) ────────────────────────
    -- Duration stored in seconds as returned by the pipeline ("duracion": 222.12).
    -- Use  ROUND(duration_s * 1000)::INT  in the app for millisecond precision.
    duration_s      NUMERIC(10,2)   NOT NULL,      -- seconds  e.g. 222.12
    bitrate         INT             NOT NULL,       -- bps      e.g. 192000
    sample_rate     INT             NOT NULL,       -- Hz       e.g. 48000
    channels        SMALLINT        NOT NULL DEFAULT 2,   -- 1=mono 2=stereo

    -- ── Audio analysis (from external APIs: AcousticBrainz, etc.) ────────────
    bpm             NUMERIC(6,2),
    musical_key     VARCHAR(5),                    -- e.g. 'C#m'
    time_signature  SMALLINT        DEFAULT 4,
    energy          NUMERIC(4,3),                  -- 0.000–1.000
    valence         NUMERIC(4,3),                  -- 0.000–1.000 (musical positiveness)
    acousticness    NUMERIC(4,3),
    instrumentalness NUMERIC(4,3),
    loudness_db     NUMERIC(5,2),

    -- ── Waveform (for the visualiser — compact amplitude array 0–255) ─────────
    waveform_data   SMALLINT[],                    -- ~1000 samples per song

    -- ── Availability flags ───────────────────────────────────────────────────
    streamable      BOOLEAN     NOT NULL DEFAULT TRUE,
    downloadable    BOOLEAN     NOT NULL DEFAULT TRUE,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    search_vector   tsvector GENERATED ALWAYS AS (
        to_tsvector('spanish', coalesce(title,''))
    ) STORED
);

-- -----------------------------------------------------------------------------
-- song_genres  (many-to-many)
-- -----------------------------------------------------------------------------
CREATE TABLE song_genres (
    song_id     UUID NOT NULL REFERENCES songs(id)  ON DELETE CASCADE,
    genre_id    UUID NOT NULL REFERENCES genres(id) ON DELETE CASCADE,
    PRIMARY KEY (song_id, genre_id)
);

-- -----------------------------------------------------------------------------
-- lyrics  (time-synced, one row per line — karaoke / Belén's player feature)
-- start/end remain in milliseconds here because lyric sync is always ms-based
-- -----------------------------------------------------------------------------
CREATE TABLE lyrics (
    id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    song_id     UUID        NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
    line_index  SMALLINT    NOT NULL,
    start_ms    INT         NOT NULL,
    end_ms      INT         NOT NULL,
    text        TEXT        NOT NULL,
    language    CHAR(2)     DEFAULT 'es'
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. MOOD ENGINE
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE moods (
    id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            TEXT        NOT NULL UNIQUE,
    display_name    TEXT        NOT NULL,
    description     TEXT,
    icon_name       TEXT        NOT NULL,
    gradient_start  CHAR(7)     NOT NULL,
    gradient_end    CHAR(7)     NOT NULL,
    sort_order      SMALLINT    NOT NULL DEFAULT 0,
    energy_min      NUMERIC(4,3),
    energy_max      NUMERIC(4,3),
    valence_min     NUMERIC(4,3),
    valence_max     NUMERIC(4,3),
    bpm_min         NUMERIC(6,2),
    bpm_max         NUMERIC(6,2)
);

INSERT INTO moods (name, display_name, icon_name, gradient_start, gradient_end, sort_order,
                   energy_min, energy_max, valence_min, valence_max, bpm_min, bpm_max)
VALUES
    ('feliz',     'Feliz',    'fa-face-smile',       '#FACC15','#F97316', 1,  0.6,1.0, 0.6,1.0,  100,180),
    ('triste',    'Triste',   'fa-cloud-rain',        '#475569','#1E3A5F', 2,  0.0,0.4, 0.0,0.4,   50,100),
    ('focus',     'Focus',    'fa-headphones',        '#6366F1','#7C3AED', 3,  0.3,0.7, 0.2,0.6,   80,130),
    ('energia',   'Energía',  'fa-bolt',              '#DC2626','#18181B', 4,  0.7,1.0, 0.5,1.0,  120,200),
    ('relax',     'Relax',    'fa-leaf',              '#2DD4BF','#059669', 5,  0.0,0.4, 0.3,0.7,   50, 95),
    ('fiesta',    'Fiesta',   'fa-martini-glass',     '#EC4899','#E11D48', 6,  0.7,1.0, 0.6,1.0,  115,175),
    ('dormir',    'Dormir',   'fa-moon',              '#1C1917','#000000', 7,  0.0,0.25,0.0,0.4,   40, 80),
    ('romance',   'Romance',  'fa-heart',             '#FB7185','#EF4444', 8,  0.2,0.6, 0.4,0.8,   60,110),
    ('nostalgia', 'Nostalgia','fa-clock-rotate-left', '#92400E','#78350F', 9,  0.2,0.6, 0.3,0.7,   70,120);

-- many-to-many: song ↔ mood, with AI confidence score
CREATE TABLE song_moods (
    song_id     UUID            NOT NULL REFERENCES songs(id)  ON DELETE CASCADE,
    mood_id     UUID            NOT NULL REFERENCES moods(id)  ON DELETE CASCADE,
    score       NUMERIC(4,3)    NOT NULL DEFAULT 1.0, -- 1.0=manually tagged, <1=AI
    tagged_by   TEXT            NOT NULL DEFAULT 'system',
    PRIMARY KEY (song_id, mood_id)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. USERS & AUTH
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE users (
    id                  UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    username            TEXT        NOT NULL UNIQUE,
    email               TEXT        NOT NULL UNIQUE,
    display_name        TEXT,
    avatar_url          TEXT,
    bio                 TEXT,
    country             CHAR(2),
    preferred_language  CHAR(2)     DEFAULT 'es',
    date_of_birth       DATE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_login_at       TIMESTAMPTZ
);

-- Which mood is the user currently in (drives app theme/colours)
CREATE TABLE user_mood_sessions (
    id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    mood_id     UUID        NOT NULL REFERENCES moods(id) ON DELETE CASCADE,
    started_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at    TIMESTAMPTZ
);

-- User audio/app preferences
CREATE TABLE user_preferences (
    user_id         UUID            PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    stream_quality  stream_quality  NOT NULL DEFAULT 'normal',
    download_quality stream_quality NOT NULL DEFAULT 'high',
    eq_low          NUMERIC(5,2)   NOT NULL DEFAULT 0,  -- dB, -12 to +12
    eq_mid          NUMERIC(5,2)   NOT NULL DEFAULT 0,
    eq_high         NUMERIC(5,2)   NOT NULL DEFAULT 0,
    show_explicit   BOOLEAN        NOT NULL DEFAULT TRUE,
    autoplay        BOOLEAN        NOT NULL DEFAULT TRUE,
    crossfade_ms    INT            NOT NULL DEFAULT 0,
    updated_at      TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

-- User follows artist
CREATE TABLE followed_artists (
    user_id     UUID        NOT NULL REFERENCES users(id)   ON DELETE CASCADE,
    artist_id   UUID        NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
    followed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, artist_id)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. MONETIZATION  (from Medium article)
-- ─────────────────────────────────────────────────────────────────────────────

-- -----------------------------------------------------------------------------
-- subscription_plans  — Free / Premium / etc.
-- -----------------------------------------------------------------------------
CREATE TABLE subscription_plans (
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            TEXT            NOT NULL UNIQUE,   -- 'Free', 'Premium Mensual', …
    price_usd       NUMERIC(10,2)   NOT NULL DEFAULT 0.00,
    description     TEXT,
    features        TEXT[],         -- e.g. ARRAY['Sin anuncios','Descarga offline']
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

INSERT INTO subscription_plans (name, price_usd, description, features) VALUES
    ('Free',
     0.00,
     'Acceso básico con anuncios',
     ARRAY['Streaming básico','Calidad normal']),
    ('Premium Mensual',
     9.99,
     'Experiencia completa sin anuncios',
     ARRAY['Sin anuncios','Descarga offline','Calidad alta','DJ manual','Listening Party']),
    ('Premium Anual',
     99.99,
     'Premium con descuento anual (2 meses gratis)',
     ARRAY['Sin anuncios','Descarga offline','Calidad lossless','DJ manual','Listening Party']);

-- -----------------------------------------------------------------------------
-- user_subscriptions  — which plan a user holds right now
-- -----------------------------------------------------------------------------
CREATE TABLE user_subscriptions (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID            NOT NULL REFERENCES users(id)              ON DELETE CASCADE,
    plan_id             UUID            NOT NULL REFERENCES subscription_plans(id) ON DELETE RESTRICT,
    start_date          DATE            NOT NULL DEFAULT CURRENT_DATE,
    end_date            DATE,                           -- NULL = indefinite / cancelled
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    auto_renew          BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- Convenience view: is a given user premium right now?
CREATE VIEW user_is_premium AS
    SELECT u.id AS user_id,
           EXISTS (
               SELECT 1 FROM user_subscriptions us
               JOIN subscription_plans sp ON sp.id = us.plan_id
               WHERE us.user_id = u.id
                 AND us.is_active = TRUE
                 AND sp.price_usd > 0
                 AND (us.end_date IS NULL OR us.end_date >= CURRENT_DATE)
           ) AS is_premium
    FROM users u;

-- -----------------------------------------------------------------------------
-- payments  — full payment history (supports refunds, etc.)
-- -----------------------------------------------------------------------------
CREATE TABLE payments (
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID            NOT NULL REFERENCES users(id)              ON DELETE RESTRICT,
    subscription_id UUID            REFERENCES user_subscriptions(id)          ON DELETE SET NULL,
    amount_usd      NUMERIC(10,2)   NOT NULL,
    payment_method  TEXT            NOT NULL,    -- 'card', 'paypal', 'google_pay', …
    payment_date    TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    status          TEXT            NOT NULL DEFAULT 'completed',   -- 'pending','completed','refunded'
    external_ref    TEXT                         -- payment gateway transaction ID
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. LIBRARY  (liked_songs + downloads)
-- ─────────────────────────────────────────────────────────────────────────────

-- Favoritos / Me gustan  (Feature #4 — Fabi)
CREATE TABLE liked_songs (
    user_id     UUID        NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    song_id     UUID        NOT NULL REFERENCES songs(id)  ON DELETE CASCADE,
    liked_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, song_id)
);

-- Downloads for offline playback  (Feature #2 — Fernando)
CREATE TABLE downloads (
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID            NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    song_id         UUID            NOT NULL REFERENCES songs(id)  ON DELETE CASCADE,
    quality         stream_quality  NOT NULL DEFAULT 'high',
    file_size_bytes BIGINT,
    local_path      TEXT,           -- on-device path (returned by flutter_downloader)
    status          download_status NOT NULL DEFAULT 'pending',
    downloaded_at   TIMESTAMPTZ,
    expires_at      TIMESTAMPTZ,    -- licence expiry for premium downloads
    UNIQUE (user_id, song_id)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. PLAYLISTS  (Feature #3 — Andrés)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE playlists (
    id                UUID                PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id          UUID                NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name              TEXT                NOT NULL,
    description       TEXT,
    cover_url         TEXT,
    visibility        playlist_visibility NOT NULL DEFAULT 'private',
    is_mood_based     BOOLEAN             NOT NULL DEFAULT FALSE,
    mood_id           UUID                REFERENCES moods(id) ON DELETE SET NULL,
    gradient_start    CHAR(7),
    gradient_end      CHAR(7),
    icon_name         TEXT,
    total_songs       INT                 NOT NULL DEFAULT 0,   -- denormalised; kept by trigger
    total_duration_s  NUMERIC(12,2)       NOT NULL DEFAULT 0,  -- [v2] seconds (was duration_ms)
    created_at        TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ         NOT NULL DEFAULT NOW(),

    search_vector     tsvector GENERATED ALWAYS AS (
        to_tsvector('spanish', coalesce(name,'') || ' ' || coalesce(description,''))
    ) STORED
);

-- Drag-and-drop position stored as `position` (1-based, unique within playlist)
CREATE TABLE playlist_songs (
    id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    playlist_id UUID        NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
    song_id     UUID        NOT NULL REFERENCES songs(id)     ON DELETE CASCADE,
    position    INT         NOT NULL,
    added_by    UUID        REFERENCES users(id) ON DELETE SET NULL,
    added_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (playlist_id, song_id),
    UNIQUE (playlist_id, position)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. PLAYER  (Feature #5 — Belén)  +  Timeline (Idea #3)
-- ─────────────────────────────────────────────────────────────────────────────

-- Live queue for the current session
CREATE TABLE user_queue (
    id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID        NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    song_id     UUID        NOT NULL REFERENCES songs(id)  ON DELETE CASCADE,
    position    INT         NOT NULL,
    source_type TEXT,                   -- 'playlist','album','mood','search','dj','party'
    source_id   UUID,
    added_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, position)
);

-- Persisted player state — app restores from here on relaunch
-- [v2] position_s stored in seconds (matches duration_s in songs)
CREATE TABLE player_state (
    user_id         UUID        PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    current_song_id UUID        REFERENCES songs(id) ON DELETE SET NULL,
    position_s      NUMERIC(10,2) NOT NULL DEFAULT 0,   -- playback cursor in seconds
    repeat          repeat_mode NOT NULL DEFAULT 'none',
    shuffle         BOOLEAN     NOT NULL DEFAULT FALSE,
    volume          NUMERIC(4,3) NOT NULL DEFAULT 1.0,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Listening history — drives the music timeline (Idea #3)
-- Partitioned by month so weekly/monthly queries hit only one shard.
-- [v2] duration_s in seconds to stay consistent with songs table
CREATE TABLE listening_history (
    id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID        NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    song_id     UUID        NOT NULL REFERENCES songs(id)  ON DELETE CASCADE,
    listened_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    duration_s  NUMERIC(10,2) NOT NULL,              -- how long the user actually listened
    completed   BOOLEAN     NOT NULL DEFAULT FALSE,   -- TRUE if ≥80% played
    source_type TEXT,
    mood_id     UUID        REFERENCES moods(id) ON DELETE SET NULL,
    CHECK (duration_s >= 0)
) PARTITION BY RANGE (listened_at);

-- Monthly partitions — add a new one each month via a cron job / migration
DO $$
DECLARE
  y INT;
  m INT;
  start_d DATE;
  end_d   DATE;
BEGIN
  FOR y IN 2025..2027 LOOP
    FOR m IN 1..12 LOOP
      start_d := make_date(y, m, 1);
      end_d   := start_d + INTERVAL '1 month';
      EXECUTE format(
        'CREATE TABLE IF NOT EXISTS listening_history_%s_%s
         PARTITION OF listening_history
         FOR VALUES FROM (%L) TO (%L)',
        y, lpad(m::text, 2, '0'), start_d, end_d
      );
    END LOOP;
  END LOOP;
END
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. RECOMMENDATIONS  (from Medium article — collaborative filtering)
-- ─────────────────────────────────────────────────────────────────────────────

-- Pre-computed similarity scores between a user and every song.
-- A background job (Python / scheduled function) recomputes these nightly
-- using collaborative filtering on listening_history.
--
-- Query pattern:
--   SELECT song_id FROM similarity
--   WHERE user_id = $1 ORDER BY score DESC LIMIT 20;
CREATE TABLE similarity (
    user_id     UUID            NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    song_id     UUID            NOT NULL REFERENCES songs(id)  ON DELETE CASCADE,
    score       FLOAT           NOT NULL,           -- collaborative filtering score
    computed_at TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, song_id)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 10. SOCIAL — Listening Parties  (Idea #4)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE listening_parties (
    id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    host_id         UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name            TEXT        NOT NULL DEFAULT 'Mi Listening Party',
    invite_code     TEXT        NOT NULL UNIQUE DEFAULT upper(left(gen_random_uuid()::text,8)),
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
    current_song_id UUID        REFERENCES songs(id) ON DELETE SET NULL,
    position_s      NUMERIC(10,2) NOT NULL DEFAULT 0,  -- [v2] synced cursor in seconds
    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at        TIMESTAMPTZ
);

CREATE TABLE party_members (
    id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    party_id    UUID        NOT NULL REFERENCES listening_parties(id) ON DELETE CASCADE,
    user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role        party_role  NOT NULL DEFAULT 'listener',
    joined_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    left_at     TIMESTAMPTZ,
    UNIQUE (party_id, user_id)
);

CREATE TABLE party_chat (
    id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    party_id    UUID        NOT NULL REFERENCES listening_parties(id) ON DELETE CASCADE,
    user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message     TEXT        NOT NULL,
    reaction    TEXT,
    sent_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE party_queue (
    id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    party_id        UUID        NOT NULL REFERENCES listening_parties(id) ON DELETE CASCADE,
    song_id         UUID        NOT NULL REFERENCES songs(id)             ON DELETE CASCADE,
    requested_by    UUID        REFERENCES users(id) ON DELETE SET NULL,
    position        INT         NOT NULL,
    played          BOOLEAN     NOT NULL DEFAULT FALSE,
    added_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (party_id, position)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 11. DJ MODE  (Idea #5)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE dj_sessions (
    id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name            TEXT        NOT NULL DEFAULT 'Mi Set',
    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at        TIMESTAMPTZ,
    is_saved        BOOLEAN     NOT NULL DEFAULT FALSE,
    recording_url   TEXT
);

CREATE TABLE dj_tracks (
    id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id      UUID        NOT NULL REFERENCES dj_sessions(id) ON DELETE CASCADE,
    song_id         UUID        NOT NULL REFERENCES songs(id)        ON DELETE CASCADE,
    deck            CHAR(1)     NOT NULL CHECK (deck IN ('A','B')),
    position        INT         NOT NULL,

    -- Tempo control (Idea 5.iii/iv)
    original_bpm    NUMERIC(6,2),                -- from songs.bpm
    adjusted_bpm    NUMERIC(6,2),                -- user-dialled target BPM

    -- EQ knobs in dB  (-12 to +12)
    eq_low          NUMERIC(5,2)    NOT NULL DEFAULT 0,
    eq_mid          NUMERIC(5,2)    NOT NULL DEFAULT 0,
    eq_high         NUMERIC(5,2)    NOT NULL DEFAULT 0,

    -- Mixer
    volume          NUMERIC(4,3)    NOT NULL DEFAULT 1.0,
    crossfader_pos  NUMERIC(4,3)    NOT NULL DEFAULT 0.5,
    filter_enabled  BOOLEAN         NOT NULL DEFAULT FALSE,  -- Idea 5.i

    -- Cue / loop points in milliseconds (player-precision timing for DJ mode)
    cue_in_ms       INT,
    cue_out_ms      INT,
    loop_start_ms   INT,
    loop_end_ms     INT,

    played_at       TIMESTAMPTZ,
    added_at        TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 12. NOTIFICATIONS  (from Medium article)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE notifications (
    id          UUID                PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID                NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type        notification_type   NOT NULL DEFAULT 'system',
    title       TEXT                NOT NULL,
    content     TEXT                NOT NULL,
    is_read     BOOLEAN             NOT NULL DEFAULT FALSE,
    deep_link   TEXT,               -- e.g. "app://party/abc123" or "app://song/uuid"
    created_at  TIMESTAMPTZ         NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 13. SEARCH SUPPORT  (Feature #2 — Fernando)
-- ─────────────────────────────────────────────────────────────────────────────

-- Universal search view — one query covers songs, artists, albums, playlists
CREATE VIEW search_index AS
    SELECT 'song'    AS entity_type, s.id AS entity_id,
           s.title   AS primary_text, a.name AS secondary_text,
           s.cover_url AS image_url,  s.play_count AS popularity,
           s.search_vector AS sv
    FROM songs s JOIN artists a ON a.id = s.artist_id
    WHERE s.streamable = TRUE

    UNION ALL

    SELECT 'artist', a.id, a.name, NULL, a.image_url,
           a.monthly_listeners, a.search_vector
    FROM artists a

    UNION ALL

    SELECT 'album', al.id, al.title, a.name, al.cover_url, 0, al.search_vector
    FROM albums al JOIN artists a ON a.id = al.artist_id

    UNION ALL

    SELECT 'playlist', p.id, p.name, u.display_name, p.cover_url,
           p.total_songs, p.search_vector
    FROM playlists p JOIN users u ON u.id = p.owner_id
    WHERE p.visibility = 'public';

-- ─────────────────────────────────────────────────────────────────────────────
-- 14. INDEXES
-- ─────────────────────────────────────────────────────────────────────────────

-- Full-text (GIN)
CREATE INDEX idx_songs_search     ON songs     USING GIN (search_vector);
CREATE INDEX idx_artists_search   ON artists   USING GIN (search_vector);
CREATE INDEX idx_albums_search    ON albums    USING GIN (search_vector);
CREATE INDEX idx_playlists_search ON playlists USING GIN (search_vector);

-- Trigram fuzzy search
CREATE INDEX idx_songs_title_trgm    ON songs     USING GIN (title    gin_trgm_ops);
CREATE INDEX idx_artists_name_trgm   ON artists   USING GIN (name     gin_trgm_ops);
CREATE INDEX idx_albums_title_trgm   ON albums    USING GIN (title    gin_trgm_ops);
CREATE INDEX idx_playlists_name_trgm ON playlists USING GIN (name     gin_trgm_ops);

-- Catalog lookups
CREATE INDEX idx_songs_artist           ON songs           (artist_id);
CREATE INDEX idx_songs_album            ON songs           (album_id);
CREATE INDEX idx_songs_file_id          ON songs           (file_id);        -- [v2] file lookup
CREATE INDEX idx_albums_artist          ON albums          (artist_id);
CREATE INDEX idx_song_genres_genre      ON song_genres     (genre_id);
CREATE INDEX idx_song_moods_mood        ON song_moods      (mood_id);
CREATE INDEX idx_playlist_songs_pl      ON playlist_songs  (playlist_id, position);
CREATE INDEX idx_liked_songs_user       ON liked_songs     (user_id, liked_at DESC);
CREATE INDEX idx_downloads_user         ON downloads       (user_id, status);
CREATE INDEX idx_queue_user             ON user_queue      (user_id, position);

-- Listening history (partitioned — local index on each shard)
CREATE INDEX idx_lh_user_time           ON listening_history (user_id, listened_at DESC);
CREATE INDEX idx_lh_mood                ON listening_history (mood_id,  listened_at DESC);

-- Recommendations
CREATE INDEX idx_similarity_user        ON similarity      (user_id, score DESC);

-- DJ
CREATE INDEX idx_dj_tracks_session      ON dj_tracks       (session_id, position);
CREATE INDEX idx_dj_sessions_user       ON dj_sessions     (user_id, started_at DESC);

-- Mood sessions
CREATE INDEX idx_mood_sessions_user     ON user_mood_sessions (user_id, started_at DESC);

-- Social
CREATE INDEX idx_party_members_party    ON party_members   (party_id);
CREATE INDEX idx_party_chat_party       ON party_chat      (party_id, sent_at DESC);

-- Notifications
CREATE INDEX idx_notifications_user     ON notifications   (user_id, is_read, created_at DESC);

-- Subscriptions
CREATE INDEX idx_subscriptions_user     ON user_subscriptions (user_id, is_active);

-- ─────────────────────────────────────────────────────────────────────────────
-- 15. TRIGGERS
-- ─────────────────────────────────────────────────────────────────────────────

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$;

CREATE TRIGGER trg_songs_updated_at     BEFORE UPDATE ON songs     FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_artists_updated_at   BEFORE UPDATE ON artists   FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_albums_updated_at    BEFORE UPDATE ON albums    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_playlists_updated_at BEFORE UPDATE ON playlists FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_users_updated_at     BEFORE UPDATE ON users     FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Keep playlist total_songs and total_duration_s accurate
-- [v2] sums duration_s instead of duration_ms
CREATE OR REPLACE FUNCTION update_playlist_stats()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_pid UUID;
BEGIN
    IF TG_OP = 'DELETE' THEN v_pid := OLD.playlist_id;
    ELSE v_pid := NEW.playlist_id; END IF;

    UPDATE playlists SET
        total_songs      = (SELECT COUNT(*)
                            FROM playlist_songs ps WHERE ps.playlist_id = v_pid),
        total_duration_s = (SELECT COALESCE(SUM(s.duration_s), 0)
                            FROM playlist_songs ps
                            JOIN songs s ON s.id = ps.song_id
                            WHERE ps.playlist_id = v_pid)
    WHERE id = v_pid;
    RETURN NULL;
END; $$;

CREATE TRIGGER trg_playlist_songs_stats
AFTER INSERT OR UPDATE OR DELETE ON playlist_songs
FOR EACH ROW EXECUTE FUNCTION update_playlist_stats();

-- Increment play_count on completed listens
CREATE OR REPLACE FUNCTION increment_play_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.completed THEN
        UPDATE songs SET play_count = play_count + 1 WHERE id = NEW.song_id;
    END IF;
    RETURN NULL;
END; $$;

CREATE TRIGGER trg_lh_play_count
AFTER INSERT ON listening_history
FOR EACH ROW EXECUTE FUNCTION increment_play_count();

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- 1. Insert a song from the YouTube ingest pipeline JSON
INSERT INTO songs (
    file_id, file_path, title, artist_id, album_id,
    release_year, duration_s, bitrate, sample_rate, channels
) VALUES (
    'b8f5c4be-c064-4a02-8e00-7228fe171cd1.mp3',      -- file_id  (JSON "id")
    'music/b8f5c4be-c064-4a02-8e00-7228fe171cd1.mp3', -- file_path (JSON "ruta")
    'Selfless',                                        -- JSON metadata.titulo
    '<artist_uuid>',                                   -- looked up by metadata.artista
    '<album_uuid>',                                    -- looked up by metadata.album
    2020,                                              -- JSON metadata.anio
    222.12,                                            -- JSON "duracion"
    192000,                                            -- JSON "bitrate"
    48000,                                             -- JSON "sample_rate"
    2                                                  -- JSON "canales"
);

-- 2. Universal search (one query for songs + artists + albums + playlists)
SELECT entity_type, entity_id, primary_text, secondary_text, image_url
FROM search_index
WHERE sv @@ plainto_tsquery('spanish', 'strokes')
   OR primary_text ILIKE '%strokes%'
ORDER BY ts_rank(sv, plainto_tsquery('spanish', 'strokes')) DESC,
         popularity DESC
LIMIT 20;

-- 3. Personalised recommendations for a user based on similarity scores
SELECT s.id, s.title, a.name AS artist, sim.score
FROM similarity sim
JOIN songs s   ON s.id = sim.song_id
JOIN artists a ON a.id = s.artist_id
WHERE sim.user_id = '<user_uuid>'
  AND s.id NOT IN (SELECT song_id FROM liked_songs WHERE user_id = '<user_uuid>')
ORDER BY sim.score DESC
LIMIT 20;

-- 4. Top songs for a given mood
SELECT s.id, s.title, a.name AS artist, sm.score
FROM song_moods sm
JOIN moods m   ON m.id = sm.mood_id AND m.name = 'focus'
JOIN songs s   ON s.id = sm.song_id
JOIN artists a ON a.id = s.artist_id
ORDER BY sm.score DESC, s.play_count DESC
LIMIT 50;

-- 5. Listening timeline — minutes per day in April 2026
SELECT date_trunc('day', listened_at) AS day,
       COUNT(*)                        AS songs_played,
       SUM(duration_s) / 60.0         AS minutes_listened
FROM listening_history
WHERE user_id    = '<user_uuid>'
  AND listened_at BETWEEN '2026-04-01' AND '2026-05-01'
GROUP BY 1
ORDER BY 1;

-- 6. Check if user is premium
SELECT is_premium FROM user_is_premium WHERE user_id = '<user_uuid>';

-- 7. DJ session — song list with BPM for the tempo slider
SELECT s.title, a.name AS artist, s.bpm AS original_bpm,
       dt.adjusted_bpm, dt.eq_low, dt.eq_mid, dt.eq_high
FROM dj_tracks dt
JOIN songs   s ON s.id = dt.song_id
JOIN artists a ON a.id = s.artist_id
WHERE dt.session_id = '<session_uuid>'
ORDER BY dt.position;
*/
