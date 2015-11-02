#!/bin/bash

# Enter Database Name to check against
DBNAME="postgres"
MPPID=$1

# Error check input
if [ $# -eq 0 ]
  then
    echo "No PID supplied"
    exit
fi

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
	MFILE=`grep $FTYPE proctrace.txt |awk -F',' {'print $1;'}|awk -F"(" {'print $2;'}|sort|uniq|xargs`
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
		ONFILE=`ls -l /proc/$MPPID/fd |grep " $IOFILE ->"|awk -F"-> " {'print $2;'}|awk -F"/" {'print $6;'}|awk -F"." {'print $1;'}`
                ONSUBFILE=`ls -l /proc/$MPPID/fd |grep " $IOFILE ->"|awk -F . '{print $NF}'`
                FULLNAME=`ls -l /proc/$MPPID/fd |grep " $IOFILE ->"|awk -F"-> " {'print $2;'}`
                MDIR=`ls -l /proc/$MPPID/fd |grep " $IOFILE ->"|awk -F"-> " {'print $2;'}|awk -F"/" {'print $1"/"$2"/"$3"/"$4"/"$5;'}`
		MAXSUBFILE=`ls -al $MDIR |grep $ONFILE|sort|grep -v "_vm"|grep -v "_fsm"|tail -n1|awk -F . '{print $NF}'`
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
echo "Checking process $MPPID"
echo $(date)
echo

timeout 1 strace -o proctrace.txt -p $MPPID &>/dev/null
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
