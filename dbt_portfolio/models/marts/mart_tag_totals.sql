{{ config(materialized='table') }}

select
    tag,
    category_type,
    region,
    iso3,
    count(distinct guid) as mention_count,
    max(pub_date) as last_mentioned
from {{ ref('int_article_tags') }}
group by 1, 2, 3, 4
order by mention_count desc
