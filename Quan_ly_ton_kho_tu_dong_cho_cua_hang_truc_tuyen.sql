CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255),
    stock INT
);

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    product_id INT REFERENCES products(id),
    quantity INT,
    order_status VARCHAR(100)
);

INSERT INTO products (name, stock)
VALUES ('Laptop Dell XPS 15', 10),
    ('iPhone 15 Pro', 25),
    ('Bàn phím cơ Akko', 50),
    ('Chuột Logitech MX Master 3S', 15),
    ('Màn hình LG 27 inch 4K', 8);

CREATE OR REPLACE FUNCTION trg_order_before_insert()
RETURNS trigger AS
    $$
    DECLARE v_stock INT;
    BEGIN
        SELECT stock INTO v_stock
        FROM products
        WHERE id = NEW.product_id;
        IF v_stock < NEW.quantity THEN
            RAISE EXCEPTION 'Không đủ số lượng tồn kho';
        end if;

        UPDATE products
        SET stock = stock - NEW.quantity
        WHERE id = NEW.product_id;

        RETURN NEW;
    end;
    $$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_insert_order
BEFORE INSERT ON orders
FOR EACH ROW
EXECUTE FUNCTION trg_order_before_insert();

INSERT INTO orders (product_id, quantity, order_status)
VALUES (1, 1, 'Completed'),
       (2, 2, 'Processing'),
       (3, 5, 'Shipped'),
       (5, 1, 'Pending'),
       (4, 3, 'Cancelled');

CREATE OR REPLACE FUNCTION fn_trg_before_update()
RETURNS TRIGGER AS $$
    DECLARE
        v_change_quantity INT;
        v_stock INT;
    BEGIN
        SELECT stock INTO v_stock
        FROM products
        WHERE id = NEW.product_id;
        IF (NEW.quantity > OLD.quantity) THEN
            v_change_quantity := NEW.quantity - OLD.quantity;
            IF (v_change_quantity > v_stock) THEN
                RAISE EXCEPTION 'Không đủ số luọng';
            end if;

            UPDATE products
            SET stock = stock - v_change_quantity
            WHERE id = NEW.product_id;
        ELSE
            v_change_quantity := OLD.quantity - NEW.quantity;

            UPDATE products
            SET stock = stock + v_change_quantity
            WHERE id = NEW.product_id;
        end if;

        IF OLD.order_status <> 'Cancelled' THEN
            UPDATE products
            SET stock = stock + OLD.quantity
            WHERE id = OLD.product_id;
        END IF;
        RETURN NEW;
    end;
    $$ LANGUAGE plpgsql;
CREATE OR REPLACE TRIGGER trg_before_update_order
BEFORE UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION fn_trg_before_update();

UPDATE orders
SET quantity = 7
WHERE id = 1;

UPDATE orders
SET order_status = 'Cancelled'
WHERE id = 1;
