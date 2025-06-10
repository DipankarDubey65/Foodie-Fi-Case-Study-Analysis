/* The Foodie-Fi team wants you to create a new payments table for the year 2020 
that includes amounts paid by each customer in the subscriptions table with the following requirements:
   *) monthly payments always occur on the same day of month as the original start_date of any monthly paid plan
   * upgrades from basic to monthly or pro plans are reduced by the current paid amount in that month and start immediately
   * upgrades from pro monthly to pro annual are paid at the end of the current billing period and also starts at the end of the month period
    once a customer churns they will no longer make payments
*/


with recursive filter_data as(select sb.customer_id,sb.plan_id,sb.start_date,pl.plan_name,pl.price from 
subscriptions sb join plans pl on sb.plan_id = pl.plan_id where year(start_date)= 2020),

rank_plan as(select customer_id,plan_name,start_date,row_number() over(partition by customer_id order by start_date) as ranks 
from filter_data fd),

 monthly_payment as(select customer_id,plan_id,plan_name,start_date as payment_date, price as amount, 1 as payment_order 
from filter_data where plan_name in('basic monthly','pro monthly')
union
select mp.customer_id,mp.plan_id,mp.plan_name,
date_add(mp.payment_date, interval 1 month),mp.amount,mp.payment_order+1
 from monthly_payment mp join filter_data fd on mp.customer_id = fd.customer_id
 where date_add(mp.payment_date, interval 1 month) <= '2020-12-31'
 and not exists ( select 1 from filter_data fd 
 where fd.customer_id = mp.customer_id 
 and fd.start_date > mp.payment_date 
 and fd.start_date<= date_add(mp.payment_date, interval 1 month)
 and fd.plan_name != mp.plan_name)
 
 and not exists (select 1 from filter_data f2 where f2.customer_id = mp.customer_id and f2.plan_name = 'churn'
 and f2.start_date<= date_add(mp.payment_date,interval 1 month))
 ),
 
 
 one_time_payment as(select customer_id,plan_id,plan_name,start_date as payment_date,price as amount, 1 as payment_order 
 from filter_data where plan_name in('pro annual','basic annual')),
 
 
upgrade_adjustment as(select f.customer_id,
f.plan_id,f.plan_name,(case when f.plan_name = 'basic monthly' then f.start_date
when prev.plan_name = 'pro monthly' and f.plan_name = 'pro annual' then date_add(prev.start_date,interval 1 month) 
else f.start_date end )as payment_date,
(case when prev.plan_name = 'basic monthly' then f.price - prev.price else f.price end) as amount, 1 as payment_order
 
from filter_data f join filter_data prev 
 on f.customer_id = prev.customer_id and prev.start_date< f.start_date
 where f.plan_name in('pro monthly','pro annual') 
 and prev.plan_name in( 'basic monthly','pro monthly')
 and year(f.start_date) = 2020),
 
all_payment as( select * from monthly_payment
 union
 select * from one_time_payment
 union
 select * from upgrade_adjustment)

select customer_id,plan_id,plan_name,payment_date,round(amount,2) amount,
row_number() over(partition by customer_id order by payment_date) as payment_order
 from all_payment order by customer_id,payment_date;
 
