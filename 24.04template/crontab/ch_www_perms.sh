#!/bin/bash
find /var/www -type f -print0 | xargs -I {} -0 chmod 0664 {}
find /var/www -type d -print0 | xargs -I {} -0 chmod 0775 {}

