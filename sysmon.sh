#!/bin/bash

if [ $# -lt 1 ]
then
    echo "Usage: sysmon.sh -f <frequency-in-seconds>  [-i <number-of-iterations> -c <clean up old and retain logs for last c days>] "
    exit 1
fi

#sleep interval in seconds
SLEEP=$1
ITERATIONS=0
if [ $# -ge 2 ]
then
    ITERATIONS=$2
fi

OUTPUT_PREFIX=/tmp/sysmon_`hostname`
CMD_CURRENT_HOUR="date +%Y-%m-%d_%H%M"
OLD_OUTPUT_DIR=       
OUTPUT_DIR=

set_output_location() {
    OUTPUT_DIR="${OUTPUT_PREFIX}_`${CMD_CURRENT_HOUR}`"
    SCRIPTLOG="${OUTPUT_DIR}/sysmon.log"
    if [ "${OLD_OUTPUT_DIR}" != "${OUTPUT_DIR}" ]
    then
	mkdir -p ${OUTPUT_DIR}		
        exec 1<&-
        exec 2<&-
        exec >>${SCRIPTLOG}
        exec 2>&1
        OLD_OUTPUT_DIR="${OUTPUT_DIR}"
    fi
}

log() {
    echo "`date +%Y-%m-%d\ %H:%M:%S`:    $1" 
}

archive_if_necessary() {
    if [ "$OUTPUT_DIR" != "$OLD_OUTPUT_DIR" ]
    then
       ARCHIVE="${OLD_OUTPUT_DIR}.tar.gz"
       log "New directory! Archiving old logs to $ARCHIVE"
       tar -cvzf $ARCHIVE $OLD_OUTPUT_DIR/*
       # log "Removing old dir $OLD_OUTPUT_DIR"
       # rm -rf ${OLD_OUTPUT_DIR}
       # log "Removed $OLD_OUTPUT_DIR"
    fi
}


#custom_func() {
#    echo $1 | grep -q runnables
#    if [ $? -eq 0 ] ; then
#        grep -q "flush-8:0" $1
#        [[ $? -eq 0 ]] && (./collect_services_jstacks.sh &)
#    fi
#}


log_and_exec() {
    log "START $1" 
    PREFIX=${TIME}
    OUTPUT_FILE=${OUTPUT_DIR}/$1.out
    #eval $2 | sed "s/^/$PREFIX | /g" >> "${OUTPUT_DIR}/${OUTPUT_FILE}.out"
	echo "################## $PREFIX ##################" >> ${OUTPUT_FILE}
	eval $2 >> ${OUTPUT_FILE}
    log "DONE $1"
	
	custom_func $OUTPUT_FILE
}


if [ $# -lt 1 ]
then
    echo "Usage: sysmon.sh <sleep-in-seconds>"
    exit 1
fi

if [ $# -gt 0 ]; then
    while getopts f:c:i param ;
    do
      case "$param" in
        [?]) Usage
	      ;;
	i)    ITERATIONS=${OPTARG}
	        if [ -z "$ITERATIONS" ]; then
	          echo "ITERATIONS not specified. Please specify a value with -f option."
	          exit 1
	        fi 
              method=1
	      ;;
	c)    LOG_RETAIN_DAYS=${OPTARG}
	        if [ -z "$LOG_RETAIN_DAYS" ]; then
	          echo "LOG_RETAIN_DAYS not specified. Please specify a value with -c option which would be the number of days the logs to be retained."
	          exit 1
	        fi
	      method=2
	      ;;
	f)    SLEEP_FREQ=${OPTARG}
		    if [ -z "$SLEEP_FREQ" ]; then
	          echo "SLEEP_FREQUENCY not specified. Please specify a value with -f option which would be the sleep interval between each collection."
	          exit 1
	        fi
	      ;;
	d)    outputdir=${OPTARG}
	      dir=1
	      ;;
	z)    zipfilename=${OPTARG}
	      ;;
	i)    iter=${OPTARG}
	      ;;
	r)    run_interval=${OPTARG}
	      ;;
	s)    ignoreprocstack="-i"
	      ;;
      esac
    done
  else
    Usage
  fi


#sleep interval in seconds
SLEEP=$1

set_output_location
log "Script started with sleep interval of $SLEEP seconds"
log "Host=`hostname`"
log "Uname=`uname -a`"
if [ $ITERATIONS -eq 0 ]
then
    log "Sysmon will run forever until termination"
else
    log "Sysmon will stop after ${ITERATIONS} iterations"
fi

CNT=1
trap "{ echo Sysmon interrupted by signal. Halting!; exit 255; }" SIGINT SIGQUIT SIGTERM SIGKILL
trap "{ echo HUP received }" SIGHUP
while [ $ITERATIONS -eq 0 ] || [ $CNT -le $ITERATIONS ]
do
    #set_output_location 
    #archive_if_necessary

    TIME=`date +%Y-%m-%d\ %H:%M:%S`
    #export PREFIX=${TIME}
    log "Woke up!"
    log_and_exec "top" "top -b -n 1" 
    log_and_exec "vmstat" "vmstat 1 2 "
    log_and_exec "netstat" "netstat -as" 
    log_and_exec "netstat" "netstat -peano" 
    log_and_exec "loadavg" "cat /proc/loadavg" 
    log_and_exec "runnables" "ps -eLo state,pid,tid,cpu,comm,time,args | egrep '^(R|D)'" 
    log_and_exec "ps" "ps -eaf"
    log_and_exec "iostat" "iostat -x 1 2"
    log_and_exec "lsof" "lsof"
    log "Zzzzz"
    if [ $ITERATIONS -ne 0 ]
    then
        CNT=`expr $CNT + 1`
    fi
    sleep $SLEEP 
done

log "Sysmon completed $ITERATIONS iterations. Halting!"



