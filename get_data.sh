#!/bin/sh
BASEDIR=`cd "$(dirname "$0")"; pwd`
cd $BASEDIR

mysql_exec="mysql -h127.0.0.1 -uroot -pDji@123 db_rtk -ABN --local-infile=1 -e "

sql="select * from t_base;"
echo "$mysql_exec" "$sql"
$mysql_exec "$sql" > t_base.txt

#sql="load data local infile \"car_base.txt\" replace into table car_base (car_base_id, series, name);"
#echo "$mysql_exec2" "$sql"
#$mysql_exec2 "$sql"
