-- CTE 1: рассчитываем Recency, Frequency, Monetary для каждого клиента
with grouped_data as (
    select 
        card as card_num,                                    -- номер бонусной карты (идентификатор клиента)
        ('2022-06-09' - max(datetime::date)) as recency,    -- Recency: дни с последней покупки до 09.06.2022
        count(distinct doc_id) as frequency,                 -- Frequency: количество уникальных чеков
        sum(summ) as monetary                                -- Monetary: общая сумма покупок
    from bonuscheques 
    where datetime::date between '2022-01-01' and '2022-06-09'  -- фильтр по периоду
        and card ~ '^[0-9]+$'                                -- только реальные номера карт (без зашифрованных)
    group by card
),

-- CTE 2: рассчитываем перцентили для каждой метрики
perc_rfm as (
    select
        -- Recency: чем меньше дней, тем лучше
        percentile_cont(0.33) within group (order by recency) as r33,   -- 33-й перцентиль
        percentile_cont(0.66) within group (order by recency) as r66,   -- 66-й перцентиль
        
        -- Frequency: чем больше, тем лучше
        percentile_cont(0.33) within group (order by frequency) as f33,
        percentile_cont(0.66) within group (order by frequency) as f66,
        
        -- Monetary: чем больше, тем лучше
        percentile_cont(0.33) within group (order by monetary) as m33,
        percentile_cont(0.66) within group (order by monetary) as m66
    from grouped_data
),

-- CTE 3: присваиваем каждому клиенту оценки R_score, F_score, M_score (1–3)
client_scores as (
    select
        gd.card_num,
        gd.recency,
        gd.frequency,
        gd.monetary,
        
        -- R_score: 3 = самые свежие (recency <= r33)
        --          2 = средние (recency между r33 и r66)
        --          1 = давно не покупали (recency >= r66)
        case
            when gd.recency <= pr.r33 then 3
            when gd.recency <= pr.r66 then 2
            else 1
        end as r_score,
        
        -- F_score: 3 = высокая частота (frequency >= f66)
        --          2 = средняя (frequency между f33 и f66)
        --          1 = низкая (frequency <= f33)
        case
            when gd.frequency >= pr.f66 then 3
            when gd.frequency >= pr.f33 then 2
            else 1
        end as f_score,
        
        -- M_score: 3 = высокий чек (monetary >= m66)
        --          2 = средний (monetary между m33 и m66)
        --          1 = низкий (monetary <= m33)
        case
            when gd.monetary >= pr.m66 then 3
            when gd.monetary >= pr.m33 then 2
            else 1
        end as m_score
        
    from grouped_data gd
    cross join perc_rfm pr   -- добавляем перцентили к каждому клиенту
)

-- Финальный запрос: группируем по RFM-сегментам и считаем агрегаты
select
    count(*) as clients_count,                               -- количество клиентов в сегменте
    concat(r_score, f_score, m_score) as rfm_segment,        -- RFM-сегмент (три цифры)
    round(avg(recency), 1) as avg_recency_days,              -- средний Recency по сегменту
    round(avg(frequency), 1) as avg_frequency,               -- средняя частота по сегменту
    round(avg(monetary), 2) as avg_monetary                  -- средний чек по сегменту
from client_scores
group by rfm_segment
order by rfm_segment;                                        -- сортировка по сегменту
