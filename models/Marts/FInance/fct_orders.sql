WITH orders as (

  SELECT * FROM {{ ref('stg_jaffle_shop__orders') }}
  ),



customer_spend as (

  SELECT 
  orders.order_id,
  COALESCE(SUM(payment_amount),0) as amount
  FROM orders
  LEFT JOIN {{ ref('stg_stripe__payment') }} as sp
  USING (order_id)
  WHERE sp.payment_status = 'success' AND orders.status NOT LIKE ('returned%')
  GROUP BY orders.order_id
),

final as (

  SELECT 
  orders.order_id as order_id,
  orders.customer_id as customer_id,
  COALESCE(customer_spend.amount,0) as amount
  
  FROM orders
    LEFT JOIN customer_spend USING(order_id)
    

)

SELECT * FROM final ORDER BY CUSTOMER_ID