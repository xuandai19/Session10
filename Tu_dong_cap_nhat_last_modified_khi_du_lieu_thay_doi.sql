CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    price DECIMAL(15, 2) NOT NULL,
    last_modified TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION update_last_modified()
RETURNS TRIGGER AS $$
    BEGIN
        NEW.last_modified = CURRENT_TIMESTAMP;
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_last_modified
BEFORE UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION update_last_modified();

INSERT INTO products (name, price)
VALUES ('Chuột Gaming Logitech', 500000),
    ('Bàn phím cơ Razer', 2500000);

SELECT * FROM products;

UPDATE products
SET price = 600000
WHERE name = 'Chuột Gaming Logitech'

SELECT * FROM products;
