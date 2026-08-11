with customers as (

Select * from {{ ref('stg_jaffle_shop__customer') }}

),

orders as (

   Select * from {{ ref('stg_jaffle_shop__order') }}

),

customer_orders as (

    select
        customer_id,
        min(order_date) as first_order_date,
        max(order_date) as most_recent_order_date,
        count(order_id) as number_of_orders

    from orders

    group by 1

),

lifetime_customer_spend as (

    SELECT 
    customer_id,
    SUM(amount) as lifetime_value
    
    FROM {{ ref('fct_orders') }}

    GROUP BY 1
),


final as (

    select
        customers.customer_id,
        customers.first_name,
        customers.last_name,
        customer_orders.first_order_date,
        customer_orders.most_recent_order_date,
        coalesce(customer_orders.number_of_orders, 0) as number_of_orders,
        coalesce(lifetime_customer_spend.lifetime_value,0) as lifetime_value

    from customers

    left join customer_orders using (customer_id)
    left join lifetime_customer_spend using (customer_id)

)

select * from final order by customer_id