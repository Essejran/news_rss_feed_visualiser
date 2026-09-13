-- Reference only: fetch_feed.py creates this table automatically on first
-- run if it doesn't exist. This file documents the schema for anyone
-- reading the repo (and for writing dbt sources/staging models against).

CREATE TABLE IF NOT EXISTS `portfolio-hub-464520.global_voices_raw.articles_raw`
(
  guid          STRING,
  title         STRING,
  link          STRING,
  author        STRING,      -- original source author
  pub_date_raw  STRING,      -- original RFC-822 string from the feed
  pub_date      TIMESTAMP,   -- parsed to UTC
  categories    ARRAY<STRING>,-- array containing region and topic tags
  description   STRING,      -- short excerpt
  content_html  STRING,      -- full article body, HTML
  pulled_at     TIMESTAMP    -- when this snapshot was fetched
)
PARTITION BY DATE(pulled_at);

-- Notes for downstream (dbt) modeling:
--   * This table is append-only / raw landing. The same `guid` will appear
--     in many rows across different `pulled_at` snapshots while it's still
--     in the feed's rolling window. Do NOT treat a row here as
--     a unique article.
--   * A staging model should dedupe per `guid`, keeping the row with the
--     max `pulled_at` (freshest scrape) or min `pulled_at` (first seen).
--   * `categories` contains an array of strings that must be flattened using
--     UNNEST() in downstream models to count overlapping topic tags.
--   * Original data is licensed under CC BY 3.0 by Global Voices.
