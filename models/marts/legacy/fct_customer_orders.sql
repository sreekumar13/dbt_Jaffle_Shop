WITH 

-- import CTEs

customers AS (
    
                SELECT 
                      ID AS customer_id,
                      FIRST_NAME AS customer_givenname,
                      LAST_NAME AS customer_surname
                
                FROM {{ source('jaffle_shop', 'customers') }}

             ),

orders AS (
    
                SELECT 
                      ID AS order_id,
                      USER_ID AS customer_id,
                      ORDER_DATE AS order_date,
                      STATUS AS order_status,
                      _ETL_LOADED_AT AS _etl_loaded_at
                
                FROM {{ source('jaffle_shop', 'orders') }}

          ),

payments AS (
    
                SELECT 
                      ID AS payment_id,
                      ORDERID AS order_id,
                      PAYMENTMETHOD AS payment_method,
                      STATUS AS payment_status,
                      ROUND(AMOUNT/100.0,2) AS payment_amount,
                      CREATED AS payment_created_date,
                      _BATCHED_AT AS _batched_at
                
                FROM {{ source('stripe', 'payment') }}
                WHERE STATUS <> 'fail'
           ),

-- logical CTEs

customer_spend AS (
                    SELECT DISTINCT
                                   orders.order_id,
                                   orders.customer_id,
                                   SUM(payments.payment_amount) OVER (PARTITION BY orders.order_id) AS total_order_value,
                                   SUM(payments.payment_amount) OVER(PARTITION BY orders.customer_id ORDER BY orders.order_id) AS customer_lifetime_spend,
                                   SUM(CASE WHEN orders.order_status NOT LIKE 'return%' 
                                            THEN payments.payment_amount --Cumulative sum of orders that were not returned
                                            ELSE 0 END) 
                                            OVER (PARTITION BY orders.customer_id ORDER BY orders.order_id) AS customer_actual_spend
                              
                    FROM payments
                          
                    LEFT JOIN orders
                    USING(order_id)

                    ORDER BY 2,1

                   ),


-- Final CTE

final AS (
          SELECT
                orders.order_id,
                orders.customer_id,
                customers.customer_surname,
                customers.customer_givenname,
                orders.order_date,
                customer_spend.total_order_value,
                orders.order_status,
                CASE WHEN MIN(orders.order_date) OVER (PARTITION BY orders.customer_id ORDER BY orders.order_id) = orders.order_date
                     THEN 'new' --categorized as new customer
                     ELSE 'return' -- categorized as returning customer
                END AS customer_status,
                ROW_NUMBER() OVER (PARTITION BY orders.customer_id ORDER BY orders.order_id) AS customer_sales_seq,
                MIN(orders.order_date) OVER (PARTITION BY orders.customer_id ORDER BY orders.order_id) AS first_order_date,
                customer_spend.customer_actual_spend,
                customer_spend.customer_lifetime_spend,
          
          FROM orders

          LEFT JOIN customers
          USING(customer_id)
          
          LEFT JOIN customer_spend
          USING(order_id)

          ORDER BY 2,1
          
         )

-- Simple SELECT Statements

SELECT 
      * 

FROM final 

ORDER BY customer_id, order_id 