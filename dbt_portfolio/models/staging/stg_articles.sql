{{ config(materialized='view') }}

with source as (
    select * from {{ source('global_voices', 'articles_raw') }}
),

deduped as (
    select
        *,
        row_number() over (partition by guid order by pulled_at desc) as rn
    from source
)

select
    guid,
    title,
    link,
    author,
    pub_date,
    -- Extracts the article slug from URL structure (e.g. globalvoices.org/YYYY/MM/DD/slug/)
    replace(
        regexp_extract(link, r'https?://[^/]+/\d{4}/\d{2}/\d{2}/([^/]+)/?'),
        '-', ' '
    ) as article_slug,
    -- Cleans category tags array by stripping trailing/leading whitespace
    array(
        select trim(cat)
        from unnest(categories) as cat
        where cat is not null and trim(cat) != ''
    ) as tags,
    description,
    content_html,
    pulled_at as last_seen_at,
    -- Standardized CC-BY 3.0 attribution for downstream charts & dashboards
    'Original content from Global Voices (https://globalvoices.org), published under CC BY 3.0.' as source_attribution
from deduped
where rn = 1