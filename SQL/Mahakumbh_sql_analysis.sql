-- What was the total number of pilgrims per day across all sectors?

Select date, sum(pilgrims) as total_pilgrims from pilgrim_attendance
group by date
order by date;

-- Which states contributed the highest pilgrim counts during the event?

Select state, Sum(pilgrims) as Total from pilgrim_attendance
group by state
order by total DESC
limit 1;

-- What were the top 5 days with the highest footfall?

select month, sum(pilgrims) as total_footfall from pilgrim_attendance
group by month
order by total_footfall DESC
limit 5;

-- How does pilgrim count vary across weekdays and weekends?

select c.day_type, sum(p.pilgrims) as count from pilgrim_attendance p 
left join calendar c on c.date = p.date
group by c.day_type;

-- Which accommodation types had the highest and lowest occupancy rates?

with cte as(
select accommodation_type, sum(total_capacity) as capacity, sum(occupied) as total_occupied from accommodation
group by accommodation_type
),
occupancy as(
select accommodation_type, ROUND(100.0 * total_occupied / capacity, 2) as occupancy_rate from cte
),
-- select * from occupancy
-- where occupancy_rate= (select max(occupancy_rate) from occupancy) or occupancy_rate = (select min(occupancy_rate) from occupancy)
-- order by occupancy_rate desc;
ranks as (
select *, rank() over (order by occupancy_rate) as rn_asc, 
rank() over (order by occupancy_rate desc) as rn_desc from occupancy
)

select accommodation_type, occupancy_rate from ranks
where rn_asc=1 or rn_desc=1;

-- What was the average stay duration by accommodation type?

select accommodation_type, round(avg(avg_stay_days), 2) as average_stay from accommodation
group by accommodation_type;

-- Which booking channel (Govt Portal, Private, Walk-in) was most used?

select booking_channel, count(*) as total_booking_count from accommodation
group by booking_channel
order by total_booking_count desc
limit 1;

-- Which sectors had occupancy over 95% for more than 5 days — indicating overcrowding risk?

with cte as(
select date, sector, round(100.0 * occupied / total_capacity, 2 ) as occupancy_rate from accommodation
order by sector, date
),
occupancy as (
select sector, count(*) as count_over_95 from cte
where occupancy_rate > 95
group by sector
)

select * from occupancy
where count_over_95 > 5
order by count_over_95 desc;



-- Which sectors had the highest water and electricity consumption?

WITH infra AS (
SELECT sector, SUM(water_liters) AS water_litres_total, 
SUM(electricity_kwh) AS high_electricity_consp FROM infrastructure
GROUP BY sector
)

SELECT *
FROM infra
WHERE water_litres_total = (SELECT MAX(water_litres_total) FROM infra)
OR high_electricity_consp = (SELECT MAX(high_electricity_consp) FROM infra);


-- What is the correlation between feedback score and sanitation count?

select round(corr(feedback_score, sanitation_count):: "numeric", 4) as correlation,
case when corr(feedback_score, sanitation_count) < 0.3 then 'weak correlation'
	 when corr(feedback_score, sanitation_count) < 0.7 then 'moderate correlation'
	 else 'strong correlation'
end as correlation_strength
from infrastructure;

-- Which 5 sectors consistently received feedback scores below 3.5?

select sector, count(*) as low_feedback from infrastructure
where feedback_score < 3.5
group by sector
order by low_feedback desc
limit 5;

-- =============================================================================

SELECT 
    sector,
    COUNT(*) FILTER (WHERE feedback_score < 3.5) AS low_score_count,
    COUNT(*) AS total_entries,
    ROUND(100.0 * COUNT(*) FILTER (WHERE feedback_score < 3.5) / COUNT(*), 2) AS low_score_percent
FROM infrastructure
GROUP BY sector
HAVING COUNT(*) >= 5  
ORDER BY low_score_percent DESC
LIMIT 5;


