WITH source as (
                SELECT * FROM {{ source('stripe', 'payment') }}
                ),

new_stg as (

    SELECT 
    id as payment_id,
    orderid as order_id,
    paymentmethod as payment_method,
    status as payment_status,
    amount as payment_amount,
    created as payment_date,
    _batched_at as load_date
    
    from source
)

SELECT * FROM new_stg