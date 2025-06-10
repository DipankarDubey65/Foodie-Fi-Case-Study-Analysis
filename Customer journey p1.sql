/* Based off the 8 sample customers provided in the sample from the subscriptions table, 
write a brief description about each customer’s onboarding journey.
Try to keep it as short as possible - you may also want to run some sort of join to make your explanations a bit easier! */

SELECT 
    sb.customer_id, pl.plan_name,sb.start_date
FROM
    subscriptions sb
        JOIN
    plans pl ON sb.plan_id = pl.plan_id
WHERE
    sb.customer_id IN (1 , 2, 3, 4, 5, 6, 7, 8)
order by sb.customer_id,sb.start_date;