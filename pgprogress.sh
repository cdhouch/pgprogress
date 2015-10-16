#!/bin/bash

# Enter Database Name to check against
DBNAME="I2B2"

if [ $# -eq 0 ]
  then
    echo "No PID supplied"
    exit
fi

echo "Checking process $1"
echo $(date)
echo

timeout 1 strace -o proctrace.txt -p $1 &>/dev/null
MFILE=`grep read proctrace.txt |awk -F',' {'print $1;'}|awk -F"(" {'print $2;'}|sort|uniq`
SMFILE=`echo $MFILE|xargs`
NUMMFILE=`echo $SMFILE|wc -w`

WFILES=`grep write proctrace.txt |awk -F',' {'print $1;'}|awk -F"(" {'print $2;'}|sort|uniq|xargs`

if [ $NUMMFILE -gt 1 ]; then
	echo "Process is reading multiple files and progress cannot be tracked"
	echo "Files being READ are:"
	echo "---------------------"
	for RFILE in $SMFILE
	do
		ONFILE=`ls -l /proc/$1/fd |grep " $RFILE ->"|awk -F"-> " {'print $2;'}|awk -F"/" {'print $6;'}|awk -F"." {'print $1;'}`
		ONSUBFILE=`ls -l /proc/$1/fd |grep " $RFILE ->"|awk -F . '{print $NF}'`
		OIDNAME=`psql -t -d $DBNAME -c "SELECT relname from pg_class where oid = $ONFILE;"`
		echo "Process is reading $OIDNAME at $ONSUBFILE"
	done
        
	echo
	echo "Files being WRITTEN TO are:"
        echo "---------------------------"
	
	for WFILE in $WFILES
	do
		ONFILE=`ls -l /proc/$1/fd |grep " $WFILE ->"|awk -F"-> " {'print $2;'}|awk -F"/" {'print $6;'}|awk -F"." {'print $1;'}`
                ONSUBFILE=`ls -l /proc/$1/fd |grep " $WFILE ->"|awk -F . '{print $NF}'`
                OIDNAME=`psql -t -d $DBNAME -c "SELECT relname from pg_class where oid = $ONFILE;"`
                echo "Process is writing $OIDNAME at $ONSUBFILE"
	done
	echo
else

	echo "Found file being accessed as FD $MFILE"
	ls -l /proc/$1/fd |grep " $MFILE ->"

	MDIR=`ls -l /proc/$1/fd |grep " $MFILE ->"|awk -F"-> " {'print $2;'}|awk -F"/" {'print $1"/"$2"/"$3"/"$4"/"$5;'}`
	ONSUBFILE=`ls -l /proc/$1/fd |grep " $MFILE ->"|awk -F . '{print $NF}'`

	ONLYGIG=`echo $ONSUBFILE|grep -c "/"`

	if [ $ONLYGIG -ne 0 ]; then
		ONSUBFILE=0
	fi

	ONFILE=`ls -l /proc/$1/fd |grep " $MFILE ->"|awk -F"-> " {'print $2;'}|awk -F"/" {'print $6;'}|awk -F"." {'print $1;'}`

	MAXSUBFILE=`ls -al $MDIR |grep $ONFILE|sort|grep -v "_vm"|grep -v "_fsm"|tail -n1|awk -F . '{print $NF}'`

	OIDNAME=`psql -t -d $DBNAME -c "SELECT relname from pg_class where oid = $ONFILE;"`
	echo "Process is reading $OIDNAME at $ONSUBFILE gigabytes of $MAXSUBFILE"
	echo

fi

