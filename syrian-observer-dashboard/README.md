# Syrian Observer Dashboard — Ingestion

Personal, private-use data pipeline that pulls the public RSS feed from
`https://syrianobserver.com/feed` into BigQuery on a daily schedule, as the
raw landing layer for a dbt + Looker Studio dashboard.

This README covers only the **ingestion** piece (this is step 1 — dbt models
and the dashboard come later).

## What this does

1. `ingestion/fetch_feed.py` fetches the RSS feed, parses each `<item>`, and
   appends the rows to a BigQuery table (`tso_feed.articles_raw` in the
   `portfolio-hub-464520` project).
2. `.github/workflows/ingest_feed.yml` runs that script once a day via
   GitHub Actions.
3. No deduplication happens here on purpose — this is a raw append-only
   landing table. See `sql/raw/create_raw_articles_table.sql` for schema
   notes and what downstream (dbt) modeling needs to account for.

## One-time setup

### 1. Google Cloud

- Create (or reuse) a GCP project. Note its **project ID**.
- Enable the BigQuery API for that project.
- Create a service account with these roles:
  - `BigQuery Data Editor` (create/write tables)
  - `BigQuery Job User` (run load jobs)
- Create a JSON key for that service account and download it.

You don't need to pre-create the dataset or table — the script creates both
on first run if they don't exist.

### 2. GitHub repo secrets

In the repo's **Settings → Secrets and variables → Actions**, add:

| Secret name        | Value                                            |
|---------------------|---------------------------------------------------|
| `GCP_PROJECT_ID`    | `portfolio-hub-464520`                             |
| `GCP_SA_KEY_JSON`   | the full contents of the service account JSON key  |

### 3. Test it

- Go to the **Actions** tab → "Ingest Syrian Observer RSS feed" → **Run workflow**
  (this uses the `workflow_dispatch` trigger, so you don't have to wait for
  the daily cron to test it).
- Check the run logs, then check BigQuery — you should see a new
  `tso_feed.articles_raw` table with ~20 rows.

After that, it runs automatically once a day (03:00 UTC by default — the
feed appears to batch-publish most articles around 21:00 UTC, so this leaves
a buffer; adjust the cron in the workflow file if you want a different time).

## Local development / manual run

```bash
cd ingestion
pip install -r requirements.txt

export GCP_PROJECT_ID="portfolio-hub-464520"
export GCP_SA_KEY_JSON="$(cat /path/to/your-key.json)"
export BQ_DATASET="tso_feed"
# optional overrides:
# export BQ_TABLE="articles_raw"
# export BQ_LOCATION="US"

python fetch_feed.py
```

## Notes / known limitations

- The feed only exposes the most recent ~20 items, so meaningful trend data
  will take days/weeks of accumulated daily pulls — a single run is only
  useful for standing up and testing the schema/models, not for real
  analysis yet.
- `categories` in the feed mixes section names (e.g. "Society") and entity
  tags (e.g. "Turkey") with no way to distinguish them from the field alone.
  That split needs to happen downstream, likely via a small maintained list
  of known section names.
- This pulls directly from the site's own public RSS feed (its built-in
  syndication mechanism), for personal/private use only — not scraping
  rendered HTML pages. See project notes for the underlying permissions
  conversation with the site owner.
