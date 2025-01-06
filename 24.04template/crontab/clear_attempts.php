<?php

$db = "testdb1";
include("/var/cons/inc-db.php");

mysqli_query($con,"DELETE FROM attempts WHERE id > 0");

mysqli_close($con);
?>
