#! /bin/bash

## This script displays basic system metrics. It relies on binaries
## usually in the sysstat package. If not in debug mode, the
## tab-separated output is compatible with gnuplot (just redirect
## stdout to a file).
##
## first run: stats.bash -c > gnuplot.file
## then from cron: stats.bash >> gnuplot.file
##
## Enhancement Request:
##   - check for the existence of the tools first, give useful errors
##
## Version 1.0.2  2019-12-28  joni@flyingpenguintech.org
##
## 1.0.2  2019-12-28  improve debugging output
## 1.0.1  2019-09-08  simplify
## 1.0.0  2019-06-27  initial
VERSION="1.0.2"
NAME=${0##*/}

# if any command in a pipeline fails, that exit code is used for
#   the whole pipeline; see ${PIPESTATUS[@]} and hint-pipestatus
set -o pipefail
# bash will now complain about using an undefined variable
set -o nounset
# avoid /foo/* glob interpreted literally when no files match
shopt -s nullglob

###
## Variables
#
# 0 for no DEBUG
declare -i DEBUG=0
if (( DEBUG )); then /bin/echo Debugging on...; fi

###
## Parameters
#
declare -a STATSARRAY=()
declare -i STEP=1
PATH=/usr/bin:/bin:/usr/sbin:/sbin
#ECHO=/bin/echo
#AWK=/usr/bin/awk
#LOGGER=/usr/bin/logger
#SED=/bin/sed
#TR=/usr/bin/tr

###
## Getting Started
#
function printUsage () {
  echo "*****************************************************************************"
  echo "* $NAME [-c]"
  echo "*"
  echo "* -c  displays a comment line describing each column"
  echo "        this line starts with \# and is typically first in a gnuplot data file"
  echo "*****************************************************************************"
  # secret options:
  # -h to display this help
  # -V to show version
  # -v for verbose output
  # -w for more verbose output (no difference yet)
} # end function printUsage

# save the args before getopts eats them
# (without needing getopts reset of 'shift $((expr $OPTIND-1))')
ARGS=$@
# or put the args into an array, space-preserving
# declare -a ARGARRAY=("$@")

declare -i CFLAG=0
# getopts trick is : after option means arguments, no colon no args
while getopts chVvw GETFLAGS
do
  case "$GETFLAGS" in
  c) CFLAG=1
     ;;
  h) printUsage
     exit 0
     ;;
  V) echo " Script: ${NAME}"
     echo "Version: ${VERSION}"
     exit 0
     ;;
  v) DEBUG=1
     ;;
  w) DEBUG=2
     ;;
  \?) printUsage
     exit 64
     ;;
  esac
done

if (( DEBUG )); then
  echo "This input: $0 $ARGS"
  echo "has these flags (0 unset): CFLAG $CFLAG, DEBUG mode $DEBUG"
fi

## Message Logging Is Good
#
# messages must be sent ONE LINE AT A TIME
#
# ... use with knowledge: logged messages will probably go to
#     central searchable storage like Elasticsearch ...
#
# usage:
#   log "writing to stdout and to syslog"
#   err "writing to stderr and to syslog"
# result in syslog:
#   ${NAME}: writing to stdaaa and to syslog
#
function log () {
  declare -i f_log_cmdexit=0

  echo -e "$@"
  f_log_cmdexit=$?

  logger -p user.notice -t ${NAME} "$@"
  let f_log_cmdexit+=$?

  return ${f_log_cmdexit}
} # end function log: to stdout and syslog
#
function err () {
  declare -i f_err_cmdexit=0

  echo -e "$@" >&2
  f_err_cmdexit=$?

  logger -p user.error -t ${NAME} "$@"
  let f_err_cmdexit+=$?

  return ${f_err_cmdexit}
} # end function err: to stderr and syslog
#
# end Getting Started

# For clarity while debugging, add more whitespace (not gnuplot-compatible).
# Otherwise, display results incrementally for a basic progress meter.
function displayValue () {
  if (( DEBUG )); then
    if (( CFLAG )); then
      echo -e "\n$@"
    else
      echo -en "$@\t"
    fi
    printf "Step %02d complete\n\n" ${STEP}
  elif (( ! CFLAG )); then
    echo -en "$@\t"
  fi
}

###
## main()
#
if (( DEBUG )); then
  echo "Script ${NAME:=is} (version ${VERSION:=1}) running"
  if (( ! CFLAG )); then
    echo "This output may make more sense with the -c option too."
  fi
  echo ""
fi

## start data collection vvv