-- Which sectors had maximum sanitation services but low feedback — indicating potential service inefficiencies?
with cte as (
select sector, sum(sanitation_count) as total_sanitation, round(avg(feedback_score), 2) as feedback from infrastructure
group by sector
)
select sector, total_sanitation, feedback from cte
where total_sanitation > (select avg(total_sanitation) from cte) 
AND feedback < (select avg(feedback) from cte)
order by feedback;

-- Which sectors reported the most medical and crime-related incidents?

select sector, sum(incidents_medical) as total_medical_inc, sum(incidents_crime) as total_crime_inc
from security
group by sector
order by total_medical_inc desc, total_crime_inc desc;

-- What was the average number of incidents per 10,000 pilgrims in each sector?

WITH pilgrim_total AS (
    SELECT 
        date,
        sector,
        SUM(pilgrims) AS total_pilgrims
    FROM pilgrim_attendance
    GROUP BY date, sector
),
incident_total AS (
    SELECT 
        date,
        sector,
        (incidents_medical + incidents_crime) AS total_incidents
    FROM security
)
SELECT 
    i.sector,
    ROUND(AVG( (i.total_incidents * 10000.0) / p.total_pilgrims ), 2) AS avg_incidents_per_10k
FROM incident_total i
JOIN pilgrim_total p
  ON i.sector = p.sector AND i.date = p.date
WHERE p.total_pilgrims > 0
GROUP BY i.sector
ORDER BY avg_incidents_per_10k DESC;


-- Which business types generated the most revenue?

select business_type, sum(revenue_rs) as total_revenue from economic_activity 
group by business_type
order by total_revenue desc;

-- What was the revenue per sector compared to footfall, to identify high-performing business zones?

select e.sector, sum(e.revenue_rs) as total_revenue, sum(p.pilgrims) as total_pilgrims, 
Round(sum(e.revenue_rs)/NULLIF(sum(p.pilgrims), 0), 2) as revenue_per_pilgrims from economic_activity e
left join pilgrim_attendance p
on p.date = e.date and p.sector = e.sector
group by e.sector
order by revenue_per_pilgrims desc;

-- Which sectors created the most employment opportunities?

select sector, sum(total_jobs) as employment_created from economic_activity
group by sector
order by employment_created desc;

-- Based on 2025 trends, which sectors require infrastructure scaling for the next Maha Kumbh?

SELECT
    i.sector,
    ROUND(AVG(i.water_liters), 2) AS avg_water_usage,
    ROUND(AVG(i.electricity_kwh), 2) AS avg_electricity_usage,
    ROUND(AVG(i.sanitation_count), 2) AS avg_sanitation,
    ROUND(AVG(i.feedback_score), 2) AS avg_feedback,
    SUM(p.pilgrims) AS total_footfall
FROM infrastructure i
JOIN pilgrim_attendance p ON i.sector = p.sector AND i.date = p.date
GROUP BY i.sector
HAVING AVG(i.water_liters) > 45000
   AND AVG(i.sanitation_count) < 600
ORDER BY total_footfall DESC;


-- What is the current vs forecasted resource (water, electricity, sanitation) requirement if pilgrims increase by 20% 
--in the next Kumbh?
SELECT
    ROUND(SUM(water_liters), 0) AS current_water_liters,
    ROUND(SUM(water_liters) * 1.2, 0) AS forecasted_water_liters,
    ROUND(SUM(electricity_kwh), 0) AS current_electricity_kwh,
    ROUND(SUM(electricity_kwh) * 1.2, 0) AS forecasted_electricity_kwh,
    ROUND(SUM(sanitation_count), 0) AS current_sanitation_count,
    ROUND(SUM(sanitation_count) * 1.2, 0) AS forecasted_sanitation_count
FROM infrastructure i
JOIN pilgrim_attendance p ON i.sector = p.sector AND i.date = p.date
WHERE EXTRACT(YEAR FROM i.date) = 2025;



