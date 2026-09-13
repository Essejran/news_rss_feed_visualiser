{{ config(materialized='table') }}

select
    date(pub_date) as article_date,
    count(*) as article_count
from {{ ref('stg_articles') }}
group by 1
order by 1