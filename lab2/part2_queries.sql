--2.1
--Подробная информация о кредитах: клиент, в каком отделении, отрудник, условия и статус
SELECT l.contract_number,
       c.last_name || ' ' || c.first_name               AS client,
       b.name                                            AS branch,
       COALESCE(e.last_name, '— не указан —')            AS employee,
       l.principal,
       l.interest_rate,
       l.term_months,
       l.issued_at,
       l.status
FROM loans l
JOIN accounts a        ON a.account_id = l.account_id
JOIN account_holders h ON h.account_id = a.account_id AND h.holder_role = 'глава племени'
JOIN clients c         ON c.client_id  = h.client_id
JOIN branches b        ON b.branch_id  = a.branch_id
LEFT JOIN employees e  ON e.employee_id = l.employee_id --сотрудника может не быть
ORDER BY l.issued_at;


--Счета, по которым не было ни одной операции (ни прихода, ни расхода)
SELECT a.account_number,
       c.last_name || ' ' || c.first_name AS owner,
       a.currency_code,
       a.balance,
       a.opened_at
FROM accounts a
JOIN account_holders h ON h.account_id = a.account_id AND h.holder_role = 'глава племени'
JOIN clients c         ON c.client_id  = h.client_id
LEFT JOIN transactions t ON t.from_account_id = a.account_id
                         OR t.to_account_id   = a.account_id
WHERE t.transaction_id IS NULL
ORDER BY a.opened_at;


--Объекты, удовлетворяющие нескольким условиям сразу:
--1. действующие карты (статус active и срок не истек)
--2. привязанные к активному рублевому счету с балансом от 50 000
SELECT c.last_name || ' ' || c.first_name AS card_holder,
       k.card_number,
       k.payment_system,
       k.expiry_date,
       a.account_number,
       a.balance,
       b.name AS branch
FROM cards k
JOIN clients c  ON c.client_id  = k.client_id
JOIN accounts a ON a.account_id = k.account_id
JOIN branches b ON b.branch_id  = a.branch_id
WHERE k.status = 'active'
  AND k.expiry_date > CURRENT_DATE
  AND a.status = 'active'
  AND a.currency_code = 'RUB'
  AND a.balance >= 50000
ORDER BY a.balance DESC;


-- 2.2. Агрегация и группировка
-- Количественные показатели по группам: сколько счетов в каждом отделении и в каком они статусе
SELECT b.name                                         AS branch,
       COUNT(a.account_id)                            AS accounts_total,
       COUNT(a.account_id) FILTER (WHERE a.status = 'active')  AS active,
       COUNT(a.account_id) FILTER (WHERE a.status = 'blocked') AS blocked,
       COUNT(a.account_id) FILTER (WHERE a.status = 'closed')  AS closed,
       COUNT(DISTINCT a.currency_code)                AS currencies
FROM branches b
LEFT JOIN accounts a ON a.branch_id = b.branch_id
GROUP BY b.name
ORDER BY accounts_total DESC;


-- Суммарные и средние показатели с фильтрацией групп: расходы по клиентам только по рублевым счетам
SELECT c.last_name || ' ' || c.first_name AS client,
       COUNT(*)                           AS ops_count,
       SUM(t.amount)                      AS total_spent,
       ROUND(AVG(t.amount), 2)            AS avg_amount,
       MAX(t.amount)                      AS max_amount
FROM transactions t
JOIN accounts a        ON a.account_id = t.from_account_id
JOIN account_holders h ON h.account_id = a.account_id AND h.holder_role = 'глава племени'
JOIN clients c         ON c.client_id  = h.client_id
WHERE a.currency_code = 'RUB'
GROUP BY c.client_id, c.last_name, c.first_name
HAVING SUM(t.amount) > 30000
ORDER BY total_spent DESC;


--Сравнение по временным периодам и категориям:
--1. по каждому месяцу и типу операции — количество, сумма, средняя, мин и макс
--2. Только рублевые операции (валюта определяется по счету, участвующему в операции)
SELECT to_char(date_trunc('month', t.created_at), 'YYYY-MM') AS month,
       t.transaction_type,
       COUNT(*)                AS ops_count,
       SUM(t.amount)           AS total,
       ROUND(AVG(t.amount), 2) AS avg_amount,
       MIN(t.amount)           AS min_amount,
       MAX(t.amount)           AS max_amount
FROM transactions t
JOIN accounts a ON a.account_id = COALESCE(t.from_account_id, t.to_account_id)
WHERE a.currency_code = 'RUB'
GROUP BY month, t.transaction_type
ORDER BY month, t.transaction_type;
