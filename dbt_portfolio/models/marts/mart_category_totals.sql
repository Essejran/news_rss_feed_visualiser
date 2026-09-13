{{ config(materialized='table') }}

select
    date(pub_date) as article_date,
    main_category,
    count(distinct guid) as article_count
from {{ ref('stg_articles') }}
group by 1, 2