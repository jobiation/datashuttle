<?php
$db = "testdb1";
include("/var/cons/inc-db.php");
?>

<!DOCTYPE html>
<html>
<head>
<title>Connection Test Page</title>
</head>
<body>

<h2>Connection Test Page</h2>
<p>

<?php

# Loop through tea table
    $dbSel = mysqli_query($con,"SELECT today FROM currentdate WHERE id = 1");
    $dbInfo = mysqli_fetch_array($dbSel);
    echo "The date value in " . $db . " is " . $dbInfo['today'];
?>

</p>
</body>
</html>

<?php mysqli_close($con); ?>

