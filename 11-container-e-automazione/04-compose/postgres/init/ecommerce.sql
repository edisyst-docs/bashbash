-- Creazione schema pubblico pulito
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;

-- Tabella prodotti
CREATE TABLE products (
                          id SERIAL PRIMARY KEY,
                          name TEXT NOT NULL,
                          price NUMERIC(10,2) NOT NULL,
                          stock INTEGER DEFAULT 0
);

-- Tabella clienti
CREATE TABLE customers (
                           id SERIAL PRIMARY KEY,
                           first_name TEXT NOT NULL,
                           last_name TEXT NOT NULL,
                           email TEXT UNIQUE NOT NULL
);

-- Tabella ordini
CREATE TABLE orders (
                        id SERIAL PRIMARY KEY,
                        customer_id INTEGER REFERENCES customers(id) ON DELETE CASCADE,
                        order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabella ordini_prodotti (many-to-many)
CREATE TABLE order_product (
                               order_id INTEGER REFERENCES orders(id) ON DELETE CASCADE,
                               product_id INTEGER REFERENCES products(id),
                               quantity INTEGER NOT NULL,
                               PRIMARY KEY(order_id, product_id)
);

-- Inserimento prodotti
INSERT INTO products (name, price, stock) VALUES
                                              ('Laptop', 1200.00, 10),
                                              ('Mouse', 25.50, 100),
                                              ('Monitor', 300.99, 20),
                                              ('Keyboard', 45.00, 50);

-- Inserimento clienti
INSERT INTO customers (first_name, last_name, email) VALUES
                                                         ('Mario', 'Rossi', 'mario.rossi@example.com'),
                                                         ('Luigi', 'Verdi', 'luigi.verdi@example.com');

-- Inserimento ordini
INSERT INTO orders (customer_id, order_date) VALUES
                                                 (1, '2024-05-10 10:00:00'),
                                                 (2, '2024-05-11 12:00:00');

-- Inserimento prodotti negli ordini
INSERT INTO order_product (order_id, product_id, quantity) VALUES
                                                               (1, 1, 1),
                                                               (1, 2, 2),
                                                               (2, 3, 1),
                                                               (2, 4, 1);
