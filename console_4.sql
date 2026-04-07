-- 3 Trigger
    -- Khi thêm đơn hàng:
        -- Khi thêm thì phải trừ đi stock thông qua quantity ở order
        -- Kiểm tra tồn kho trước khi trừ
        -- stock = stock - NEW.quantity (Order)
    -- Cập nhật số lượng tồn kho
        -- if NEW.quantity > OLD.quantity -- đăng tăng
        -- Kiểm tra stock có đủ tồn kho hay không
        -- > cần phải trừ đi stock
        -- Ngược lại thì tương tự
    -- Huỷ hàng
        -- Cập nhật trạng thái về CANCELLED
        -- Cập nhật stock sản phẩm tất cả từ order được huỷ

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

-- Tạo function update insert
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
            -- đang tăng
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
-- Tạo trigger
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
                IF v_current_stock < ABS(v_diff) THEN
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