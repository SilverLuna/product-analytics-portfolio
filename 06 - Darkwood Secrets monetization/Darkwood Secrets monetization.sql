-- Часть 1. Исследовательский анализ данных

-- Задача 1. Исследование доли платящих игроков
-- 1.1. Доля платящих пользователей по всем данным:
SELECT
	COUNT(id) AS all_players,
	SUM(payer) AS paying_players,
	ROUND(SUM(payer::numeric)/COUNT(id)*100,2) AS perc_of_paying_players -- 17,69%
FROM fantasy.users;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT
	r.race,
	SUM(u.payer) AS paying_players,
	COUNT(u.id) AS all_players,
	ROUND(SUM(u.payer::numeric)/COUNT(u.id)*100,2) AS perc_of_paying_players -- в среднем 17,78%
FROM fantasy.users AS u
LEFT JOIN fantasy.race AS r ON u.race_id = r.race_id
GROUP BY r.race;

-- Задача 2. Исследование внутриигровых покупок

-- 2.1. Статистические показатели по полю amount:
SELECT
	COUNT(amount) AS count_purchases, -- 1307678
	SUM(amount) AS sum_purchases, -- 686615040
	MIN(amount) AS min_purchase, -- 0
	MAX(amount) AS max_purchase, -- 486615
	ROUND(AVG(amount::numeric), 2) AS avg_purchase, -- 525,69
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS median_purchase, -- медиана 74
	ROUND(STDDEV(amount::numeric), 2) AS std_deviation -- стандартное отклонение 2517
FROM fantasy.events;

-- 2.2: Аномальные нулевые покупки:
SELECT
	COUNT(CASE WHEN amount = 0 THEN 1 END) AS zero_purchases, -- 907
	COUNT(amount) AS all_purchases, -- 1307678
	ROUND(COUNT(CASE WHEN amount = 0 THEN 1 END)::numeric/COUNT(amount)*100, 2) AS perc_of_zero_purchases -- 0,07%
FROM fantasy.events;

-- 2.3: Популярные эпические предметы:
WITH buyers_per_item AS( -- уникальные покупатели по группам предметов
	SELECT
		item_code,
		COUNT(DISTINCT id) AS count_item_buyers
	FROM fantasy.events
	WHERE amount > 0
	GROUP BY item_code
)
SELECT
	DISTINCT i.game_items,
	(SELECT COUNT(transaction_id) FROM fantasy.events WHERE amount > 0) AS all_purchases, -- все продажи без нулей 1306771
	COUNT(e.transaction_id) AS item_purchases,
	ROUND(COUNT(e.transaction_id)::numeric/(SELECT COUNT(transaction_id) FROM fantasy.events WHERE amount > 0)*100, 2) AS perc_of_item_purchases,
	(SELECT SUM(count_item_buyers) FROM buyers_per_item) AS all_buyers, -- все уникальные покупатели всех эпиков 33509
	COUNT(DISTINCT e.id) AS item_buyers, -- уникальные покупатели по группам
	ROUND(COUNT(DISTINCT id)::numeric/(SELECT SUM(count_item_buyers) FROM buyers_per_item)*100, 2) AS perc_of_buyers -- %
FROM fantasy.events AS e
LEFT JOIN fantasy.items AS i ON e.item_code = i.item_code
LEFT JOIN buyers_per_item AS b ON i.item_code = b.item_code
WHERE e.amount > 0
GROUP BY i.game_items
ORDER BY item_purchases DESC;


-- Часть 2. Решение ad hoc-задачи

