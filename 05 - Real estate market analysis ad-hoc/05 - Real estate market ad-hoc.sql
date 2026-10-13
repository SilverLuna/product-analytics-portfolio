-- Задача 1: Время активности объявлений

-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY f.total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY f.rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY f.balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY f.ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY f.ceiling_height) AS ceiling_height_limit_l,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY a.last_price) AS last_price_limit_h, -- Выброс цен: 99 - 36000000, а MAX - 763000000
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY a.last_price) AS last_price_limit_l -- MIN 12190 - это странно
    FROM real_estate.flats AS f
    LEFT JOIN real_estate.advertisement AS a ON f.id = a.id
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT f.id
    FROM real_estate.flats AS f
    LEFT JOIN real_estate.advertisement AS a ON f.id = a.id
    WHERE
        f.total_area < (SELECT total_area_limit FROM limits)
        AND (f.rooms < (SELECT rooms_limit FROM limits) OR f.rooms IS NULL)
        AND (f.balcony < (SELECT balcony_limit FROM limits) OR f.balcony IS NULL)
        AND ((f.ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
        	AND f.ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR f.ceiling_height IS NULL)
        AND ((a.last_price < (SELECT last_price_limit_h FROM limits)
        	AND a.last_price > (SELECT last_price_limit_l FROM limits)) OR a.last_price IS NULL)
),
-- Добавление категорий:
category AS (
	SELECT
		f.id,
    	a.first_day_exposition,
    	a.days_exposition,
    	a.last_price,
    	c.city,
    	t.type,
    	f.total_area,
    	f.rooms,
    	f.ceiling_height,
    	f.floors_total,
    	f.floor,
    	f.is_apartment,
    	f.open_plan,
    	f.balcony,
    	f.airports_nearest,
    	f.parks_around3000,
    	f.ponds_around3000,
   		CASE
			WHEN a.days_exposition BETWEEN 1 AND 30 THEN 'до месяца'
      		WHEN a.days_exposition BETWEEN 31 AND 90 THEN 'до трёх месяцев'
      		WHEN a.days_exposition BETWEEN 91 AND 180 THEN 'до шести месяцев'
      		WHEN a.days_exposition > 180 THEN 'от полугода'
      		ELSE 'non_category'
    	END AS activity,
    	CASE
			WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
      		WHEN c.city != 'Санкт-Петербург' THEN 'Ленинградская область'
      		ELSE 'non_category'
    	END AS region,
    	ROUND(a.last_price::numeric/f.total_area::numeric, 0) AS cost_m
	FROM real_estate.flats AS f
	LEFT JOIN real_estate.advertisement AS a ON f.id = a.id
	LEFT JOIN real_estate.city AS c ON f.city_id = c.city_id
	LEFT JOIN real_estate.type AS t ON f.type_id = t.type_id
	WHERE f.id IN (SELECT * FROM filtered_id) AND t.type = 'город'
)
SELECT
	region AS region,
	activity AS activity,
	COUNT(id) AS count_adv,
	ROUND(COUNT(id)/SUM(COUNT(id)) OVER(PARTITION BY region), 3) * 100 AS count_adv_part, -- %
	-- ROUND(SUM(is_apartment)/COUNT(id::numeric), 4)*100 AS Из_них_апарт, -- Незначительно (апартов и до фильтрации 50)
	-- ROUND(SUM(open_plan)/COUNT(id::numeric), 4)*100 AS Из_них_студ, -- Незначительно (апартов и до фильтрации 67)
	ROUND(AVG(cost_m), 0) AS avg_sq_m,
	ROUND(AVG(total_area::numeric), 2) AS avg_space,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS median_rooms,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS median_balcony,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor) AS median_floor,
	ROUND(AVG(ceiling_height::numeric), 2) AS avg_ceiling,
	ROUND(AVG(airports_nearest::numeric)/1000, 0) AS avg_air, -- В км
	ROUND(AVG(parks_around3000::numeric), 2) AS avg_parks,
	ROUND(AVG(ponds_around3000::numeric), 2) AS avg_ponds,
	region AS region
FROM category
WHERE first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31' -- Всего 13849 после фильтраций (лимиты, тип, время), было 23650
GROUP BY region, activity
ORDER BY region DESC, activity;


-- Задача 2: Сезонность объявлений

WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY f.total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY f.rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY f.balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY f.ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY f.ceiling_height) AS ceiling_height_limit_l,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY a.last_price) AS last_price_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY a.last_price) AS last_price_limit_l
    FROM real_estate.flats AS f
    LEFT JOIN real_estate.advertisement AS a ON f.id = a.id
),
filtered_id AS(
    SELECT f.id
    FROM real_estate.flats AS f
    LEFT JOIN real_estate.advertisement AS a ON f.id = a.id
    WHERE
        f.total_area < (SELECT total_area_limit FROM limits)
        AND (f.rooms < (SELECT rooms_limit FROM limits) OR f.rooms IS NULL)
        AND (f.balcony < (SELECT balcony_limit FROM limits) OR f.balcony IS NULL)
        AND ((f.ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
          AND f.ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR f.ceiling_height IS NULL)
        AND ((a.last_price < (SELECT last_price_limit_h FROM limits)
          AND a.last_price > (SELECT last_price_limit_l FROM limits)) OR a.last_price IS NULL)
),
-- Месяцы публикации и снятия:
base AS (
	SELECT
		a.id,
    	a.first_day_exposition, -- Дата публикации
    	(a.first_day_exposition + a.days_exposition * INTERVAL '1 day')::date AS last_day_exposition, -- Дата снятия
    	a.days_exposition,
    	EXTRACT (month FROM a.first_day_exposition) AS start_month, -- Месяц публикации
    	EXTRACT (month FROM (a.first_day_exposition + a.days_exposition * INTERVAL '1 day')::date) AS end_month, -- Месяц снятия
    	a.last_price,
    	f.total_area,
    	ROUND(a.last_price::numeric/f.total_area::numeric, 0) AS cost_m
  	FROM real_estate.flats AS f
  	LEFT JOIN real_estate.advertisement AS a ON f.id = a.id
  	LEFT JOIN real_estate.city AS c ON f.city_id = c.city_id
  	LEFT JOIN real_estate.type AS t ON f.type_id = t.type_id
  	WHERE f.id IN (SELECT * FROM filtered_id) AND t.type = 'город' -- Только тип город
   		AND first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31' -- Только целые годы, null значения оставила
),
start_exp AS (
	SELECT
		start_month,
		COUNT(id) AS start_adv_count,
		ROUND(AVG(cost_m::numeric), 0) AS start_avg_meter,
		ROUND(AVG(total_area::numeric), 2) AS start_avg_area
	FROM base
	GROUP BY start_month
	ORDER BY start_month ASC -- Публикация
),
end_exp AS (
	SELECT
		end_month,
		COUNT(id) AS end_adv_count,
		ROUND(AVG(cost_m::numeric), 0) AS end_avg_meter,
		ROUND(AVG(total_area::numeric), 2) AS end_avg_area
	FROM base
	GROUP BY end_month
	ORDER BY end_month ASC -- Снятие объявления с публикации
)
SELECT
	TO_CHAR(MAKE_DATE(2024, s.start_month::int, 1), 'FMMon') AS month, -- Пришлось так, first_day_exposition нет в таблице
	s.start_adv_count AS count_post,
	RANK() OVER(ORDER BY s.start_adv_count DESC) AS count_post_rank, -- Ранг пубоикаций
	ROUND(s.start_adv_count/SUM(s.start_adv_count) OVER(), 3) * 100 AS count_post_part, -- %
	e.end_adv_count AS count_drop,
	RANK() OVER(ORDER BY e.end_adv_count DESC) AS count_drop_rank, -- Ранг снятий
	ROUND(e.end_adv_count/SUM(e.end_adv_count) OVER(), 3) * 100 AS count_drop_part, -- %
	s.start_avg_meter AS avg_post_sq_m,
	s.start_avg_area AS avg_post_space,
	e.end_avg_meter AS avg_drop_sq_m,
	e.end_avg_area AS avg_drop_space,
	TO_CHAR(MAKE_DATE(2024, s.start_month::int, 1), 'FMMon') AS month
FROM start_exp AS s
LEFT JOIN end_exp AS e ON s.start_month = e.end_month
ORDER BY s.start_month ASC;











-- Draft

SELECT COUNT(*)
FROM real_estate.advertisement; -- 23650

SELECT COUNT(*)
FROM real_estate.flats; -- 23650

SELECT COUNT(*)
FROM real_estate.type; -- 10

SELECT COUNT(*)
FROM real_estate.city; -- 305

SELECT *
FROM real_estate.advertisement
LIMIT 10;

SELECT *
FROM real_estate.flats
LIMIT 10;

SELECT *
FROM real_estate.type
LIMIT 10;

SELECT *
FROM real_estate.city
LIMIT 10;

SELECT *
FROM real_estate.city
WHERE city.city = 'Санкт-Петербург'; -- 6X8I

SELECT COUNT(f.city_id)
FROM real_estate.flats AS f;

SELECT COUNT(a.id)
FROM real_estate.advertisement AS a;

SELECT COUNT(DISTINCT a.id)
FROM real_estate.advertisement AS a;

SELECT
	is_apartment,
	COUNT(*)
FROM real_estate.flats
GROUP BY is_apartment; -- Апарты

SELECT
	open_plan,
	COUNT(*)
FROM real_estate.flats
GROUP BY open_plan; -- Студии

SELECT
	MAX(f.ceiling_height), -- 100
	MIN(f.ceiling_height), -- 1
	AVG(f.ceiling_height), -- 2,77
	MAX(f.total_area), -- 900
	MIN(f.total_area), -- 12
	AVG(f.total_area) -- 60,32
FROM real_estate.flats AS f;

SELECT
	MIN(a.first_day_exposition), -- 2014-11-27
	MAX(a.first_day_exposition) -- 2019-05-03
FROM real_estate.advertisement AS a;

SELECT
	t.type,
	COUNT(DISTINCT f.city_id),
	COUNT(f.id)
FROM real_estate.advertisement AS a
LEFT JOIN real_estate.flats AS f ON a.id = f.id
LEFT JOIN real_estate.type AS t ON f.type_id = t.type_id
GROUP BY t.type;

SELECT
	MAX(a.days_exposition), -- 1580
	MIN(a.days_exposition), -- 1
	ROUND(AVG(a.days_exposition::numeric), 2), -- 180,75
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY a.days_exposition) -- 95
FROM real_estate.advertisement AS a;

