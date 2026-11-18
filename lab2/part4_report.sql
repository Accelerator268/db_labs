-- Вопрос руководителя: "Как работают отделения? Сколько у каждого клиентов,
-- какие денежные потоки идут через его рублевые счета и сколько выдано и возвращено по кредитам?"
--
-- Схема вычислений:
--   transactions, accounts, loans, loan_payments исходные данные
--     flows           каждая операция превращается в приход/расход конкретного счета
--     account_stats   итоги по каждому счету - промежуточные показатели
--     branch_sums     денежные потоки по отделению - агрегация
--     branch_clients  число счетов и клиентов отделения - агрегация
--     loan_paid       сколько выплачено по каждому кредиту - промежуточные показатели
--     branch_loans    кредитный портфель отделения - агрегация
--     итоговый SELECT одна строка на отделение - отчет

-- приходы/уходы с счетов
WITH
flows AS (
    SELECT to_account_id AS account_id, amount AS income, 0 AS outcome
    FROM transactions
    WHERE to_account_id IS NOT NULL
    UNION ALL
    SELECT from_account_id, 0, amount
    FROM transactions
    WHERE from_account_id IS NOT NULL
),

-- итоги по каждому рублевому счету: сколько пришло, ушло и сколько было движений
account_stats AS (
    SELECT a.account_id,
           a.branch_id,
           COUNT(f.account_id)          AS ops_count,
           COALESCE(SUM(f.income), 0)   AS income,
           COALESCE(SUM(f.outcome), 0)  AS outcome
    FROM accounts a
    LEFT JOIN flows f ON f.account_id = a.account_id
    WHERE a.currency_code = 'RUB'
    GROUP BY a.account_id, a.branch_id
),

-- денежные потоки по отделению
branch_sums AS (
    SELECT branch_id,
           SUM(ops_count) AS ops_count,
           SUM(income)    AS income,
           SUM(outcome)   AS outcome
    FROM account_stats
    GROUP BY branch_id
),
-- скольько в отделении счетов и уникальных клиентов
branch_clients AS (
    SELECT s.branch_id,
           COUNT(DISTINCT s.account_id) AS accounts,
           COUNT(DISTINCT h.client_id)  AS clients
    FROM account_stats s
    JOIN account_holders h ON h.account_id = s.account_id
    GROUP BY s.branch_id
),

-- кредитный портфель отделения: сколько выдано и сколько уже вернули

--сколько выплачено по каждому кредиту
loan_paid AS (
    SELECT loan_id, SUM(amount) AS paid
    FROM loan_payments
    GROUP BY loan_id
),
--кредиты отделения
branch_loans AS (
    SELECT a.branch_id,
           COUNT(*)                                AS loans_count,
           COUNT(*) FILTER (WHERE l.status = 'overdue') AS overdue_count,
           SUM(l.principal)                        AS loans_issued,
           SUM(COALESCE(p.paid, 0))                AS loans_paid
    FROM loans l
    JOIN accounts a       ON a.account_id = l.account_id
    LEFT JOIN loan_paid p ON p.loan_id    = l.loan_id
    GROUP BY a.branch_id
)

-- итоговый отчет (типо берем к бранчам присоединяем три говотвых cte по айдишнику)
SELECT b.name                                     AS branch,
       c.clients,
       c.accounts,
       s.ops_count,
       s.income,
       s.outcome,
       s.income - s.outcome                       AS net_flow, --читыйй доход
       COALESCE(l.loans_count, 0)                 AS loans, --кол-во кредитов
       COALESCE(l.overdue_count, 0)               AS overdue_loans, --кол-во просрочек
       COALESCE(l.loans_issued, 0)                AS loans_issued, --сколько выдано в кредит
       COALESCE(l.loans_paid, 0)                  AS loans_paid, --сколько вернули по кредитам
       ROUND(100 * COALESCE(l.loans_paid, 0) / NULLIF(l.loans_issued, 0), 1) AS paid_percent --процент возврата кредитов
FROM branches b
JOIN branch_clients c    ON c.branch_id = b.branch_id
JOIN branch_sums s       ON s.branch_id = b.branch_id
LEFT JOIN branch_loans l ON l.branch_id = b.branch_id
ORDER BY net_flow DESC;
