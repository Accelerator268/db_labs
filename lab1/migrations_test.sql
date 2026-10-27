BEGIN;
INSERT INTO account_holders (account_id, client_id) VALUES (3, 3);
SELECT account_id, client_id, holder_role FROM account_holders WHERE account_id = 3;
ROLLBACK;