# datestamp
WHEN=$(date +%s)
STATSARRAY+="${WHEN} "
if (( CFLAG )); then
  echo -en "# datestamp\t"
fi
displayValue "${WHEN}"
STEP+=1

# load average for last 1 minute, 5 minutes, 15 minutes
#LOAD=$(cat /proc/loadavg | awk '{ print $1"\t"$2"\t"$3 }')
LOAD=$(uptime | awk '{ print $(NF-2)"\t"$(NF-1)"\t"$NF }' | tr -d ",")
STATSARRAY+="${LOAD} "
if (( CFLAG )); then
  echo -en "load1min\tload5min\tload15min\t"
fi
displayValue "${LOAD}"
STEP+=1

# average CPU use
#   not per-CPU, just to keep number of fields the same
CPU=$(iostat -ch | sed -n 4p | awk '{ print $1"\t"$2"\t"$3"\t"$4"\t"$5"\t"$6 }')
STATSARRAY+="${CPU} "
if (( CFLAG )); then
  iostat -ch | sed -n 3p | awk '{ print "avg"$2"\tavg"$3"\tavg"$4"\tavg"$5"\tavg"$6"\tavg"$7 }' | tr -d '\n'
  echo -en "\t"
fi
displayValue "${CPU}"
STEP+=1

# RAM use
MEM=$(free -m | grep ^Mem | awk '{ print $2"\t"$3"\t"$4"\t"$5"\t"$6"\t"$7 }')
STATSARRAY+="${MEM} "
if (( CFLAG )); then
  free -m | sed -n 1p | tr "/" "-" | awk '{ print $1"-mem\t"$2"-mem\t"$3"-mem\t"$4"-mem\t"$5"-mem\t"$6"-mem" }' | tr -d '\n'
  echo -en "\t"
fi
displayValue "${MEM}"
STEP+=1

# swap use
SWAP=$(free -m | grep ^Swap | awk '{ print $2"\t"$3"\t"$4 }')
STATSARRAY+="${SWAP} "
if (( CFLAG )); then
  free -m | sed -n 1p | tr "/" "-" | awk '{ print $1"-swap\t"$2"-swap\t"$3"-swap" }' | tr -d '\n'
  echo -en "\t"
fi
displayValue "${SWAP}"
STEP+=1

# disk I/O, greatly simplified
DISKIO=$(vmstat -D | grep IO$ | tr -d '\n' | awk '{ print $1"\t"$4 }')
STATSARRAY+="${DISKIO} "
if (( CFLAG )); then
  vmstat -D | grep IO$ | sed 's/\ IO/-diskIO/g;s/milli\ spent/ms-spent/g' | tr -d '\n' | awk '{ print $2"\t"$4 }' | tr -d '\n'
  echo -en "\t"
fi
displayValue "${DISKIO}"
STEP+=1

# network I/O
NETIO=$(sar -n DEV 1 1 | grep ^Average | grep -vw lo | grep -v "virbr\|tun\|tap" | sed 1d | awk '{ print $3"\t"$4"\t"$5"\t"$6 }')
STATSARRAY+="${NETIO} "
# last step, no need for trailing tab or for STEP increment
if (( CFLAG )); then
  sar -n DEV 1 1 | grep ^Average | grep -w IFACE | sed 's/pck\/s/pps/g;s/kB\/s/kps/g;s/rx/RX/g;s/tx/TX/g' | awk '{ print $3"\t"$4"\t"$5"\t"$6 }' | tr -d '\n'
fi
displayValue "${NETIO}"
#STEP+=1

# Satellite status, with response latency
#STATUS=$(curl -ks https://ustry1basv0165l.metlife.com:443/katello/api/ping)
#displayValue "${}"
#STEP+=1

## end data collection ^^^

if (( CFLAG )); then
  if (( DEBUG )); then
    echo -n "Full data set:"
  fi
  printf '\n%s\t' "${STATSARRAY[@]}"
fi
echo ""

if (( DEBUG )); then 
  echo -en "\nDEBUG: number of elements as counted by awk: "
  printf '%s\t' "${STATSARRAY[@]}" | awk '{ print NF }'
fi

# use exit code values of 0 (success) and 64 through 113 (or 125)
exit 0

version: 1.3 skeleton-header
version: 1.1 skeleton-variables
version: 1.0 BasicFlags-parameters
version: 1.2 skeleton-parameters
version: 1.5 skeleton-setup
version: 1.1 BasicFlags-setup
version: 1.5 skeleton-setup
version: 1.1 skeleton-main
version: 1.0 skeleton-footer
