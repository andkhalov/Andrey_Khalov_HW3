


--> Вывести распределение (количество) клиентов по сферам деятельности, отсортировав результат по убыванию количества. 
select job_industry_category, count(customer_id) as customers
from customers c 
group by job_industry_category 
order by customers desc 


--> Создадим временную таблицу для дальнейшей работы
drop table if exists  temp_all

create temp table temp_all as
select 
	c.job_industry_category,
	c.customer_id,
	t.transaction_date,
	t.list_price,
	t.brand,
	t.order_status,
	t.online_order,
	t.transaction_id,
	c.first_name,
	c.last_name,
	c.job_title
from 
	customers c
join
	"transaction" t on c.customer_id = t.customer_id;

--> Найти сумму транзакций за каждый месяц по сферам деятельности, отсортировав по месяцам и по сфере деятельности.
select 
    distinct (DATE_TRUNC('month', TO_DATE(transaction_date, 'DD/MM/YYYY'))) AS month,
    job_industry_category,
    SUM(list_price) AS total_price
from 
    temp_all
group by
    DATE_TRUNC('month', TO_DATE(transaction_date, 'DD/MM/YYYY')),
    job_industry_category
order by 
    month,
    job_industry_category;
    
   
   --> Вывести количество онлайн-заказов для всех брендов в рамках подтвержденных заказов клиентов из сферы IT.
   select 
   		brand, 
   		count(transaction_id)
   from
   		temp_all
   where 
   		online_order = true 
   		and job_industry_category = 'IT' 
   		and order_status = 'Approved'
   group by brand
   order by count
   
   
   
   --> Найти по всем клиентам сумму всех транзакций (list_price), максимум, минимум и количество транзакций, 
   --> отсортировав результат по убыванию суммы транзакций и количества клиентов. Выполните двумя способами: 
   --> используя только group by и используя только оконные функции. Сравните результат.
   
   --> сначала используем Group By
   select 
   		customer_id,
   		sum(list_price) as sum_tr,
   		max(list_price) as max_tr,
   		min(list_price) as min_tr,
   		count(transaction_id) as tr_count
   from
   		temp_all
   group by 
   		customer_id
   order by 
   		sum_tr desc, 
   		tr_count desc
   
   
   --> теперь используем оконные функции
   select
   		customer_id,
   		sum(list_price) over(partition by customer_id) as sum_tr,
   		max(list_price) over(partition by customer_id) as max_tr,
   		min(list_price) over(partition by customer_id) as min_tr,
   		count(transaction_id) over(partition by customer_id) as tr_count
   from 
   		temp_all
   order by 
   		sum_tr desc, 
   		tr_count desc
   
   
   -->Найти имена и фамилии клиентов с минимальной/максимальной суммой транзакций за весь период (сумма транзакций не может быть null). 
   --> Напишите отдельные запросы для минимальной и максимальной суммы. — (2 балла)
   
   	--> максимальная транзакция 
   	select	
   		first_name,
   		last_name,
   		list_price as max_price
   	from 
   		temp_all
	where
		list_price = (
						select
							max(list_price)
						from
							temp_all
						where 
							list_price is not null
						)
						
						
						
	--> минимальная транзакция
	select	
   		first_name,
   		last_name,
   		list_price as min_price
   	from 
   		temp_all
	where
		list_price = (
						select
							min(list_price)
						from
							temp_all
						where 
							list_price is not null
						)

						
--> Вывести только самые первые транзакции клиентов. 
--> Решить с помощью оконных функций.	
with RankedTransactions as (
    select
        customer_id,
        transaction_date,
        list_price,
        row_number() over (partition by customer_id order by to_date(transaction_date, 'DD/MM/YYYY')) as rn
    from
        temp_all
)
select
    customer_id,
    transaction_date,
    list_price
from
    RankedTransactions
where
    rn = 1;
   

   --> Вывести имена, фамилии и профессии клиентов, между транзакциями которых 
   --> был максимальный интервал (интервал вычисляется в днях).
   --> здесь тоже используем  СTE
   
   --> План запроса:
   -->		1) Создаем CTE таблицу смещений, то есть следующей даты по каждому кастомеру
   -->		2) Создаем таблицу с разницей смещение - действительная транзакция
   -->		3) Вычисляем максимальный гэп
   
with TransactionDifferences as (
    select
        customer_id,
        first_name,
        last_name,
        job_title,
        to_date(transaction_date, 'DD/MM/YYYY') as transaction_date,
        lead(to_date(transaction_date, 'DD/MM/YYYY')) over (partition by customer_id order by to_date(transaction_date, 'DD/MM/YYYY')) as next_transaction_date
    from
        temp_all
),
Intervals as (
    select
        customer_id,
        first_name,
        last_name,
        job_title,
        transaction_date,
        next_transaction_date,
        next_transaction_date - transaction_date as interval_days
    from
        TransactionDifferences
    where
        next_transaction_date is not null
),
MaxInterval as (
    select
        max(interval_days) as max_interval
    from
        Intervals
)
select
    i.customer_id,
    i.first_name,
    i.last_name,
    i.job_title,
    i.interval_days
from
    Intervals i, MaxInterval mi
where
    i.interval_days = mi.max_interval;
   
