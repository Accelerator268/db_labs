--3.1. Сравнение с вычисляемым показателем.
--Счета, баланс которых выше среднего баланса по счетам в той же валюте
SELECT a.account_number,
       a.currency_code,
       a.balance,
       ROUND(avg_by_cur.avg_balance, 2) AS avg_in_currency
FROM accounts a
JOIN (SELECT currency_code, AVG(balance) AS avg_balance
      FROM accounts
      WHERE status <> 'closed'          -- закрытые счета с нулем не портят среднее
      GROUP BY currency_code) avg_by_cur
  ON avg_by_cur.currency_code = a.currency_code
WHERE a.status <> 'closed' AND a.balance > avg_by_cur.avg_balance
ORDER BY a.currency_code, a.balance DESC;


-- 3.2. EXISTS: клиенты, у которых есть хотя бы 1 крупное снятие наличных (от 20 000)
SELECT c.client_id,
       c.last_name || ' ' || c.first_name AS client,
       c.phone
FROM clients c
WHERE EXISTS (
    SELECT 1
    FROM account_holders h
    JOIN transactions t ON t.from_account_id = h.account_id
    WHERE h.client_id = c.client_id AND t.transaction_type = 'withdrawal' AND t.amount >= 20000
)
ORDER BY c.client_id;


--3.3. NOT EXISTS: непогашенные кредиты (active или overdue), по которым не было ни 1 платежа
SELECT l.contract_number,
       l.principal,
       l.issued_at,
       l.status
FROM loans l
WHERE l.status IN ('active', 'overdue') AND NOT EXISTS (
      SELECT 1
      FROM loan_payments p
      WHERE p.loan_id = l.loan_id
  );


-- 3.4. Коррелированный подзапрос: для каждого кредита считаем его собственные показатели:
-- сколько платежей внесено, сколько всего выплачено, какая доля от суммы кредита и когда был последний платеж.
SELECT l.contract_number,
       l.status,
       l.principal,
       (SELECT COUNT(*)
          FROM loan_payments p WHERE p.loan_id = l.loan_id)                  AS payments_count,
       (SELECT COALESCE(SUM(p.amount), 0)
          FROM loan_payments p WHERE p.loan_id = l.loan_id)                  AS paid_total,
       ROUND(100 * (SELECT COALESCE(SUM(p.amount), 0)
          FROM loan_payments p WHERE p.loan_id = l.loan_id) / l.principal, 1) AS paid_percent,
       (SELECT MAX(p.payment_date)
          FROM loan_payments p WHERE p.loan_id = l.loan_id)                  AS last_payment
FROM loans l
ORDER BY l.issued_at;
