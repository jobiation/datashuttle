<?php
echo "You must execute this script as the user for whom MUTT was configured.";
$notify_script = "/var/cons/muttsend.sh";
$notify_recipients = "me@yahoo.com";
$notify_subject = "TheSubject2";
$message = "TheBody2";
exec("{$notify_script} {$notify_recipients} '{$notify_subject}' '{$message}'");
?>
