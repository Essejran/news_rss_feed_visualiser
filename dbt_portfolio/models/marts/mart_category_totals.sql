{{ config(materialized='table') }}

select
    date(pub_date) as article_date,
    tag as category_name,
    count(distinct guid) as article_count
from {{ ref('stg_articles') }},
unnest(tags) as tag
group by 1, 2