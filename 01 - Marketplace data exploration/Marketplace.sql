-- Описание данных проекта
-- Данные лежат в схеме pa_graduate

-- Таблица Users
  -- user_id — уникальный идентификатор пользователя
  -- registration_date — дата регистрации пользователя
  -- user_params — JSON-объект (словарь) с параметрами пользователя: 
    -- age — возраст
    -- gender — пол (M, F)
    -- region — регион
    -- buyer_segment — сегмент покупателя
    -- acq_channel — канал привлечения
        
-- Таблица Orders
  -- order_id — уникальный идентификатор заказа
  -- user_id — идентификатор пользователя, который сделал заказ (внешний ключ на пользователя)
  -- order_date — дата и время оформления заказа
  -- product_id — уникальный идентификатор товара, который был куплен
  -- quantity — количество единиц товара в заказе
  -- unit_price — цена за одну единицу товара на момент заказа
  -- total_price — общая стоимость позиции в заказе (quantity * unit_price)

-- Таблица Product_dict
  -- product_id — уникальный идентификатор товара
  -- category_id — идентификатор категории товара
  -- category_name — название категории товара (например, Аксессуары для гаджетов)
  -- product_name — наименование товара (например, AirPods Pro)

-- Таблица Events
  -- event_id — уникальный идентификатор события
  -- user_id — уникальный идентификатор пользователя
  -- timestamp — время и дата события
  -- event_type — тип события (например, вход пользователя, просмотр страницы, просмотр товара, добавление в корзину)
  -- product_id — идентификатор продукта, к которому относится событие (если применимо)
  -- event_params — JSON-поле с дополнительными параметрами события. Некоторые дополнительные параметры: 
    -- device — тип устройства, на котором произошло событие (например, desktop, mobile, tablet)
    -- os — операционная система (macOS, Windows, iOS, Android и другие)
    -- timestamp — время события в формате ISO (например, "2024-01-11T08:56:27")

-- Таблица Campaigns
  -- acq_channel — канал привлечения (например, Affiliate, Targeted Ads, Email Marketing и др.)
  -- spend_month — месяц, в который был потрачен бюджет, YYYY-MM (отражает период, в котором были привлечены пользователи)
  -- budget — маркетинговый бюджет (в денежном выражении), потраченный на данный канал в указанном месяце

    
-- Сбор данных о пользователях
SELECT
    user_id,
    registration_date,
    user_params->>'age' AS age,
    user_params->>'gender' AS gender,
    user_params->>'region' AS region,
    user_params->>'acq_channel' AS acq_channel,
    user_params->>'buyer_segment' AS buyer_segment,
    DATE_TRUNC('week', registration_date)::date AS cohort_week,
    DATE_TRUNC('month', registration_date)::date AS cohort_month
FROM pa_graduate.Users
WHERE registration_date >= '2024-01-01' AND registration_date < '2025-01-01'
ORDER BY registration_date;

-- Сбор данных о событиях
SELECT
    event_id,
    user_id,
    timestamp AS event_date,
    event_type,
    event_params->>'os' AS os,
    event_params->>'device' AS device_type,
    product_name AS product_name,
    DATE_TRUNC('week', timestamp)::date AS event_week,
    DATE_TRUNC('month', timestamp)::date AS event_month
FROM pa_graduate.Events AS e
LEFT JOIN pa_graduate.Product_dict AS p USING(product_id)
WHERE timestamp >= '2024-01-01' AND timestamp < '2025-01-01'
ORDER BY event_date;

-- Сбор данных о заказах
SELECT
    o.order_id,
    o.user_id,
    o.order_date,
    p.product_name,
    o.quantity,
    o.unit_price,
    o.total_price,
    p.category_name,
    DATE_TRUNC('week', o.order_date)::date AS order_week,
    DATE_TRUNC('month', o.order_date)::date AS order_month
FROM pa_graduate.Orders AS o
LEFT JOIN pa_graduate.Product_dict AS p USING(product_id)
WHERE o.order_date >= '2024-01-01' AND o.order_date < '2025-01-01'
ORDER BY o.order_date ASC;
