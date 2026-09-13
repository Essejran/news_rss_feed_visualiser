{{ config(materialized='table') }}

select
    tag,
    count(distinct guid) as mention_count,
    max(pub_date) as last_mentioned
from {{ ref('stg_articles') }},
unnest(tags) as tag
group by 1
order by mention_count desc