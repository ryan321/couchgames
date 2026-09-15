CREATE TABLE library_lock (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    token INTEGER NOT NULL DEFAULT 0
);
INSERT INTO library_lock (id) VALUES (1);

CREATE TABLE installed_releases (
    game_id TEXT NOT NULL,
    release_id TEXT NOT NULL,
    target TEXT NOT NULL,
    title TEXT NOT NULL,
    version TEXT NOT NULL,
    runtime TEXT NOT NULL,
    manifest_hash TEXT NOT NULL,
    relative_path TEXT NOT NULL,
    active INTEGER NOT NULL CHECK (active IN (0, 1)),
    installed_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    PRIMARY KEY (game_id, release_id, target)
);
CREATE UNIQUE INDEX one_active_release
ON installed_releases (game_id, target) WHERE active = 1;
