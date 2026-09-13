{{ config(materialized='table') }}

select
    date(pub_date) as article_date,
    tag as category_name,
    category_type,
    region,
    count(distinct guid) as article_count
from {{ ref('int_article_tags') }}
group by 1, 2, 3, 4
