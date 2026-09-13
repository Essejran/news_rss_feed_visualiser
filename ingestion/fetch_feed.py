"""
Fetch the Global Voices RSS feed and append it as a raw snapshot into BigQuery.

Design notes:
- This is a *landing* step only: no deduplication, no transformation. Every
  run appends whatever the feed currently contains, tagged with the UTC time
  of the pull (`pulled_at`). The same article will appear in multiple pulls
  while it's still in the feed's ~20-item window — that's expected and by
  design. Dedup (keep latest pull per `guid`, or first-seen, etc.) belongs in
  a dbt staging model that reads this raw table, not here.
- Uses a BigQuery *load job* (not streaming inserts) so this stays inside the
  free tier cleanly and avoids streaming-buffer quirks (e.g. rows being
  briefly unqueryable / not immediately updatable).
- Table is time-partitioned on `pulled_at` so cost/scan stays cheap even as
  history accumulates.
"""

import json
import os
import sys
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from xml.etree import ElementTree as ET

import requests
from google.cloud import bigquery
from google.oauth2 import service_account

FEED_URL = "https://globalvoices.org/feed/"

NS = {
    "content": "http://purl.org/rss/1.0/modules/content/",
    "dc": "http://purl.org/dc/elements/1.1/",
}

RAW_SCHEMA = [
    bigquery.SchemaField("guid", "STRING"),
    bigquery.SchemaField("title", "STRING"),
    bigquery.SchemaField("link", "STRING"),
    bigquery.SchemaField("author", "STRING"),
    bigquery.SchemaField("pub_date_raw", "STRING"),
    bigquery.SchemaField("pub_date", "TIMESTAMP"),
    bigquery.SchemaField("categories", "STRING", mode="REPEATED"),
    bigquery.SchemaField("description", "STRING"),
    bigquery.SchemaField("content_html", "STRING"),
    bigquery.SchemaField("pulled_at", "TIMESTAMP"),
]


def fetch_feed_xml() -> str:
    resp = requests.get(
        FEED_URL,
        timeout=30,
        headers={
            # Identify the bot honestly and give a way to reach you.
            "User-Agent": "personal-global-voices-dashboard/0.1 (+github.com/Essejran/news_rss_feed_visualiser)"
        },
    )
    resp.raise_for_status()
    return resp.text


def parse_pub_date(raw: str | None) -> str | None:
    if not raw:
        return None
    try:
        return parsedate_to_datetime(raw).astimezone(timezone.utc).isoformat()
    except Exception:
        return None


def parse_items(xml_text: str, pulled_at: str) -> list[dict]:
    root = ET.fromstring(xml_text)
    channel = root.find("channel")
    if channel is None:
        return []

    items = []
    for item in channel.findall("item"):
        guid_el = item.find("guid")
        pub_date_raw = item.findtext("pubDate")
        creator_el = item.find("dc:creator", NS)
        content_el = item.find("content:encoded", NS)
        categories = [c.text for c in item.findall("category") if c.text]

        items.append(
            {
                "guid": guid_el.text if guid_el is not None else None,
                "title": (item.findtext("title") or "").strip(),
                "link": (item.findtext("link") or "").strip(),
                "author": creator_el.text if creator_el is not None else None,
                "pub_date_raw": pub_date_raw,
                "pub_date": parse_pub_date(pub_date_raw),
                "categories": categories,
                "description": (item.findtext("description") or "").strip(),
                "content_html": content_el.text if content_el is not None else "",
                "pulled_at": pulled_at,
            }
        )
    return items


def get_bq_client(project_id: str) -> bigquery.Client:
    key_json = os.environ["GCP_SA_KEY_JSON"]
    info = json.loads(key_json)
    creds = service_account.Credentials.from_service_account_info(info)
    return bigquery.Client(project=project_id, credentials=creds)


def ensure_dataset(client: bigquery.Client, project_id: str, dataset: str, location: str):
    dataset_id = f"{project_id}.{dataset}"
    try:
        client.get_dataset(dataset_id)
    except Exception:
        ds = bigquery.Dataset(dataset_id)
        ds.location = location
        client.create_dataset(ds)
        print(f"Created dataset {dataset_id}")


def ensure_table(client: bigquery.Client, project_id: str, dataset: str, table: str):
    table_id = f"{project_id}.{dataset}.{table}"
    try:
        client.get_table(table_id)
    except Exception:
        bq_table = bigquery.Table(table_id, schema=RAW_SCHEMA)
        bq_table.time_partitioning = bigquery.TimePartitioning(field="pulled_at")
        client.create_table(bq_table)
        print(f"Created table {table_id}")


def load_rows(client: bigquery.Client, project_id: str, dataset: str, table: str, rows: list[dict]):
    table_id = f"{project_id}.{dataset}.{table}"
    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
        schema=RAW_SCHEMA,
    )
    job = client.load_table_from_json(rows, table_id, job_config=job_config)
    job.result()  # wait for completion, raises on failure
    print(f"Loaded {len(rows)} rows into {table_id}")


def main():
    project_id = os.environ["GCP_PROJECT_ID"]
    dataset = os.environ.get("BQ_DATASET", "global_voices_raw")
    table = os.environ.get("BQ_TABLE", "articles_raw")
    location = os.environ.get("BQ_LOCATION", "EU")

    pulled_at = datetime.now(timezone.utc).isoformat()

    print(f"Fetching {FEED_URL} ...")
    xml_text = fetch_feed_xml()

    items = parse_items(xml_text, pulled_at)
    print(f"Parsed {len(items)} items from feed")

    if not items:
        print("No items parsed from feed - aborting without writing to BigQuery.")
        sys.exit(1)

    client = get_bq_client(project_id)
    ensure_dataset(client, project_id, dataset, location)
    ensure_table(client, project_id, dataset, table)
    load_rows(client, project_id, dataset, table, items)


if __name__ == "__main__":
    main()
