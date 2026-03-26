with grouped_data as (
    select 
        card as card_num,
        ('2022-06-09' - max(datetime::date)) as recency,
        count(distinct doc_id) as frequency,
        sum(summ) as monetary
    from bonuscheques 
    where datetime::date between '2022-01-01' and '2022-06-09'
        and card ~ '^[0-9]+$'
    group by card
),
perc_rfm as (
    select
        percentile_cont(0.33) within group (order by recency) as r33,
        percentile_cont(0.66) within group (order by recency) as r66,
        percentile_cont(0.33) within group (order by frequency) as f33,
        percentile_cont(0.66) within group (order by frequency) as f66,
        percentile_cont(0.33) within group (order by monetary) as m33,
        percentile_cont(0.66) within group (order by monetary) as m66
    from grouped_data
),
client_scores as (
    select
        gd.card_num,
        gd.recency,
        gd.frequency,
        gd.monetary,
        case
            when gd.recency <= pr.r33 then 3
            when gd.recency <= pr.r66 then 2
            else 1
        end as r_score,
        case
            when gd.frequency >= pr.f66 then 3
            when gd.frequency >= pr.f33 then 2
            else 1
        end as f_score,
        case
            when gd.monetary >= pr.m66 then 3
            when gd.monetary >= pr.m33 then 2
            else 1
        end as m_score
    from grouped_data gd
    cross join perc_rfm pr
)

select
	count(*) as clients_count,
    concat(r_score, f_score, m_score) as rfm_segment,
    round(avg(recency), 1) as avg_recency_days,
    round(avg(frequency), 1) as avg_frequency,
    round(avg(monetary), 2) as avg_monetary
from client_scores
group by rfm_segment
order by rfm_segment;
