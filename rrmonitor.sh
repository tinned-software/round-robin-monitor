#!/bin/bash
#
# @author Gerhard Steinbeis (info [at] tinned-software [dot] net)
# @copyright Copyright (c) 2012 - 2013
version=0.1.1
# @license http://opensource.org/licenses/GPL-3.0 GNU General Public License, version 3
# @package monitoring
#


# Default path value
HOST_PATH="/"


#
# Parse all parameters
#
HELP=0
while [ $# -gt 0 ]; do
	case $1 in
		# General parameter
		-h|--help)
			HELP=1
			shift
			;;
		-v|--version)
			echo 
			echo "Copyright (c) 2014 Tinned-Software (Gerhard Steinbeis)"
			echo "License GNUv3: GNU General Public License version 3 <http://opensource.org/licenses/GPL-3.0>"
			echo 
			echo "`basename $0` version $version"
			echo
			exit 0
			;;

		# specific parameters
		-c|--config)
			CONFIG_FILE=$2
			. $CONFIG_FILE
			shift 2
			;;

		--host)
			HOST_NAME=$2
			shift 2
			;;

		--path)
			HOST_PATH=$2
			shift 2
			;;

		--pattern)
			SEARCH_PATTERN=$2
			shift 2
			;;

		--format)
			FORMAT=$2
			shift 2
			;;

		# Unnamed parameter        
		*)
			echo "Unknown option '$1'"
			HELP=1
			shift
			break
			;;
    esac
done


if [ "$HOST_NAME" == "" ]
then
	echo "parameter --host is required."
	HELP=1
fi



# show help message
if [ "$HELP" -eq "1" ]; then
    echo 
    echo "This script will resolve the provided hostname. The returned IP "
    echo "addresses will be checked one by one via HTTP request. The returned "
    echo "web content is searched for the provided pattern."
    echo 
    echo "Usage: `basename $0` [-hv] [--config filename.conf] [--host hostname] [--path /index.html] [--pattern \"Website Title\"]"
      echo "  -h  --help         Print this usage and exit"
      echo "  -v  --version      Print version information and exit"
      echo "      --config       Configuration file to read parameters from"
      echo "      --host         The hostname to check"
      echo "      --path         The file/path on the server to request"
      echo "      --pattern      The pattern to search on the returned content (regex)"
      echo "      --format       Define the result format 'text' (default), 'json'"
      echo 
    exit 1
fi



# change the command used for time calculation of MacOSX
DETECTED_OS_TYPE=`uname -s`


# resolve host name to IP address
IP_LIST=`host $HOST_NAME | grep "address" | sed 's/^.*address //'`

# start output in requested format
if [ "$FORMAT" == "json" ]
then
	RESULT_JSON="{\"host\":\"$HOST_NAME\",\"details\":["
else
	echo "Host: $HOST_NAME"
fi
STATUS_SUMMARY="--"

# set the numeric seperate according to the "en_US" format
LC_NUMERIC_OLD=$LC_NUMERIC
LC_NUMERIC="en_US.UTF-8"


# Check for each host
for HOST_IP in $IP_LIST
do
	# start the time measurement
	if [ "$DETECTED_OS_TYPE" == "Darwin" ]
	then
		START_TIME=`ruby -e "puts Time.now.to_f"`
	else
		START_TIME=`date +%s%N`
	fi

	# execute the request to this server
	RESULT=`curl -i -H "Host: $HOST_NAME" $HOST_IP 2>&1 | tee $HOST_IP".log" | grep -E "$SEARCH_PATTERN" | wc -l`

	# stop the time measurement
	if [ "$DETECTED_OS_TYPE" == "Darwin" ]
	then
		END_TIME=`ruby -e "puts Time.now.to_f"`
	else
		END_TIME=`date +%s%N`
	fi

	# check HTTP response code
	HTTP_CODE=`head -n 6 "$HOST_IP.log" | grep "HTTP\/.* 200 OK" | sed -E 's/^.* ([0-9]{3}) .*$/\1/'`
	if [ "$HTTP_CODE" != "200" ]
	then
		RESULT=''
	fi

	# calculate the time needed to request the page
	DIFF_TIME=`echo "1395156785.4709299 - 1395156784.868294" | bc`
	DIFF_TIME=`printf "%f", $DIFF_TIME`

	# Check if content is returned
	if [ "$RESULT" != "" ]
	then
		# check the requersted return format
		if [ "$FORMAT" == "json" ]
		then
			RESULT_JSON=$RESULT_JSON"{\"ip\":\"$HOST_IP\",\"time\":\"$DIFF_TIME\",\"status\":\"OK\"},"
		else
			echo "    Status: OK  , IP: $HOST_IP , Time: $DIFF_TIME"
		fi

		# define summary status
		if [ "$STATUS_SUMMARY" == "--" ]
		then
			STATUS_SUMMARY="OK"
		fi
		# remove log on success
		#rm $HOST_IP".log"
	else
		if [ "$FORMAT" == "json" ]
		then
			RESULT_JSON=$RESULT_JSON"{\"ip\":\"$HOST_IP\",\"time\":\"$DIFF_TIME\",\"status\":\"OK\"},"
		else
			echo "    Status: NOK , IP: $HOST_IP , Time: $DIFF_TIME"
		fi
		# rename log on failure
		mv $HOST_IP".log" $(date "+%Y-%m-%d_%H-%M-%S_NOK_")$HOST_IP".log"
		STATUS_SUMMARY="NOK"
	fi
done

# set the number locale back to its original
LC_NUMERIC=$LC_NUMERIC_OLD

# Finish output based on the requested format
if [ "$FORMAT" == "json" ]
then
	RESULT_JSON=${RESULT_JSON%?}
	RESULT_JSON=$RESULT_JSON"],\"status\":\"$STATUS_SUMMARY\"}"
	echo -e $RESULT_JSON
else
	echo "Summary: $STATUS_SUMMARY"
fi

if [ "$STATUS_SUMMARY" == "OK" ]
then
	exit 0
else
	exit 1
fi
