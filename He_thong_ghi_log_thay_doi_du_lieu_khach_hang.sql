CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(20),
    address TEXT
);

CREATE TABLE customers_log (
    log_id SERIAL PRIMARY KEY,
    customer_id INT,
    operation VARCHAR(10),
    old_data JSONB,
    new_data JSONB,
    changed_by VARCHAR(100),
    change_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION fn_trg_log()
RETURNS trigger AS
    $$
    BEGIN
        IF (TG_OP = 'INSERT') THEN
            INSERT INTO customers_log (customer_id, operation, new_data, changed_by)
            VALUES (NEW.id, 'INSERT', to_jsonb(NEW), current_user);
            RETURN NEW;

        ELSIF (TG_OP = 'UPDATE') THEN
            INSERT INTO customers_log (customer_id, operation, old_data, new_data, changed_by)
            VALUES (OLD.id, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW), current_user);
            RETURN NEW;

        ELSIF (TG_OP = 'DELETE') THEN
            INSERT INTO customers_log (customer_id, operation, old_data, changed_by)
            VALUES (OLD.id, 'DELETE', to_jsonb(OLD), current_user);
            RETURN OLD;
        END IF;

        RETURN NULL;
    end;
    $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_customers_log
AFTER INSERT OR UPDATE OR DELETE ON customers
FOR EACH ROW
EXECUTE FUNCTION fn_trg_log();

INSERT INTO customers (name, email, phone, address)
VALUES ('Nguyễn Văn A', 'vana@gmail.com', '0901234567', 'Hà Nội');

UPDATE customers
SET phone = '0999888777', address = 'TP. Hồ Chí Minh'
WHERE name = 'Nguyễn Văn A';

DELETE FROM customers WHERE id = 1;

SELECT * FROM customers_log ORDER BY change_time DESC;
