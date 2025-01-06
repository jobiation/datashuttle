#!/usr/bin/env python3
import subprocess;
notify_script = "sudo -u tony /var/cons/muttsend.sh";
notify_recipients = "me@gmail.com";
notify_subject = "This is the subject.";
message = "This is the message";
subprocess.call(notify_script+" '"+notify_recipients+"' '"+notify_subject+"' '"+message+"'",shell=True);
