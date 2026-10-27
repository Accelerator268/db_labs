--на один счет несколько владельцев (например, семейный счет)
BEGIN;

CREATE TABLE account_holders (
    account_id  INTEGER     NOT NULL REFERENCES accounts (account_id) ON DELETE CASCADE,
    client_id   INTEGER     NOT NULL REFERENCES clients (client_id)   ON DELETE RESTRICT,
    holder_role VARCHAR(15) NOT NULL DEFAULT 'соплеменник',
    added_at    DATE        NOT NULL DEFAULT CURRENT_DATE,

    CONSTRAINT account_holders_pk       PRIMARY KEY (account_id, client_id),
    CONSTRAINT account_holders_role_chk CHECK (holder_role IN ('глава племени', 'соплеменник'))
);

INSERT INTO account_holders (account_id, client_id, holder_role, added_at)
SELECT account_id, client_id, 'глава племени', opened_at
FROM accounts;

ALTER TABLE cards ADD COLUMN client_id INTEGER;

UPDATE cards c
SET client_id = a.client_id
FROM accounts a
WHERE a.account_id = c.account_id;

ALTER TABLE cards ALTER COLUMN client_id SET NOT NULL;

ALTER TABLE cards
    ADD CONSTRAINT cards_holder_fk FOREIGN KEY (account_id, client_id)
        REFERENCES account_holders (account_id, client_id) ON DELETE CASCADE;

ALTER TABLE cards DROP CONSTRAINT cards_account_id_fkey;

DROP INDEX accounts_client_idx;
ALTER TABLE accounts DROP COLUMN client_id;

COMMIT;
