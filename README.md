# Global Voices Dashboard — Ingestion

Public portfolio data pipeline that pulls the CC BY 3.0 licensed RSS feed from
`https://globalvoices.org/feed/` into BigQuery on a 6-hour schedule. This serves as the
raw landing layer for a dbt + Quarto dashboard.

This README covers only the **ingestion** piece (step 1 — dbt models
and the dashboard come later).

## What this does

1. `ingestion/fetch_feed.py` fetches the RSS feed, parses each `<item>`, and
   appends the rows to a BigQuery table (`global_voices_raw.articles_raw` in the
   `portfolio-hub-464520` project).
2. `.github/workflows/ingest_feed.yml` runs that script every 6 hours via
   GitHub Actions.
3. No deduplication happens here on purpose — this is a raw append-only
   landing table. The same article will appear in multiple pulls. Deduplication
   and tag extraction happen downstream in dbt staging models.

## One-time setup

### 1. Google Cloud

- Create (or reuse) a GCP project. Note its **project ID**.
- Enable the BigQuery API for that project.
- Create a service account with these roles:
  - `BigQuery Data Editor` (create/write tables)
  - `BigQuery Job User` (run load jobs)
- Create a JSON key for that service account and download it.

You don't need to pre-create the dataset or table — the Python script creates both
on its first run if they don't exist.

### 2. GitHub repo secrets

In the repo's **Settings → Secrets and variables → Actions**, add:

| Secret name        | Value                                             |
|--------------------|---------------------------------------------------|
| `GCP_PROJECT_ID`   | `portfolio-hub-464520`                            |
| `GCP_SA_KEY_JSON`  | the full contents of the service account JSON key |

### 3. Test it

- Go to the **Actions** tab → "Ingest Global Voices RSS feed" → **Run workflow**
  (this uses the `workflow_dispatch` trigger, so you don't have to wait for
  the cron schedule to test it).
- Check the run logs, then check BigQuery — you should see a new
  `global_voices_raw.articles_raw` table with the latest feed items.

After that, it runs automatically every 6 hours to capture the continuous publishing schedule of Global Voices.

## Local development / manual run

```bash
cd ingestion
pip install -r requirements.txt

export GCP_PROJECT_ID="portfolio-hub-464520"
export GCP_SA_KEY_JSON="$(cat /path/to/your-key.json)"
export BQ_DATASET="global_voices_raw"
export BQ_LOCATION="EU"
# optional overrides:
# export BQ_TABLE="articles_raw"


python fetch_feed.py
