WITH 

-- import CTEs

customers AS (
    
                SELECT * FROM {{ source('jaffle_shop', 'customers') }}

             ),

orders AS (
    
                SELECT * FROM {{ source('jaffle_shop', 'orders') }}

          ),

payments AS (
    
                SELECT * FROM {{ source('stripe', 'payment') }}

           ),

-- logical CTEs

customer_payment AS (

                     SELECT 
                           ORDERID AS order_id, 
                           max(CREATED) AS payment_finalized_date, 
                           sum(AMOUNT) / 100.0 AS total_amount_paid
                     FROM payments
                     WHERE status <> 'fail'
                     GROUP BY 1
                    ),

paid_orders AS (
    
                SELECT 
                      orders.ID AS order_id,
                      orders.USER_ID    AS customer_id,
                      orders.ORDER_DATE AS order_date,
                      orders.STATUS AS order_status,
                      customer_payment.total_amount_paid AS total_amount_paid,
                      customer_payment.payment_finalized_date AS payment_finalized_date,
                      customers.FIRST_NAME AS customer_first_name,
                      customers.LAST_NAME AS customer_last_name
                FROM orders
                
                LEFT JOIN customer_payment 
                ON orders.ID = customer_payment.order_id

                LEFT JOIN customers
                ON orders.USER_ID = customers.ID

              ),

customer_orders AS (
                    SELECT 
                          customers.ID AS customer_id,
                          MIN(orders.ORDER_DATE) AS first_order_date
                          
                    FROM customers
                    
                    LEFT JOIN orders
                    ON orders.USER_ID = customers.ID 
                    GROUP BY 1
                   ),

customer_spend AS (
                         SELECT
                                order_id,
                                SUM(total_amount_paid) OVER(PARTITION BY customer_id ORDER BY order_id)AS customer_lifetime_spend,
                                SUM(CASE WHEN order_status NOT LIKE 'return%' THEN total_amount_paid
                                         ELSE 0 END) OVER (PARTITION BY customer_id ORDER BY order_id) AS customer_actual_spend
                          FROM paid_orders po1
                          
                          
                          ORDER BY 1

                        ),


-- Final CTE

final AS (
          SELECT
                paid_orders.order_id,
                paid_orders.customer_id,
                paid_orders.customer_last_name,
                paid_orders.customer_first_name,
                paid_orders.order_date,
                paid_orders.total_amount_paid,
                paid_orders.order_status,
                paid_orders.payment_finalized_date,
                ROW_NUMBER() OVER (PARTITION BY customer_orders.customer_id ORDER BY paid_orders.order_id) AS customer_sales_seq,
                customer_spend.customer_actual_spend,
                customer_spend.customer_lifetime_spend,
                CASE WHEN customer_orders.first_order_date = paid_orders.order_date
                     THEN 'new' --categorized as new customer
                     ELSE 'return' -- categorized as returning customer
                END AS customer_status,
                customer_orders.first_order_date AS first_order_date
          FROM paid_orders

          LEFT JOIN customer_orders 
          USING (customer_id)
    
          LEFT JOIN customer_spend
          USING(order_id)

          ORDER BY 1
          
         )

-- Simple SELECT Statements

SELECT * FROM final order by customer_id, order_id 