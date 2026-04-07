CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    credit_limit DECIMAL(15, 2) DEFAULT 0
);

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customers(id),
    order_amount DECIMAL(15, 2) NOT NULL
);

INSERT INTO customers (name, credit_limit)
VALUES ('Công ty A', 5000000),
    ('Anh Bình', 1000000);

CREATE OR REPLACE FUNCTION check_credit_limit()
    RETURNS TRIGGER AS $$
DECLARE
    v_current_total_orders DECIMAL(15, 2);
    v_credit_limit DECIMAL(15, 2);
BEGIN
    SELECT credit_limit INTO v_credit_limit
    FROM customers
    WHERE id = NEW.customer_id;

    SELECT SUM(order_amount) INTO v_current_total_orders
    FROM orders
    WHERE customer_id = NEW.customer_id;

    IF (v_current_total_orders + NEW.order_amount) > v_credit_limit THEN
        RAISE EXCEPTION 'Giao dịch bị từ chối! Tổng đơn hàng (%) vượt quá hạn mức tín dụng của khách hàng (%)',
            (v_current_total_orders + NEW.order_amount), v_credit_limit;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_credit
BEFORE INSERT ON orders
FOR EACH ROW
EXECUTE FUNCTION check_credit_limit();

INSERT INTO orders (customer_id, order_amount)
VALUES (2, 400000);

INSERT INTO orders (customer_id, order_amount)
VALUES (2, 500000);

INSERT INTO orders (customer_id, order_amount)
VALUES (2, 200000);