-- Задача: Зависимость активности игроков от расы персонажа:
WITH players_per_race AS ( -- общее количество зарег игроков по расам
	SELECT
		race_id,
		COUNT(id) AS all_players
	FROM fantasy.users
	GROUP BY race_id
	ORDER BY race_id
),
paying_players_per_race AS ( -- количество покупателей по расам
	SELECT
    	u.race_id,
    	ppr.all_players,
    	COUNT(DISTINCT u.id) AS paying_players, -- всего 3929
    	ROUND(COUNT(DISTINCT u.id)::numeric/ppr.all_players*100, 2) AS perc_of_paying_players -- %
	FROM fantasy.users AS u
	JOIN players_per_race AS ppr ON u.race_id = ppr.race_id
	WHERE u.payer = 1
	GROUP BY u.race_id, ppr.all_players
),
trans_id_data AS ( -- информация о покупках игроков
	SELECT
		DISTINCT id,
		COUNT(transaction_id) AS count_trans, -- всего покупок
		AVG(amount) AS avg_amount, -- средняя стоимость покупки
		SUM(amount) AS sum_amount -- сумма всех покупок
	FROM fantasy.events
	WHERE amount > 0 -- только реальные покупатели
	GROUP BY id
),
trans_race_data AS ( -- информация о покупках игроков в разрезе расы
	SELECT
		u.race_id,
		COUNT(d.id) AS all_buyers,
		ROUND(AVG(d.count_trans)::numeric, 2) AS avg_count_of_purchase, -- среднее кол-во покупок игрока
		ROUND(AVG(d.avg_amount)::numeric, 2) AS avg_amount_of_purchase, -- средняя стоимость 1 покупки игрока
		ROUND(AVG(d.sum_amount)::numeric, 2) AS avg_sum_of_purchases -- средняя суммарная стоимость всех покупок игрока
		FROM trans_id_data AS d
		JOIN fantasy.users AS u ON d.id = u.id
		GROUP BY u.race_id
)
SELECT
	race,
	all_players,
	paying_players,
	ROUND(paying_players::numeric/all_players*100, 2) AS perc_of_paying_players_all, -- % доля от общего количества зарегистрированных игроков по расе
	ROUND(paying_players::numeric/SUM(paying_players) OVER()*100, 2) AS perc_of_paying_players_buyers, -- % доля от внутриигровых покупок по расе
	avg_count_of_purchase,
	avg_amount_of_purchase,
	avg_sum_of_purchases,
	race
FROM trans_race_data AS d
JOIN paying_players_per_race AS p ON d.race_id = p.race_id
JOIN fantasy.race AS r ON p.race_id = r.race_id; -- названия рас


















-- Draft:

SELECT
	location,
	SUM(u.payer) AS paying_players,
	COUNT(u.id) AS all_players,
	ROUND(SUM(u.payer::numeric)/COUNT(u.id)*100,2) AS perc_of_paying_players
FROM fantasy.users AS u
JOIN fantasy.country AS r ON u.loc_id = r.loc_id
GROUP BY r.location; -- активность по странам

SELECT
    transaction_id,
    game_items,
    amount
FROM fantasy.events
LEFT JOIN fantasy.items USING(item_code)
WHERE game_items = 'Book of Legends'; -- есть завышение цены у id2131772485, id 2131754845, id2137440217 и тд

SELECT
    transaction_id,
    game_items,
    amount
FROM fantasy.events
LEFT JOIN fantasy.items USING(item_code)
WHERE game_items = 'Bag of Holding'; -- есть продажи по 16к, 10к

SELECT
    *,
    game_items
FROM fantasy.events
LEFT JOIN fantasy.items USING(item_code) -- нет таких
WHERE game_items IS NULL;

SELECT
	transaction_id, -- тянут вверх среднее против медианы
	amount
FROM fantasy.events
ORDER BY amount DESC;

SELECT
    c.table_schema,
    c.table_name,
    c.column_name,
    c.data_type,
    k.constraint_name
FROM information_schema.columns AS c
LEFT JOIN information_schema.key_column_usage AS k ON c.table_name = k.table_name
    AND c.column_name = k.column_name AND c.table_schema = k.table_schema
WHERE c.table_schema = 'fantasy' AND c.table_name = 'users';

SELECT *,
    COUNT(id) OVER() AS row_count
FROM fantasy.users
LIMIT 5;

SELECT
    COUNT(*) AS row_count
FROM fantasy.users
WHERE class_id IS NULL OR ch_id IS NULL OR pers_gender IS NULL OR server IS NULL OR race_id IS NULL OR payer IS NULL OR loc_id IS NULL;

SELECT
    DISTINCT server,
    COUNT(id) AS users_count
FROM fantasy.users
GROUP BY server;

SELECT
	c.table_schema,
	c.table_name,
	c.column_name,
	c.data_type,
	k.constraint_name
