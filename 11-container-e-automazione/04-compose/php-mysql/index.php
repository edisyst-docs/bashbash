<?php
// L'host è "database", il nome del servizio in compose.yaml: sulla rete di compose
// ogni servizio si raggiunge per nome. "localhost" sarebbe il container PHP stesso.
$conn = new mysqli(
    getenv('DB_HOST'),
    getenv('DB_USER'),
    getenv('DB_PASSWORD'),
    getenv('DB_NAME')
);

if ($conn->connect_error) {
    die("Connessione fallita: " . $conn->connect_error);
}
echo "Connesso a MySQL " . $conn->server_info . "\n";
