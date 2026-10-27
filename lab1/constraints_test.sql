--у клиента не указана фамилия
INSERT INTO clients (last_name, first_name, birth_date, passport_series, passport_number, phone)
VALUES (NULL, 'Иван', '1990-01-01', '4599', '999999', '+79001231231');

--валюта RUB уже есть
INSERT INTO currencies (currency_code, name)
VALUES ('RUB', 'Рубль');

--отделение с таким названием уже есть
INSERT INTO branches (name, address, phone)
VALUES ('Центральное отделение', 'г. Москва, ул. Арбат, д. 1', '+74950000001');

--паспорт 4510 123456 уже есть
INSERT INTO clients (last_name, first_name, birth_date, passport_series, passport_number, phone)
VALUES ('Сидоров', 'Олег', '1980-01-01', '4510', '123456', '+79001234567');

--телефон должен начинаться с +
UPDATE clients SET phone = '89213334455' WHERE client_id = 3;

--баланс не может быть отрицательным
UPDATE accounts SET balance = balance - 1000000 WHERE account_id = 1;

--статуса frozen нет среди допустимых
UPDATE accounts SET status = 'frozen' WHERE account_id = 1;

--клиенту меньше 18 лет
INSERT INTO clients (last_name, first_name, birth_date, passport_series, passport_number, phone, registered_at)
VALUES ('Юный', 'Пётр', '2012-05-05', '4530', '000001', '+79001112233', '2025-10-01');

--у пополнения не может быть счёта списания
INSERT INTO transactions (from_account_id, to_account_id, transaction_type, amount)
VALUES (1, 3, 'deposit', 500);

--валюты XYZ нет в справочнике
INSERT INTO accounts (account_number, client_id, branch_id, currency_code, account_type)
VALUES ('40817999100000000097', 1, 1, 'XYZ', 'current');

--нельзя удалить клиента, у которого есть счета
DELETE FROM clients WHERE client_id = 1;

--вместе со счётом удаляются его карты
BEGIN;
INSERT INTO cards (account_id, card_number, holder_name, payment_system, issued_at, expiry_date)
VALUES (8, '2200150000000100', 'RAMIL KHABIBULLIN', 'MIR', '2025-01-01', '2029-01-31');
DELETE FROM transactions WHERE to_account_id = 8 OR from_account_id = 8;
SELECT count(*) AS cards_before FROM cards WHERE account_id = 8;
DELETE FROM accounts WHERE account_id = 8;
SELECT count(*) AS cards_after FROM cards WHERE account_id = 8;
ROLLBACK;

--при удалении сотрудника в его операциях employee_id становится NULL
BEGIN;
DELETE FROM employees WHERE employee_id = 6;
SELECT transaction_id, employee_id FROM transactions WHERE transaction_id IN (7, 8);
ROLLBACK;
