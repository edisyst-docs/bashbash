-- ============================
-- SEZIONE 1: SELECT BASE
-- ============================

-- 1. Mostra tutti i prodotti
SELECT * FROM products;

-- 2. Mostra nome e prezzo dei prodotti con prezzo superiore a 100€
SELECT name, price FROM products WHERE price > 100;


-- ============================
-- SEZIONE 2: JOIN
-- ============================

-- 3. Lista degli ordini con nome e cognome del cliente
SELECT o.id AS order_id, c.first_name, c.last_name, o.order_date
FROM orders o
         JOIN customers c ON o.customer_id = c.id;

-- 4. Dettaglio degli ordini con nome prodotto e quantità
SELECT o.id AS order_id, p.name AS product, op.quantity
FROM orders o
         JOIN order_product op ON o.id = op.order_id
         JOIN products p ON op.product_id = p.id;


-- ============================
-- SEZIONE 3: AGGREGAZIONI
-- ============================

-- 5. Numero totale di ordini
SELECT COUNT(*) FROM orders;

-- 6. Quantità totale venduta per ogni prodotto
SELECT p.name, SUM(op.quantity) AS totale_venduto
FROM order_product op
         JOIN products p ON op.product_id = p.id
GROUP BY p.name;


-- ============================
-- SEZIONE 4: SUBQUERY
-- ============================

-- 7. Clienti che hanno fatto almeno un ordine
SELECT * FROM customers
WHERE id IN (SELECT customer_id FROM orders);

-- 8. Prodotti mai ordinati
SELECT * FROM products
WHERE id NOT IN (SELECT product_id FROM order_product);


-- ============================
-- SEZIONE 5: FUNZIONI DI FINESTRA
-- ============================

-- 9. Totale speso da ciascun cliente per ogni ordine
SELECT
    o.id AS order_id,
    c.first_name,
    SUM(p.price * op.quantity) OVER (PARTITION BY o.id) AS totale_ordine
FROM orders o
         JOIN customers c ON o.customer_id = c.id
         JOIN order_product op ON o.id = op.order_id
         JOIN products p ON op.product_id = p.id;

-- 10. Classifica dei clienti in base alla spesa totale (ranking)
SELECT
    c.first_name,
    c.last_name,
    SUM(p.price * op.quantity) AS totale_speso,
    RANK() OVER (ORDER BY SUM(p.price * op.quantity) DESC) AS classifica
FROM orders o
         JOIN customers c ON o.customer_id = c.id
         JOIN order_product op ON o.id = op.order_id
         JOIN products p ON op.product_id = p.id
GROUP BY c.id;


-- ============================
-- SEZIONE 6: CTE (Common Table Expressions)
-- ============================

-- 11. CTE per ottenere totale ordine e poi filtrare solo quelli sopra i 500€
WITH totali AS (
    SELECT o.id AS order_id, SUM(p.price * op.quantity) AS totale
    FROM orders o
             JOIN order_product op ON o.id = op.order_id
             JOIN products p ON op.product_id = p.id
    GROUP BY o.id
)
SELECT * FROM totali WHERE totale > 500;

-- 12. CTE ricorsivo (esempio semplice: numeri da 1 a 5)
WITH RECURSIVE contatore(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM contatore WHERE n < 5
)
SELECT * FROM contatore;


-- ============================
-- SEZIONE 7: MANIPOLAZIONE DATI
-- ============================

-- 13. Aggiungi un nuovo cliente
INSERT INTO customers (first_name, last_name, email)
VALUES ('Anna', 'Bianchi', 'anna.bianchi@example.com');

-- 14. Aggiorna lo stock del prodotto "Mouse" a 120 pezzi
UPDATE products SET stock = 120 WHERE name = 'Mouse';


-- ============================
-- SEZIONE 8: QUERY AVANZATE
-- ============================

-- 15. Calcola il valore medio degli ordini
SELECT AVG(totale) AS media_ordini FROM (
                                            SELECT o.id, SUM(p.price * op.quantity) AS totale
                                            FROM orders o
                                                     JOIN order_product op ON o.id = op.order_id
                                                     JOIN products p ON op.product_id = p.id
                                            GROUP BY o.id
                                        ) AS sub;

-- 16. Trova i prodotti più venduti (top 3)
SELECT p.name, SUM(op.quantity) AS venduti
FROM order_product op
         JOIN products p ON op.product_id = p.id
GROUP BY p.name
ORDER BY venduti DESC
    LIMIT 3;
