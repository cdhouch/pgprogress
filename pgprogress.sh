#!/bin/bash

MPPID=$1

# Error check input
if [ $# -eq 0 ]
  then
    echo "No PID supplied"
    exit
fi

# Determine the database being used by the process we're interrested in 
DBNAME=`psql -Atc "select datname from pg_stat_activity where pid = $MPPID"`
QUERY=`psql -Atc "select query from pg_stat_activity where pid = $MPPID"`

#functions

#Take in ONFILE raw numeric file and output relfilname
function getfname {
	local ONFILE=$1
	if [[ $ONFILE =~ .*_fsm.* ]]; then
		ONFILE="UNKNOWN";
	elif [[ $ONFILE =~ .*pg_xlog.* ]]; then
		ONFILE="UNKNOWN";
	fi
	if [ "$ONFILE" != "UNKNOWN" ]; then
		OIDNAME=`psql -t -d $DBNAME -c "SELECT relname from pg_class where relfilenode = $ONFILE;"`
	fi	
}

#Build read or write lists and flag if temp file is in list
function buildlists {
	local FTYPE=$1
	MFILE=`grep $FTYPE /tmp/proctrace.txt |awk -F',' {'print $1;'}|awk -F"(" {'print $2;'}|sort|uniq|xargs`
	NUMMFILE=`echo $MFILE|wc -w`
	
	for IOFNAME in $MFILE
	do
		FULLNAME=`ls -l /proc/$MPPID/fd |grep " $IOFNAME ->"`
       		ISTMP=`echo $FULLNAME|grep -c "pgsql_tmp"`
	done
	if [ $FTYPE == "read" ];then
		RFILES=$MFILE
	elif [ $FTYPE == "write" ];then
		WFILES=$MFILE
	fi
}

#Print list of files being read or written
function printlists {
	IOTYPE=$1
	if [ $IOTYPE == "read" ]; then
		local IOFILES=$RFILES
	elif [ $IOTYPE == "write" ]; then
		local IOFILES=$WFILES
	fi
	#echo "DEBUG IOFILES $IOFILES RFIES $RFILES WFILES $WFILES"
	for IOFILE in $IOFILES
	do
		ONFILE=`ls -l /proc/$MPPID/fd |grep " $IOFILE ->" | grep -oP '(?<=/)\d+(?=\.\d+$)'`
                ONSUBFILE=`ls -l /proc/$MPPID/fd |grep " $IOFILE ->"|awk -F . '{print $NF}'`
                FULLNAME=`ls -l /proc/$MPPID/fd |grep " $IOFILE ->"|awk -F"-> " {'print $2;'}`
                MDIR=`ls -l /proc/$MPPID/fd |grep " $IOFILE ->" | grep -oP '(?<=\s)/.*(?=/[^/]+$)'`
		MAXSUBFILE=`ls -alv $MDIR |grep $ONFILE|grep -v "_vm"|grep -v "_fsm"|tail -n1|awk -F . '{print $NF}'`
		isonlygig 
		getfname $ONFILE
                echo "Process I/O is in $OIDNAME at $ONSUBFILE out of $MAXSUBFILE at $FULLNAME"
	done
}

function isonlygig {
	# Check if table is under a gig or IO is on 0GB table
	ONLYGIG=`echo $ONSUBFILE|grep -c "/"`

        if [ $ONLYGIG -ne 0 ]; then
                ONSUBFILE=0
        fi
}	


#Main
echo "Checking process $MPPID ($QUERY)"
echo $(date)
echo

timeout 2 strace -o /tmp/proctrace.txt -p $MPPID &>/dev/null
buildlists read
buildlists write


echo "Files being READ are:"
echo "---------------------"
printlists read
       
echo
echo "Files being WRITTEN TO are:"
       echo "---------------------------"
printlists write

echo
exit
