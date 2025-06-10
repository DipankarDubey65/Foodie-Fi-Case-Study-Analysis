# 1. How many customers has Foodie-Fi ever had?
SELECT 
    COUNT(DISTINCT customer_id) total_customer
FROM
    subscriptions;

# 2. What is the monthly distribution of trial plan start_date values for our dataset

SELECT 
    MONTHNAME(sb.start_date) start_month, COUNT(*) trial_plan
FROM
    subscriptions sb
        JOIN
    plans pl ON sb.plan_id = pl.plan_id
WHERE
    pl.plan_name = 'trial'
GROUP BY start_month
ORDER BY MONTH(sb.start_date);

/* 3. What plan start_date values occur after the year 2020 for our dataset?
  Show the breakdown by count of events for each plan_name */
 
 select pl.plan_name,count(*) plan_event from subscriptions sb join plans pl on sb.plan_id = pl.plan_id
 where sb.start_date >'2020-12-31'
 group by pl.plan_name;
 
/* 4. What is the customer count and percentage of customers who have churned rounded to 1 decimal place? */

with ct as (select count(*) total_subscriber, count(case when pl.plan_name ='churn' then 1 end) cancellation_subscriber
from subscriptions sb 
join plans as pl on sb.plan_id = pl.plan_id )

select cancellation_subscriber as churned_customer_count, 
round((cancellation_subscriber/total_subscriber)*100 ,1) as churned_percentage from ct;
 
 
 /* 5. How many customers have churned straight after their initial free trial - what percentage
 is this rounded to the nearest whole number? */
 
  with ranked_plan as(select customer_id,plan_id,
  row_number() over(partition by customer_id order by start_date) as plan_order from subscriptions),
 
 customer_plan as(select rp.customer_id,pl.plan_name,rp.plan_order  from ranked_plan rp join plans pl on rp.plan_id = pl.plan_id),
 
trial_churn as(select cp1.customer_id from customer_plan cp1 join customer_plan cp2 on cp1.customer_id = cp2.customer_id 
 and cp1.plan_order  = 1 and cp2.plan_order =2
 where cp1.plan_name = 'trial'  and cp2.plan_name = 'churn'),
 
total_customer as(select count(distinct customer_id) total from subscriptions)

select count(*) churned_after_trial,round((count(*) * 100)/(select total from total_customer)) as percntage from trial_churn;


# 6. What is the number and percentage of customer plans after their initial free trial?
with ranked_plan as(select customer_id,plan_id,row_number() over(partition by customer_id order by start_date) plan_order from subscriptions),

customer_plan as(select rp.customer_id,pl.plan_name,rp.plan_order from ranked_plan rp join plans pl on rp.plan_id = pl.plan_id),

initial_trial as(select cp1.customer_id from customer_plan cp1 join customer_plan cp2 on 
cp1.customer_id = cp2.customer_id and cp1.plan_order = 1 and cp2.plan_order = 2 
where cp1.plan_name ='trial' and cp2.plan_name != 'churn' ),

total_customer as(select count(distinct customer_id) total from subscriptions)

select count(*) initial_after_trial, round((count(*)*100)/(select total from total_customer)) as percentage from initial_trial;


# 7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
with fd as(select * from subscriptions where start_date <= '2020-12-31'),

ranked_plan as(select customer_id, plan_id,row_number() over(partition by customer_id order by start_date desc) as ranks from fd ),

latest_plan as(select customer_id,plan_id from ranked_plan rp  where ranks = 1),

tc as(select count(*) as total from latest_plan)

 select pl.plan_name,count(lp.customer_id) as customer, round((count(*)*100)/(select total from tc),1) percentage 
 from latest_plan lp join plans pl on lp.plan_id = pl.plan_id group by plan_name;
 


#8. How many customers have upgraded to an annual plan in 2020?
with filter_data as(select * from subscriptions where year(start_date) = 2020)

select count(distinct fd.customer_id) upgrade from filter_data fd join plans pl on
 fd.plan_id = pl.plan_id where pl.plan_name = 'pro annual' ; 
 
#9. How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
 with filter_data as(select sb.customer_id,sb.plan_id,sb.start_date,pl.plan_name,pl.price 
 from subscriptions sb join plans pl on sb.plan_id = pl.plan_id where pl.plan_name in('trial' ,'pro annual')),
 
 
 rank_plan as(select customer_id,plan_name,start_date,row_number() over(partition by customer_id order by start_date) as ranks 
 from filter_data fd),
 
 customer_plans as(select customer_id,count(*) rank_count from rank_plan rp group by customer_id ),
 
 final_data as (select rp.customer_id,rp.plan_name,rp.start_date,rp.ranks from rank_plan  rp join customer_plans cp 
 on rp.customer_id = cp.customer_id where rank_count = 2)
 
 select  round(avg(datediff(annual.start_date,trial.start_date))) average_days_to_annual 
 from final_data as trial join final_data as annual on trial.customer_id = annual.customer_id where trial.ranks = 1 and annual.ranks = 2;
 
 
# 10. Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
with filter_data as(select sb.customer_id,sb.plan_id,sb.start_date,pl.plan_name,pl.price from subscriptions sb join plans pl 
on sb.plan_id = pl.plan_id where pl.plan_name in('trial', 'pro annual')),

rank_plan as(select customer_id,plan_name,start_date,row_number() over(partition by customer_id order by start_date) as ranks
from filter_data),

rank_count as(select customer_id,count(customer_id) rnc from rank_plan group by customer_id),

final_data as(select rp.customer_id,rp.plan_name,rp.start_date,rp.ranks from rank_plan rp 
join rank_count rc on rp.customer_id = rc.customer_id),

clear_data as(select trial.customer_id ,datediff(annual.start_date,trial.start_date) upgrade_days 
from final_data trial join final_data annual on trial.customer_id = annual.customer_id 
where trial.ranks = 1 and annual.ranks =2)

select (case
when upgrade_days between 0 and 30 then '0-30 days'
when upgrade_days between 31 and 60 then '31-60 days'
when upgrade_days between 61 and 90 then '61-90 days'
when upgrade_days between 91 and 120 then '91-120 days'
else '120+ days' end) as upgrade_range,count(*) as total_customer
 from clear_data
 group by upgrade_range order by upgrade_range;
 
 
# 11. How many customers downgraded from a pro monthly to a basic monthly plan in 2020? 
 
with filter_data as(select sb.customer_id,sb.plan_id,sb.start_date,pl.plan_name,pl.price 
from subscriptions sb join plans pl on sb.plan_id = pl.plan_id 
where year(start_date) = 2020 and pl.plan_name in('pro monthly','basic monthly')),

rank_plan as(select customer_id,plan_name,start_date,row_number() over(partition by customer_id order by start_date asc) as ranks 
from filter_data),

rank_count as(select customer_id,count(*) rnc from rank_plan group by customer_id),
 
 final_data as(select rp.customer_id,rp.plan_name,rp.start_date,ranks 
 from rank_plan rp join rank_count rc on rp.customer_id =rc.customer_id)
 
 select count(*) total_customer from final_data pro_monthly join final_data basic_monthly 
 on pro_monthly.customer_id = basic_monthly.customer_id 
 where pro_monthly.ranks = 1 and basic_monthly.ranks = 2 and 
 pro_monthly.plan_name ='pro monthly' and basic_monthly.plan_name = 'basic monthly'; 
 



