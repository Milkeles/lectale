-- v4 catalogue: opt-in public-safe snapshots. Does not store private course files.
-- These migrations build upon 0001/0002/0003.
PRAGMA foreign_keys = ON;
ALTER TABLE courses ADD COLUMN catalog_listing TEXT NOT NULL DEFAULT 'unlisted' CHECK(catalog_listing IN ('unlisted', 'listed'));
ALTER TABLE courses ADD COLUMN catalog_title TEXT;
ALTER TABLE courses ADD COLUMN catalog_summary TEXT;
ALTER TABLE courses ADD COLUMN catalog_language TEXT;
ALTER TABLE courses ADD COLUMN catalog_category TEXT;
ALTER TABLE courses ADD COLUMN catalog_tags_json TEXT NOT NULL DEFAULT '[]';
ALTER TABLE courses ADD COLUMN catalog_cover_url TEXT;
ALTER TABLE courses ADD COLUMN catalog_sort_at TEXT;
ALTER TABLE courses ADD COLUMN catalog_revision INTEGER NOT NULL DEFAULT 0 CHECK(catalog_revision >= 0);
ALTER TABLE courses ADD COLUMN catalog_updated_at TEXT;
CREATE INDEX IF NOT EXISTS idx_catalog_listing_recent ON courses(catalog_listing, status, catalog_sort_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS idx_catalog_listing_language ON courses(catalog_listing, status, catalog_language, catalog_sort_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS idx_catalog_listing_category ON courses(catalog_listing, status, catalog_category, catalog_sort_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS idx_catalog_listing_commerce ON courses(catalog_listing, status, commerce_mode, catalog_sort_at DESC, id DESC);
CREATE TABLE catalog_search_terms (
 course_id TEXT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
 term TEXT NOT NULL CHECK(length(term) BETWEEN 2 AND 48),
 PRIMARY KEY (course_id,term)
);
CREATE INDEX IF NOT EXISTS idx_catalog_search_terms_term ON catalog_search_terms(term,course_id);
-- This table contains only public-safe normalized token strings, not private README text.
-- For listing write and search-term updates use an atomic D1 batch/transaction supported by the app runtime.
