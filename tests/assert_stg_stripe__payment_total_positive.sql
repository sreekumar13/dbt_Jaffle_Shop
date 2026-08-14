SELECT SUM(payment_amount) as payment_total
FROM {{ ref('stg_stripe__payment') }}
GROUP BY order_id
HAVING payment_total<0
