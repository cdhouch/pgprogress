#!/bin/bash

# Enter Database Name to check against
DBNAME="postgres"

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

for RFNAME in $SMFILE
do
	FULLNAME=`ls -l /proc/$1/fd |grep " $RFNAME ->"`
	ISTMP=`echo $FULLNAME|grep -c "pgsql_tmp"`
	#echo "Is temp? $ISTMP $RFNAME"
done

WFILES=`grep write proctrace.txt |awk -F',' {'print $1;'}|awk -F"(" {'print $2;'}|sort|uniq|xargs`

for WFNAME in $WFILES
do
        FULLNAME=`ls -l /proc/$1/fd |grep " $WFNAME ->"`
        ISTMP=`echo $FULLNAME|grep -c "pgsql_tmp"`
        #echo "Is temp? $ISTMP $WFNAME"
done

if [ $NUMMFILE -gt 1 ] || [ -z "$MFILE" ] || [ $ISTMP -gt 0 ]; then
	echo "Process's progress cannot be tracked."
	echo "Either it is reading multiple files, writing only, or working with tmp tables"
	echo "Files being READ are:"
	echo "---------------------"
	for RFILE in $SMFILE
	do
		ONFILE=`ls -l /proc/$1/fd |grep " $RFILE ->"|awk -F"-> " {'print $2;'}|awk -F"/" {'print $6;'}|awk -F"." {'print $1;'}`
		ONSUBFILE=`ls -l /proc/$1/fd |grep " $RFILE ->"|awk -F . '{print $NF}'`
		FULLNAME=`ls -l /proc/$1/fd |grep " $RFILE ->"|awk -F"-> " {'print $2;'}`
		echo "Process is reading $FULLNAME"
	done
        
	echo
	echo "Files being WRITTEN TO are:"
        echo "---------------------------"
	
	for WFILE in $WFILES
	do
		ONFILE=`ls -l /proc/$1/fd |grep " $WFILE ->"|awk -F"-> " {'print $2;'}|awk -F"/" {'print $6;'}|awk -F"." {'print $1;'}`
                ONSUBFILE=`ls -l /proc/$1/fd |grep " $WFILE ->"|awk -F . '{print $NF}'`
                FULLNAME=`ls -l /proc/$1/fd |grep " $WFILE ->"|awk -F"-> " {'print $2;'}`
		echo "Process is writing $FULLNAME"
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

