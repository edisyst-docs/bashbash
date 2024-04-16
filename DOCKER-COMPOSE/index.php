<?php

$hostname = "database"; // non capisco perchè questo
// $hostname = "localhost";
$username = "myuser";
$password = "mypassword";
$database = "mydatabase";

// Create connection
$conn = new mysqli($hostname, $username, $password, $database);

// Check connection
if ($conn->connect_error) {
  die("Connection failed: " . $conn->connect_error);
}
echo "Connected successfully";

?>