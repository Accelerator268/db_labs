-- INSERT: новый клиент + его счёт + владение счётом + карта + первое пополнение
BEGIN;

INSERT INTO clients (last_name, first_name, middle_name, birth_date, passport_series, passport_number, phone, email, registered_at)
VALUES ('Григорьев', 'Антон', 'Викторович', '1993-02-14', '4522', '300001', '+79160000016', 'grigoriev.a@mail.ru', '2025-07-01');

INSERT INTO accounts (account_number, branch_id, currency_code, account_type, opened_at)
VALUES ('40817810100000000019', 1, 'RUB', 'current', '2025-07-01');

INSERT INTO account_holders (account_id, client_id, holder_role, added_at)
SELECT a.account_id, c.client_id, 'глава племени', '2025-07-01'
FROM accounts a, clients c
WHERE a.account_number = '40817810100000000019'
  AND c.passport_series = '4522' AND c.passport_number = '300001';

INSERT INTO cards (account_id, client_id, card_number, holder_name, payment_system, issued_at, expiry_date)
SELECT account_id, client_id, '2200150000000016', 'ANTON GRIGORIEV', 'MIR', '2025-07-01', '2031-07-31'
FROM account_holders
WHERE account_id = (SELECT account_id FROM accounts WHERE account_number = '40817810100000000019');

INSERT INTO transactions (to_account_id, employee_id, transaction_type, amount, created_at, description)
SELECT account_id, 1, 'deposit', 25000.00, '2025-07-01 12:00:00+03', 'Внесение наличных в кассе'
FROM accounts WHERE account_number = '40817810100000000019';

UPDATE accounts SET balance = balance + 25000.00
WHERE account_number = '40817810100000000019';

COMMIT;

SELECT c.last_name, a.account_number, a.balance, k.card_number
FROM clients c
JOIN account_holders h ON h.client_id = c.client_id
JOIN accounts a        ON a.account_id = h.account_id
JOIN cards k           ON k.account_id = a.account_id
WHERE c.passport_number = '300001';

-- UPDATE одной операции: переводим кредит в просрочку
UPDATE loans SET status = 'overdue'
WHERE contract_number = 'КД-2025-0003';

SELECT contract_number, status FROM loans WHERE contract_number = 'КД-2025-0003';

-- Массовый апдейт: все карты, у которых срок действия уже закончился, переводим в просрочку.
UPDATE cards SET status = 'expired'
WHERE status = 'active' AND expiry_date < CURRENT_DATE;

SELECT card_number, expiry_date, status FROM cards WHERE expiry_date < CURRENT_DATE;


-- DELETE с учётом ограничений целостности.
-- Клиента без счетов удалить можно: на него никто не ссылается.
DELETE FROM clients
WHERE passport_series = '9213' AND passport_number = '200008';

-- Клиента со счётом удалить нельзя: account_holders.client_id ссылается на него с ON DELETE RESTRICT.
-- Эта команда завершится с ошибкой.
DELETE FROM clients
WHERE passport_series = '4510' AND passport_number = '123456';

-- Просроченную карту удалить можно: на карты никто не ссылается.
DELETE FROM cards WHERE card_number = '4276380000000002';

SELECT count(*) AS clients_left FROM clients;


-- ROLLBACK: начинаем транзакцию, обнуляем все балансы, затем отменяем изменения.
BEGIN;

UPDATE accounts SET balance = 0;
SELECT account_id, balance FROM accounts ORDER BY account_id LIMIT 5; -- ограничение на 5, чтоб терминал в космос не улетел

ROLLBACK;

SELECT account_id, balance FROM accounts ORDER BY account_id LIMIT 5;
