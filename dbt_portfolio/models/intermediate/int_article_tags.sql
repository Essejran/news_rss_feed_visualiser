{{ config(materialized='view') }}

-- Global Voices flattens region, country, topic, format, and language into one
-- undifferentiated `categories` array per article (e.g. a single Haiti story
-- is tagged Caribbean, Haiti, English, Feature, Weblog, History, Law,
-- Politics, Protest, Youth all at once). This model classifies each tag
-- against the `gv_taxonomy` seed (scraped from globalvoices.org/feeds/) so
-- downstream marts can slice by dimension instead of treating them as one
-- noisy bag of tags. Tags with no match (rare cross-posted language names,
-- one-off site tags like "WORLD") are kept, not dropped, under 'other'.

with unnested as (
    select
        guid,
        pub_date,
        tag
    from {{ ref('stg_articles') }},
    unnest(tags) as tag
)

select
    u.guid,
    u.pub_date,
    u.tag,
    coalesce(t.category_type, 'other') as category_type,
    t.region
from unnested u
left join {{ ref('gv_taxonomy') }} t on u.tag = t.category_name
