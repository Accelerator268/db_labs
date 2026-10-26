DROP TABLE IF EXISTS loan_payments CASCADE;
DROP TABLE IF EXISTS loans         CASCADE;
DROP TABLE IF EXISTS transactions  CASCADE;
DROP TABLE IF EXISTS cards         CASCADE;
DROP TABLE IF EXISTS accounts      CASCADE;
DROP TABLE IF EXISTS currencies    CASCADE;
DROP TABLE IF EXISTS clients       CASCADE;
DROP TABLE IF EXISTS employees     CASCADE;
DROP TABLE IF EXISTS branches      CASCADE;

--отделения
CREATE TABLE branches (
    branch_id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    address     VARCHAR(255) NOT NULL,
    phone       VARCHAR(20)  NOT NULL,

    CONSTRAINT branches_name_uq   UNIQUE (name), --название уникальное
    CONSTRAINT branches_phone_chk CHECK (phone ~ '^\+[0-9]{11,15}$') --от 11 до 15 цифр в телефоне
);

--сотрудники
CREATE TABLE employees (
    employee_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    branch_id   INTEGER REFERENCES branches (branch_id) ON DELETE SET NULL,
    last_name   VARCHAR(50)   NOT NULL,
    first_name  VARCHAR(50)   NOT NULL,
    middle_name VARCHAR(50), --отчество может и не быть
    position    VARCHAR(100)  NOT NULL,
    email       VARCHAR(100)  NOT NULL,
    hire_date   DATE          NOT NULL DEFAULT CURRENT_DATE,
    salary      NUMERIC(12,2) NOT NULL,

    CONSTRAINT employees_email_uq   UNIQUE (email),--почта уникальная
    CONSTRAINT employees_salary_chk CHECK (salary > 0) --зп положительная
);

--клиенты
CREATE TABLE clients (
    client_id       INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    last_name       VARCHAR(50)  NOT NULL,
    first_name      VARCHAR(50)  NOT NULL,
    middle_name     VARCHAR(50), --отчество не обязательно
    birth_date      DATE         NOT NULL,
    passport_series CHAR(4)      NOT NULL, --серия паспорта = 4 цифры
    passport_number CHAR(6)      NOT NULL, --номер паспорта = 6 цифр
    phone           VARCHAR(20)  NOT NULL,
    email           VARCHAR(100),
    registered_at   DATE         NOT NULL DEFAULT CURRENT_DATE, --дата реги в банке, дефолт = сегодня

    --составное ограничение: паспорт уникален только как пара серия + номер (это гениально?)
    CONSTRAINT clients_passport_uq   UNIQUE (passport_series, passport_number),
    CONSTRAINT clients_email_uq      UNIQUE (email),
    CONSTRAINT clients_passport_chk  CHECK (passport_series ~ '^[0-9]{4}$'   --серия 4 цифры
                                        AND passport_number ~ '^[0-9]{6}$'), --номер 6 цифр
    CONSTRAINT clients_phone_chk     CHECK (phone ~ '^\+[0-9]{11,15}$'), --формат телефона
    CONSTRAINT clients_adult_chk     CHECK (birth_date <= registered_at - INTERVAL '18 years') --совершеннолетие
);

--справочник валют
CREATE TABLE currencies (
    currency_code CHAR(3)     PRIMARY KEY,
    name          VARCHAR(50) NOT NULL,

    CONSTRAINT currencies_code_chk CHECK (currency_code ~ '^[A-Z]{3}$') --код в три заглавные латинские буквы
);

--счета клиентов
CREATE TABLE accounts (
    account_id     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_number CHAR(20)      NOT NULL, --20 символьный номер счета строкой
    client_id      INTEGER       NOT NULL REFERENCES clients (client_id)        ON DELETE RESTRICT, --владелец, удалять низя
    branch_id      INTEGER       NOT NULL REFERENCES branches (branch_id)       ON DELETE RESTRICT,
    currency_code  CHAR(3)       NOT NULL REFERENCES currencies (currency_code) ON DELETE RESTRICT,
    account_type   VARCHAR(10)   NOT NULL,
    balance        NUMERIC(15,2) NOT NULL DEFAULT 0, --баланс, по дефолту ноль
    status         VARCHAR(10)   NOT NULL DEFAULT 'active', --состояние, по дефолту активен
    opened_at      DATE          NOT NULL DEFAULT CURRENT_DATE, --дата открытия, по дефолту сегодня
    closed_at      DATE, --дата закрытия, NULL пока счет открыт

    CONSTRAINT accounts_number_uq   UNIQUE (account_number), --номер счета уникален
    CONSTRAINT accounts_number_chk  CHECK (account_number ~ '^[0-9]{20}$'), --номер ровно 20 цифр
    CONSTRAINT accounts_type_chk    CHECK (account_type IN ('current', 'savings')), --текущий или сберегательный
    CONSTRAINT accounts_balance_chk CHECK (balance >= 0), --уйти в минус пл балансу нельзя
    CONSTRAINT accounts_status_chk  CHECK (status IN ('active', 'blocked', 'closed')), --статусы счета
    CONSTRAINT accounts_dates_chk   CHECK (closed_at IS NULL OR closed_at >= opened_at), --закрыт не раньше, чем открыт
    CONSTRAINT accounts_closed_chk  CHECK ((status = 'closed') = (closed_at IS NOT NULL)) -- 'closed' = дата закрытия задана
);

