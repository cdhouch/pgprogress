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
  #echo "psql -U postgres -t -d $DBNAME -c 'SELECT relname from pg_class where relfilenode = $ONFILE;'"
  OIDNAME=`psql -U postgres -t -d $DBNAME -c "SELECT relname from pg_class where relfilenode = $ONFILE;" 2>&1`
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
                #echo $IOFILE
		#echo "ls -l /proc/$MPPID/fd/$IOFILE | grep -oP '(?<=/)[^/.]+(?=(\.\d+)?$)'"
	        ONFILE=`ls -l /proc/$MPPID/fd/$IOFILE | grep -oP '(?<=/)[^/.]+(?=(\.\d+)?$)'`
                FULLNAME=`ls -l /proc/$MPPID/fd/$IOFILE | awk -F'-> ' {'print $2;'}`
		#echo "O $ONFILE F $FULLNAME"
		if [[ "$FULLNAME" =~ \. ]]; then
                  ONSUBFILE=`ls -l /proc/$MPPID/fd/$IOFILE | awk -F . '{print $NF}'`
                  #echo "ls -l /proc/$MPPID/fd/$IOFILE | grep -oP '(?<=\s)/[^ ]*(?=/[^/]+$)'"
                  MDIR=`ls -l /proc/$MPPID/fd/$IOFILE | grep -oP '(?<=\s)/[^ ]*(?=/[^/]+$)'`
                  #echo "ls -alv $MDIR |grep $ONFILE|grep -v '_vm'|grep -v '_fsm'|tail -n1|awk -F . '{print $NF}'"
  		  MAXSUBFILE=`ls -alv $MDIR |grep $ONFILE|grep -v "_vm"|grep -v "_fsm"|tail -n1|awk -F . '{print $NF}'`
                else 
		  ONSUBFILE=1
		  MAXSUBFILE=1
                fi

		isonlygig 
		#echo "ONFILE: $IOFILE $ONFILE"
                if [[ "$FULLNAME" =~ pg_xlog ]] || [[ "$FULLNAME" =~ pg_wal ]]; then 
                    OIDNAME=" <wal:$ONFILE>"
                elif [[ "$FULLNAME" =~ pgsql_tmp ]]; then
                    OIDNAME=" <tmp:$ONFILE>"
		elif [[ "$FULLNAME" =~ _fsm ]]; then
		    OIDNAME=" <fsm:$ONFILE>"
                else 
                    getfname $ONFILE
		    if [[ -z $OIDNAME ]]; then
                        OIDNAME=" <unknown:$ONFILE>"
                    fi
                fi
                echo "Process I/O is in$OIDNAME at $ONSUBFILE out of $MAXSUBFILE at $FULLNAME"
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
