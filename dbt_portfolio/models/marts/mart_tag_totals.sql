{{ config(materialized='table') }}

select
    tag,
    category_type,
    region,
    count(distinct guid) as mention_count,
    max(pub_date) as last_mentioned
from {{ ref('int_article_tags') }}
group by 1, 2, 3
order by mention_count desc