--банковские карты.
CREATE TABLE cards (
    card_id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id      INTEGER     NOT NULL REFERENCES accounts (account_id) ON DELETE CASCADE, --счет карты; удаление счета = удалились карты
    card_number     CHAR(16)    NOT NULL,
    holder_name     VARCHAR(50) NOT NULL,
    payment_system  VARCHAR(10) NOT NULL,
    issued_at       DATE        NOT NULL DEFAULT CURRENT_DATE,
    expiry_date     DATE        NOT NULL,
    status          VARCHAR(10) NOT NULL DEFAULT 'active',

    CONSTRAINT cards_number_uq   UNIQUE (card_number),
    CONSTRAINT cards_number_chk  CHECK (card_number ~ '^[0-9]{16}$'),
    CONSTRAINT cards_system_chk  CHECK (payment_system IN ('MIR', 'VISA', 'MASTERCARD')),
    CONSTRAINT cards_status_chk  CHECK (status IN ('active', 'blocked', 'expired')),
    CONSTRAINT cards_dates_chk   CHECK (expiry_date > issued_at)
);

--операции по счетам
CREATE TABLE transactions (
    transaction_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- BIGINT, операция дохуя может быть
    from_account_id  INTEGER REFERENCES accounts (account_id)   ON DELETE RESTRICT,
    to_account_id    INTEGER REFERENCES accounts (account_id)   ON DELETE RESTRICT,
    employee_id      INTEGER REFERENCES employees (employee_id) ON DELETE SET NULL, --кто оформил; NULL = банкомат/онлайн
    transaction_type VARCHAR(10)   NOT NULL,
    amount           NUMERIC(15,2) NOT NULL,
    created_at       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    description      VARCHAR(255),

    CONSTRAINT transactions_amount_chk CHECK (amount > 0),
    CONSTRAINT transactions_self_chk   CHECK (from_account_id <> to_account_id),
    CONSTRAINT transactions_type_chk   CHECK (
           (transaction_type = 'deposit'    AND from_account_id IS NULL     AND to_account_id IS NOT NULL) --пополнение, только "куда"
        OR (transaction_type = 'withdrawal' AND from_account_id IS NOT NULL AND to_account_id IS NULL)     --снятие, только "откуда"
        OR (transaction_type = 'transfer'   AND from_account_id IS NOT NULL AND to_account_id IS NOT NULL) --перевод, оба счета
    )
);

--кредиты (деп, додеп, ласт додеп, ултра ласт додеп)
CREATE TABLE loans (
    loan_id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    contract_number VARCHAR(20)   NOT NULL,
    account_id      INTEGER       NOT NULL REFERENCES accounts (account_id)   ON DELETE RESTRICT,
    employee_id     INTEGER       REFERENCES employees (employee_id)          ON DELETE SET NULL,
    principal       NUMERIC(15,2) NOT NULL,
    interest_rate   NUMERIC(5,2)  NOT NULL,
    term_months     SMALLINT      NOT NULL,
    issued_at       DATE          NOT NULL DEFAULT CURRENT_DATE,
    status          VARCHAR(10)   NOT NULL DEFAULT 'active',

    CONSTRAINT loans_contract_uq   UNIQUE (contract_number),
    CONSTRAINT loans_principal_chk CHECK (principal > 0),
    CONSTRAINT loans_rate_chk      CHECK (interest_rate > 0 AND interest_rate <= 100),
    CONSTRAINT loans_term_chk      CHECK (term_months BETWEEN 1 AND 360),
    CONSTRAINT loans_status_chk    CHECK (status IN ('active', 'paid', 'overdue'))
);

--платежи по кредитам
CREATE TABLE loan_payments (
    payment_id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    loan_id      INTEGER       NOT NULL REFERENCES loans (loan_id) ON DELETE RESTRICT, --связь с кредитом
    payment_date DATE          NOT NULL DEFAULT CURRENT_DATE,
    amount       NUMERIC(15,2) NOT NULL,

    CONSTRAINT loan_payments_day_uq     UNIQUE (loan_id, payment_date), --один платеж по кредиту в один день
    CONSTRAINT loan_payments_amount_chk CHECK (amount > 0)
);

--индексы на внешние ключи (PostgreSQL не создает их автоматически)
CREATE INDEX accounts_client_idx      ON accounts (client_id); --быстрый поиск счетов клиента
CREATE INDEX cards_account_idx        ON cards (account_id); --быстрый поиск карт счета
CREATE INDEX transactions_from_idx    ON transactions (from_account_id); --выписка: списания по счету
CREATE INDEX transactions_to_idx      ON transactions (to_account_id); --выписка: зачисления на счет
CREATE INDEX loans_account_idx        ON loans (account_id); --кредиты, привязанные к счету