FROM information_schema.columns AS c
LEFT JOIN information_schema.key_column_usage AS k
	USING(table_name, column_name, table_schema)
WHERE c.table_schema = 'fantasy' AND c.table_name = 'events'
ORDER BY c.table_name;

SELECT *,
    COUNT(id) OVER() AS row_count
FROM fantasy.events
LIMIT 5;

SELECT
    COUNT(*) AS null_count
FROM fantasy.events
WHERE date IS NULL OR time IS NULL OR amount IS NULL OR seller_id IS NULL;

SELECT
    COUNT(date) AS data_count,
    COUNT(time) AS data_time,
    COUNT(amount) AS data_amount,
    COUNT(seller_id) AS data_seller_id
FROM fantasy.events
WHERE date IS NULL
	OR time IS NULL
	OR amount IS NULL
	OR seller_id IS NULL;

SELECT
	location,
    COUNT(loc_id)
FROM fantasy.country
GROUP BY location;

SELECT
	DISTINCT class
FROM fantasy.classes;

SELECT
	DISTINCT race
FROM fantasy.race;

SELECT
	DISTINCT ch_id
FROM fantasy.skills;

SELECT
	DISTINCT item_code
FROM fantasy.items;

SELECT
	DISTINCT id,
	COUNT(transaction_id) OVER(PARTITION BY id)
FROM fantasy.events
WHERE amount > 0
ORDER BY id; -- 00-0037846 сделал 91 покупку

SELECT
	COUNT(id) AS all_players,
	SUM(payer) AS paying_players,
	SUM(payer::numeric)/COUNT(id) AS share_players, -- доля
	ROUND(SUM(payer::numeric)/COUNT(id)*100,2) AS perc_players -- %
FROM fantasy.users;

WITH a AS (
	SELECT
		DISTINCT id,
		COUNT(transaction_id) AS count_trans,
		AVG(amount) AS avg_amount,
		SUM(amount) AS sum_amount
	FROM fantasy.events
	WHERE amount > 0
	GROUP BY id
)
SELECT
	u.race_id,
	COUNT(a.id) AS all_buyers,
	ROUND(AVG(a.count_trans)::numeric, 2) AS avg_trans,
	ROUND(AVG(a.avg_amount)::numeric, 2) AS avg_amount,
	ROUND(AVG(a.sum_amount)::numeric, 2) AS avg_sum_amount
FROM a
JOIN fantasy.users AS u ON a.id = u.id
GROUP BY u.race_id;

players_activity AS (
	SELECT
		DISTINCT race_id
	FROM fantasy.events AS e
	LEFT JOIN fantasy.users AS u ON e.id = u.id
	WHERE amount > 0
	ORDER BY race_id

-- Или врезать из событий все нулевые покупки? И дальше с ней работать
WITH players_per_race AS (
	SELECT
		race_id,
		COUNT(id) AS all_players -- 22214
	FROM fantasy.users
	GROUP BY race_id
	ORDER BY race_id
),
paying_players AS (
	SELECT
		u.race_id,
		ppr.all_players,
		COUNT(u.id) AS paying_players, -- 3929
		ROUND(COUNT(u.id)::numeric/ppr.all_players, 2) AS share_paying_players, -- доля игроков
		ROUND(COUNT(u.id)::numeric/ppr.all_players*100, 2) AS perc_paying_players -- %
	FROM fantasy.users AS u
	JOIN players_per_race AS ppr ON u.race_id = ppr.race_id
	WHERE u.payer = 1
	GROUP BY u.race_id, ppr.all_players
	ORDER BY u.race_id, ppr.all_players
),
players_activity AS (
	SELECT
		DISTINCT race_id,
		COUNT(transaction_id) OVER(PARTITION BY race_id) AS count_transaction,
		ROUND(AVG(amount::numeric) OVER(PARTITION BY race_id), 2) AS avg_amount,
		SUM(amount) OVER(PARTITION BY race_id) AS sum_amount
	FROM fantasy.events AS e
	LEFT JOIN fantasy.users AS u ON e.id = u.id
	WHERE amount > 0
	ORDER BY race_id
)
SELECT *
FROM players_activity;