SELECT
	ROUND(SUM(CASE WHEN a.days_exposition >= 1 THEN 1 ELSE 0 END)::numeric/COUNT(a.id), 4)*100 -- 86,55
FROM real_estate.advertisement AS a;

SELECT
	ROUND(SUM(CASE WHEN c.city = 'Санкт-Петербург' THEN 1 ELSE 0 END)::numeric/COUNT(a.id), 4)*100
FROM real_estate.advertisement AS a
LEFT JOIN real_estate.flats AS f ON a.id = f.id
LEFT JOIN real_estate.city AS c ON f.city_id = c.city_id; -- 66,47

WITH cost_of_sq_m AS (
	SELECT
		a.id,
		a.last_price/f.total_area AS cost_m
	FROM real_estate.advertisement AS a
	LEFT JOIN real_estate.flats AS f ON a.id = f.id
)
SELECT
	MIN(m.cost_m), -- 111,83
	MAX(m.cost_m), -- 1907500
	AVG(m.cost_m), -- 99432,24
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY m.cost_m) -- 95000
FROM real_estate.advertisement AS a
LEFT JOIN cost_of_sq_m AS m ON a.id = m.id;

SELECT
	MAX(a.total_area), -- 900
	MIN(a.total_area), -- 12
	ROUND(AVG(a.total_area::numeric), 2), -- 60,33
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY a.total_area), -- 52
	PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY a.total_area), -- 197,56
	MAX(a.rooms), -- 19
	MIN(a.rooms), -- 0
	ROUND(AVG(a.rooms::numeric), 2), -- 2,07
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY a.rooms), -- 2
	PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY a.rooms), -- 5
	MAX(a.balcony), -- 5
	MIN(a.balcony), -- 0
	ROUND(AVG(a.balcony::numeric), 2), -- 1,15
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY a.balcony), -- 1
	PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY a.balcony), -- 5
	MAX(a.ceiling_height), -- 100
	MIN(a.ceiling_height), -- 1
	ROUND(AVG(a.ceiling_height::numeric), 2), -- 2,77
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY a.ceiling_height), -- 2,65
	PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY a.ceiling_height), -- 3,82
	MAX(a.floor), -- 33
	MIN(a.floor), -- 1
	ROUND(AVG(a.floor::numeric), 2), -- 5,89
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY a.floor), -- 4
	PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY a.floor) -- 23
FROM real_estate.flats AS a;

SELECT
	MAX(a.last_price), -- 763000000
	MIN(a.last_price), -- 12190
	ROUND(AVG(a.last_price::numeric), 2), -- 6541127
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY a.last_price), -- 4650000
	PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY a.last_price) -- 36000000
FROM real_estate.advertisement AS a;

-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )

-- Выведем объявления без выбросов:
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id)
,
start_exp AS (
	SELECT
		start_month,
		COUNT(id) AS start_adv_count
	FROM base
	GROUP BY start_month
	ORDER BY start_month ASC
),
end_exp AS (
	SELECT
		end_month,
		COUNT(id) AS end_adv_count
	FROM base
	GROUP BY end_month
	ORDER BY end_month ASC
)
SELECT
	b.start_month,
	s.start_adv_count,
	e.end_adv_count
FROM base AS b
LEFT JOIN start_exp AS s ON b.start_month = s.start_month
LEFT JOIN end_exp AS e ON b.end_month = e.end_month;
