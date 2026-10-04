-- Database di esempio per 03-mysql.md: lo esegue l'immagine mysql al primo avvio
-- (tutto quello che sta in /docker-entrypoint-initdb.d, in ordine alfabetico)
USE app_db;

CREATE TABLE users (
    id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name       VARCHAR(100) NOT NULL,
    email      VARCHAR(150) NOT NULL UNIQUE,
    created_at DATETIME NOT NULL
);

CREATE TABLE orders (
    id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id    INT UNSIGNED NOT NULL,
    total      DECIMAL(8,2) NOT NULL,
    created_at DATETIME NOT NULL,
    INDEX (created_at),
    FOREIGN KEY (user_id) REFERENCES users (id)
);

CREATE TABLE products (
    id    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name  VARCHAR(100) NOT NULL,
    price DECIMAL(8,2) NOT NULL
);

CREATE TABLE logs (
    id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    messaggio  VARCHAR(255) NOT NULL,
    created_at DATETIME NOT NULL
);

INSERT INTO users (name, email, created_at) VALUES
    ('Mario Rossi',    'mario.rossi@example.com',  '2026-01-15 10:00:00'),
    ('Anna Bianchi',   'anna.bianchi@example.com', '2026-02-03 09:30:00'),
    ('Luca Verdi',     'luca.verdi@example.com',   '2026-03-21 18:45:00'),
    ('Sara Neri',      'sara.neri@example.com',    '2026-05-10 12:00:00'),
    ('Paolo Gallo',    'paolo.gallo@example.com',  '2026-07-01 08:15:00'),
    ('Giulia Costa',   'giulia.costa@example.com', '2026-08-19 16:20:00'),
    ('Marco Fontana',  'marco.fontana@example.com','2026-09-02 11:10:00'),
    ('Elena Greco',    'elena.greco@example.com',  '2026-09-20 14:05:00');

INSERT INTO products (name, price) VALUES
    ('penne', 1.50), ('quaderno', 3.20), ('zaino', 39.90), ('gomma', 0.40), ('astuccio', 12.00);

-- 3000 ordini distribuiti su tutto il 2026 fino al 25 settembre, e 20000 righe di log
SET SESSION cte_max_recursion_depth = 20000;
INSERT INTO orders (user_id, total, created_at)
WITH RECURSIVE n (i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 3000)
SELECT i % 8 + 1, ROUND(5 + (i * 37 % 20000) / 100, 2), TIMESTAMP('2026-01-01') + INTERVAL (i * 7919 % 267) DAY + INTERVAL (i % 86400) SECOND
FROM n;

INSERT INTO logs (messaggio, created_at)
WITH RECURSIVE n (i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 20000)
SELECT CONCAT('evento numero ', i, ': ', REPEAT('x', i % 100)), TIMESTAMP('2026-09-01') + INTERVAL i MINUTE
FROM n;
