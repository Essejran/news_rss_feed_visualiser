{{ config(materialized='view') }}

with source as (
    select * from {{ source('tso_feed', 'articles_raw') }}
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
    initcap(replace(
        regexp_extract(link, r'https?://[^/]+/([^/]+)/'),
        '-', ' '
    )) as main_category,
    categories as tags,
    description,
    content_html,
    pulled_at as last_seen_at
from deduped
where rn = 1