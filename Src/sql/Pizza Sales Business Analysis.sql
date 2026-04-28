select * from pizza
select * from pizza_types
select * from orders
select * from order_details

--Core Metrics
--1.Total Revenue
select sum(od.quantity*p.price) as revenue
from order_details od
join pizza p
on p.pizza_id = od.pizza_id;
--2.Total Orders
select count(distinct order_id) as total_order from orders
--3. Total Quantity Sold
select sum(quantity) as total_quantity_sold from order_details
--4. Average Order Value (AOV)
SELECT 
    round(SUM(od.quantity * p.price) / COUNT(DISTINCT o.order_id),2) AS AOV
FROM orders o
JOIN order_details od ON o.order_id = od.order_id
JOIN pizza p ON p.pizza_id = od.pizza_id;

--Trend Analysis
--1.Daily revenue trend =Increase / decrease
with daily_revenue as(
select 
	o.date,
	sum(od.quantity*p.price) as revenue
	from order_details od
	join pizza p on p.pizza_id = od.pizza_id
	join orders o on o.order_id = od.order_id
	group by o.date
)
select
	date,
	revenue,
	revenue - lag(revenue) over(order by date) as change
from daily_revenue ;
	
--2.Monthly revenue trend
with monthly_revenue as(
select 
	date_trunc('month',o.date) as month,
	sum(od.quantity*p.price) as revenue
	from order_details od
	join pizza p on p.pizza_id = od.pizza_id
	join orders o on o.order_id = od.order_id
	group by month
)
select
	month,
	revenue,
	revenue - lag(revenue) over(order by month) as change
from monthly_revenue ;

--3.“Why revenue drop?
--3(i): Category-wise
WITH monthly_category_revenue AS (
    SELECT 
        DATE_TRUNC('month', o.date) AS month,
        pt.category,
        SUM(od.quantity * p.price) AS revenue
    FROM orders o
    JOIN order_details od ON o.order_id = od.order_id
    JOIN pizza p ON od.pizza_id = p.pizza_id
    JOIN pizza_types pt ON p.pizza_type_id = pt.pizza_type_id
    GROUP BY month, pt.category
),
final AS (
    SELECT 
        month,
        category,
        revenue,
        LAG(revenue) OVER (PARTITION BY category ORDER BY month) AS prev_revenue
    FROM monthly_category_revenue
)
SELECT 
    *,
    revenue - prev_revenue AS change,
    CASE 
        WHEN revenue - prev_revenue < 0 THEN 'Drop'
        WHEN revenue - prev_revenue > 0 THEN 'Growth'
        ELSE 'No Data'
    END AS status
FROM final
ORDER BY category, month;
--3.2 Product-wise
select 	
	pt.name,
	sum(od.quantity) as total_quantity_sold
from pizza_types pt
join pizza p on p.pizza_type_id = pt.pizza_type_id
join order_details od on p.pizza_id = od.pizza_id
group by pt.name
order by total_quantity_sold ;
--Agar koi pizza kam bik raha hai,kya check karoge?
--Price Issue
--Category Weak hai?
--Size Problem?
select 	
	pt.category,
	pt.name,
	sum(od.quantity) as qty,
    ROUND(SUM(od.quantity * p.price) / SUM(od.quantity), 2) as weighted_avg_price
from pizza_types pt
join pizza p on p.pizza_type_id = pt.pizza_type_id
join order_details od on p.pizza_id = od.pizza_id
group by pt.category,pt.name
order by qty ;
--Product Performance
--Size analysis
select
	p.size,
	sum(od.quantity) as total_qty,
	sum(od.quantity * p.price) as revenue
from pizza p
join order_details od on p.pizza_id = od.pizza_id
group by p.size
order by total_qty desc;

--Top products (total_quantity_sold,desc)
--Worst product (total_quantity_sold asc,limit=5)
with product_perf as (
    select
        pt.name,
        sum(od.quantity) as total_quantity_sold,
        sum(od.quantity * p.price) as total_revenue
    from pizza_types pt
    join pizza p on pt.pizza_type_id = p.pizza_type_id
    join order_details od on od.pizza_id = p.pizza_id
    group by pt.name
),

thresholds as (
    select
        percentile_cont(0.9) within group (order by total_quantity_sold) as qty_p90,
        percentile_cont(0.1) within group (order by total_quantity_sold) as qty_p10,
        percentile_cont(0.9) within group (order by total_revenue) as rev_p90,
        percentile_cont(0.1) within group (order by total_revenue) as rev_p10
    from product_perf
)

select p.*,
       case 
           when p.total_quantity_sold >= t.qty_p90 
                or p.total_revenue >= t.rev_p90
           then 'Top Product'
           
           when p.total_quantity_sold <= t.qty_p10 
                and p.total_revenue <= t.rev_p10
           then 'Worst Product'
           
           else 'Average'
       end as product_category
from product_perf p
cross join thresholds t
order by total_quantity_sold desc;
--Step: Time Analysis
