<?php
$date = date("Y") . date("m") . date("d");
$db = "testdb1";
include("/var/cons/inc-db.php");
mysqli_query($con,"UPDATE currentdate SET today = $date WHERE id = 1");
mysqli_close($con);
?>
