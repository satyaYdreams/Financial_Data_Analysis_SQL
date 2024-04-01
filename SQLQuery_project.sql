--1 top 5 cities with highest spends and their percentage contribution of total credit card spends 
use [ZERO TO HERO];

with city_spends as (
Select city , cast((sum(amount)) as bigint) as spends
from [dbo].[credit_card_transcations]
group by city),

overall_spend as (
select  *, cast(sum(spends)over() as bigint) as total_spends
from city_spends)

select top 5 city, cast (spends*100.0/total_spends as decimal(10,2)) as per_of_total_spends
from overall_spend
order by spends desc

----------------------------------------------------------------------------------------
--2.highest spend month and amount spent in that month for each card type

with type_mon_spends as (
select FORMAT(transaction_date, 'yyyy-MM') as year_month, card_type, sum(amount) as monthly_spends
from credit_card_transcations
group by FORMAT(transaction_date, 'yyyy-MM') , card_type),

top_months as (
select *, ROW_NUMBER()over(partition by card_type order by monthly_spends desc) as ranking
from type_mon_spends)

select card_type, year_month, monthly_spends
from top_months
where ranking = 1
-------------------------------------------------------------------------------------------------------
--3 transaction details(all columns from the table) for each card type when
--it reaches a cumulative of 1000000 total spends(We should have 4 rows in the o/p one for each card type)


with cte as (
select *,
cast(sum(amount)over(partition by card_type order by transaction_date rows between unbounded preceding and current row ) as bigint) as total_spends
from credit_card_transcations),

cte2 as (select*, lag(total_spends)over(partition by card_type order by transaction_date) as prev_total
from cte)

select transaction_id, city, transaction_date, card_type, gender, amount
from cte2
where total_spends>1000000 and prev_total < 1000000
--------------------------------------------------------------------------------------------------------------
--4. city which had lowest percentage spend for gold card type
--select distinct card_type from credit_card_transcations

with cte as (
select city, 
coalesce(sum(case when card_type = 'Gold' then amount end),0)  as gold_spend,
sum(amount)  as total_spend
from credit_card_transcations
group by city)

select top 1 city, gold_spend*100.0/total_spend as per_gold_spend
from cte
where gold_spend>0
order by per_gold_spend 
---------------------------------------------------------------------------------------------------

--5. city, highest_expense_type , lowest_expense_type (example format : Delhi , bills, Fuel)

with cte as (
select city,exp_type, sum(amount) as spend,
ROW_NUMBER()over(partition by city order by sum(amount) desc) as highest_type
from credit_card_transcations
group by city,exp_type),

cte2 as (
select city,exp_type, sum(amount) as spend,
ROW_NUMBER()over(partition by city order by sum(amount) ) as lowest_type
from credit_card_transcations
group by city,exp_type)

select a.city,a.exp_type as highest_expense_type, b.exp_type as lowest_expense_type
from cte a 
inner join cte2 b
on a.city=b.city
where a.highest_type=1 and b.lowest_type=1

-------------------------------------------------------------------------------------
--6- percentage contribution of spends by females for each expense type

with cte as (
select exp_type, 
coalesce(sum(case when gender = 'F' then amount end),0)  as female_spend,
sum(amount)  as total_spend
from credit_card_transcations
group by exp_type)

select exp_type, cast( female_spend*100.0/total_spend as decimal(10,2)) as  per_fem_contribution
from cte
-----------------------------------------------------------------------------------------------------------
--7-which card and expense type combination saw highest month over month growth in Jan-2014

with cte as (
Select card_type, exp_type, FORMAT(transaction_date, 'yyyy-MM') as year_month,sum(amount) as spend
from credit_card_transcations
where FORMAT(transaction_date, 'yyyy-MM') in ('2013-12','2014-01')
group by card_type, exp_type, FORMAT(transaction_date, 'yyyy-MM')),

cte2 as (
select *, lag(spend) over(partition by card_type,exp_type order by year_month) as prev_month,
(spend-lag(spend) over(partition by card_type,exp_type order by year_month))*100.0/lag(spend) over(partition by card_type,exp_type order by year_month) as  mom_growth
from cte)

select top 1 card_type,exp_type
from cte2
order by mom_growth desc

--------------------------------------------------------------------------------------------
--8-during weekends which city has highest total spend to total no of transcations ratio 

with cte as (
select *, DATEPART(WEEKDAY, transaction_date ) AS weekday_number
from credit_card_transcations
where DATEPART(WEEKDAY, transaction_date ) in (1,7))

select top 1 city , cast( sum(amount)*1.0/count(transaction_id) as decimal(10,2)) as ratio
from cte
group by city
order by ratio desc
---------------------------------------------------------------------------------------------------
--9-which city took least number of days to reach its 500th transaction after the first transaction in that city

with cte as (
select city , transaction_date,count(transaction_id) as no_of_trans,
sum(count(transaction_id))over(partition by city order by transaction_date rows between unbounded preceding and current row) as runn_count,
min(transaction_date)over(partition by city) as start_date
from credit_card_transcations
group by city, transaction_date),

cte2 as (select *, lag(runn_count)over(partition by city order by transaction_date) as past_run_total
from cte )

select top 1 city
from cte2
where runn_count >=500 and past_run_total < 500
order by DATEDIFF(day,start_date,transaction_date)
----------------------------------------------------------------------------------------------------------



