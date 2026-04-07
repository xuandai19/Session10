CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255),
    stock INT DEFAULT 0
);

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    product_id INT REFERENCES products(id),
    quantity INT
);

INSERT INTO products (name, stock)
VALUES ('Laptop Dell', 10), ('iPhone 15', 20);

CREATE OR REPLACE FUNCTION fn_update_inventory()
    RETURNS TRIGGER AS $$
    DECLARE
        v_diff INT := OLD.quantity - NEW.quantity;
        v_current_stock INT;
BEGIN
    IF (TG_OP = 'INSERT') THEN
        IF (SELECT stock FROM products WHERE id = NEW.product_id) < NEW.quantity THEN
            RAISE EXCEPTION 'Không đủ hàng trong kho cho sản phẩm ID %', NEW.product_id;
        END IF;
        UPDATE products
        SET stock = stock - NEW.quantity
        WHERE id = NEW.product_id;
        RETURN NEW;

    ELSIF (TG_OP = 'UPDATE') THEN
        BEGIN
            IF v_diff < 0 THEN
                SELECT stock INTO v_current_stock FROM products WHERE id = NEW.product_id;
                IF v_current_stock < v_diff THEN
                    RAISE EXCEPTION 'Kho không đủ hàng để tăng số lượng đơn hàng';
                END IF;
            END IF;
            UPDATE products
            SET stock = stock + v_diff
            WHERE id = NEW.product_id;
        END;
        RETURN NEW;

    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE products
        SET stock = stock + OLD.quantity
        WHERE id = OLD.product_id;
        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_inventory_control
AFTER INSERT OR UPDATE OR DELETE ON orders
FOR EACH ROW
EXECUTE FUNCTION fn_update_inventory();

INSERT INTO orders (product_id, quantity)
VALUES (1, 3);

SELECT * FROM products WHERE id = 1;

UPDATE orders
SET quantity = 2
WHERE id = 1;

SELECT * FROM products WHERE id = 1;

DELETE FROM orders WHERE id = 1;

SELECT * FROM products WHERE id = 1;
