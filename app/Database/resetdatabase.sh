#!/bin/bash
read -s -p "Enter Password: " mypassword
mysql -u root -p"$mypassword" -e "DROP DATABASE IF EXISTS drawnonward; CREATE DATABASE drawnonward;"
[ ! -z $1 ] && script=migrate_phppos || script=database
mysql -u root -p"$mypassword" -e "USE drawnonward; source $script.sql;"
