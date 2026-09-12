-- Reference only: fetch_feed.py creates this table automatically on first
-- run if it doesn't exist. This file documents the schema for anyone
-- reading the repo (and for writing dbt sources/staging models against).

CREATE TABLE IF NOT EXISTS `portfolio-hub-464520.tso_feed.articles_raw`
(
  guid          STRING,
  title         STRING,
  link          STRING,
  author        STRING,      -- original source, e.g. "SANA", "ULTRA SYRIA"
  pub_date_raw  STRING,       -- original RFC-822 string from the feed
  pub_date      TIMESTAMP,    -- parsed to UTC
  categories    ARRAY<STRING>,-- mix of section (e.g. "Foreign actors") and entity tags
  description   STRING,       -- short excerpt
  content_html  STRING,       -- full article body, HTML
  pulled_at     TIMESTAMP     -- when this snapshot was fetched
)
PARTITION BY DATE(pulled_at);

-- Notes for downstream (dbt) modeling:
--   * This table is append-only / raw landing. The same `guid` will appear
--     in many rows across different `pulled_at` snapshots while it's still
--     in the feed's rolling window (~20 items). Do NOT treat a row here as
--     a unique article.
--   * A staging model should dedupe per `guid`, e.g. keep the row with the
--     max `pulled_at` (freshest scrape of that article) or min `pulled_at`
--     (first time it was seen) depending on what you want to measure.
--   * `categories` mixes two different kinds of tags (section names like
--     "Society" vs. entity names like "Turkey") with no field to tell them
--     apart programmatically — that split will need to happen in dbt,
--     likely via a maintained lookup/seed list of known section names.
