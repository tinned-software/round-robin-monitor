#!/bin/bash
#
# @author Gerhard Steinbeis (info [at] tinned-software [dot] net)
# @copyright Copyright (c) 2014-2016
version=0.6.1
# @license http://opensource.org/licenses/GPL-3.0 GNU General Public License, version 3
# @package monitoring
#


# The host name to monitor. This hostname is resolved and each returned IP 
# address is checked individually.
#HOST_NAME=""
HOST_PORT="80"

# Set the url schema to be used when connecting to the server. When using 
# https:// this script will report a certificate missmatch as the connection is 
# explicitly made via IP address which is very likely not listed in the 
# certificate. To avoid it, add the "--insecure" option into the CURL_OPTIONS.
URL_SCHEMA="http://"

# define the DNS server to use. When you do not want to use the systems default 
# dns serers, you can specify them here. To use system defaut keep this empty.
HOST_DNS_SERVER=""

# The command used to resolve the hostname "host" does not utilize the 
# /etc/hosts file. This switch is added to switch between the "host" 
# command (using the $HOST_DNS_SERVER setting) and the "getent ahosts" command. 
# To use the /etc/hosts while resolfing the hostname set this to YES. When this 
# is set to YES, the $HOST_DNS_SERVER setting is not used.
UTILIZE_HOSTS="NO"

# Disable checking IPv6 addresses. This can be used if the monitoring host does 
# not have IPv6 connectivity to avoid false positives.
IGNORE_IP6="NO"

# The path/filename to retrieve from the server. This should at least contain 
# the "/" which is the default.
HOST_PATH="/"

# Output format of the result. Possible values are "text" (default), "json" 
# and "terse". The terse format will output the "text" format but only if the 
# summary status is not OK. It will as well contain the content of the failed 
FORMAT="text"

# Define the logfile path. It is used to store the server response to. In case 
# of an OK check, the output file is deletect after the check is completed. A 
# not successfull check will remain where the file name will be of the 
# following format: <YYYY-MM-DD_hh-mm-ss>_NOK_<HOST_IP>.log
LOG_PATH=""

# The connect timeout in seconds for the connection attempt. This limit only 
# applies to the connect phase of the ckeck.
# The default connect timeoutr is set to 10 seconds.
CONNECT_TIMEOUT="10"

# Limiting the complete check to a maximum amount of seconds. This will limit 
# the complete time the operation is allowed to take. This includes the 
# connection phase.
# The default check timeout is set to 60 seconds.
CHECK_TIMEOUT="60"

# Set additional options for the curl command to retrieve the content of the 
# website. The possible options is available in the curl man page. The example 
# shows the -L option allowing curl to follow redirects.
#CURL_OPTIONS="-L"

# This trigger-timeout defines the timeout after which the check is considered 
# failed. Even with the rest of the check beeing OK, if this time is exeeded, 
# the test is considered failed.
# The default check timeout is set to 30 seconds.
TRIGGER_TIMEOUT="30"


# Enable the notification via XMPP. This requires sendxmpp to be installed. For
# more details about sendxmpp see http://sendxmpp.platon.sk/
XMPP_NOTIFICATION="NO"



SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

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

		--port)
			HOST_PORT=$2
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
			case $2 in
				json)
					FORMAT="json"
					;;
				text)
					FORMAT="text"
					;;
				terse)
					FORMAT="terse"
					;;
				*)
					HELP=1
					echo "parameter --format with unknown value."
					;;
			esac
			shift 2
			;;

		--logpath)
			LOG_PATH=$2
			shift 2
			;;

		--connect-timeout)
			CONNECT_TIMEOUT=$2
			shift 2
			;;

		--check-timeout)
			CHECK_TIMEOUT=$2
			shift 2
			;;

		--trigger-timeout)
			TRIGGER_TIMEOUT=$2
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
      echo "  -h  --help              Print this usage and exit"
      echo "  -v  --version           Print version information and exit"
      echo "      --config            Configuration file to read parameters from"
      echo "      --host              The hostname to check"
      echo "      --port              The port to use for the check"
      echo "      --path              The file/path on the server to request"
      echo "      --connect-timeout   The curl timeout for the connect"
      echo "      --check-timeout     The curl timeout for the complete request incl. connect"
      echo "      --trigger-timeout   The trigger time after which the test is considered failed."
      echo "      --pattern           The pattern to search on the returned content (regex)"
      echo "      --logpath           Define the path for the logfiles"
      echo "      --format            Define the result format 'text' (default), 'json' and 'terse'."
      echo "                          The format terse defines that only in case of the summary status not beeing 'OK' output"
      echo "                          is generated. It also includes the returned content from the failed check(s)."
      echo 
    exit 1
fi


# load the rrdtool functions
. $SCRIPT_PATH/rrmonitor_rrdtool.sh

# change the command used according to the OS specifics
# Mac OS X ... Darwin
# Linux ...... Linux
DETECTED_OS_TYPE=`uname -s`


# resolve host name to IP address
if [[ "$UTILIZE_HOSTS" == "YES" ]]; then
	IP_LIST=`getent ahosts blog.tinned-software.net | awk '{print $1}' | uniq`
else
	IP_LIST=`host $HOST_NAME $HOST_DNS_SERVER | grep "address" | sed 's/^.*address //'`
fi

# Get timestamp of monitor run
MONITOR_TIME=`date "+%s"`

# start output in requested format
case $FORMAT in
	json)
		RESULT_JSON="{\"host\":\"$HOST_NAME\", \"timestamp\":\"$MONITOR_TIME\", \"details\":["
		;;
	text)
		echo "Host: $HOST_NAME (timestamp: $MONITOR_TIME)"
		;;
	terse)
		RESULT_TERSE="Host: $HOST_NAME (timestamp: $MONITOR_TIME)\n"
		;;
esac
STATUS_SUMMARY="--"

# set the numeric seperate according to the "en_US" format
LC_NUMERIC_OLD=$LC_NUMERIC
LC_NUMERIC="en_US.UTF-8"


if [[ "$RRDTOOL_ENABLE" == "YES" ]]
then
	for HOST_IP in $IP_LIST
	do
		HOST_IP_NAME=`echo "$HOST_IP" | sed 's/[:\.]/_/g'`
		if [[ ! -f "${RRDTOOL_DBPATH}${HOST_IP_NAME}.rrd" ]]
		then
			rrdtool_create $HOST_IP
		fi
	done
fi

# Check for each host
RESULT_TERSE_DETAILS=''
for HOST_IP in $IP_LIST
do
	# Check if IPv6 addresses should be ignored
	if [[ "$IGNORE_IP6" == "YES" ]]
	then
		# Check if host IP is an IPv6 address
		IS_IP6=`echo "$HOST_IP" |grep "\:" |wc -l`
		if [[ "$IS_IP6" -ge "1" ]]
		then
			# skip the check for the IPv6 address
			continue
		fi
	fi

	# replace : and . for the log file name
	HOST_IP_NAME=`echo "$HOST_IP" | sed 's/[:\.]/_/g'`

	# start the time measurement
	if [ "$DETECTED_OS_TYPE" == "Darwin" ]
	then
		START_TIME=`ruby -e "puts Time.now.to_f"`
	else
		START_TIME=`date +%s.%N`
	fi

	# execute the request to this server
	RESULT=`curl $CURL_OPTIONS -i --connect-timeout $CONNECT_TIMEOUT --max-time $CHECK_TIMEOUT -H "Host: $HOST_NAME" $URL_SCHEMA$HOST_IP:$HOST_PORT 2>&1 | tee "$LOG_PATH$HOST_IP_NAME.log" | grep -E "$SEARCH_PATTERN" | wc -l`

	# stop the time measurement
	if [ "$DETECTED_OS_TYPE" == "Darwin" ]
	then
		END_TIME=`ruby -e "puts Time.now.to_f"`
	else
		END_TIME=`date +%s.%N`
	fi

	# check HTTP response code
	if [ "$DETECTED_OS_TYPE" == "Darwin" ]
	then
		HTTP_CODE=`head -n 6 "$LOG_PATH$HOST_IP_NAME.log" | grep "HTTP\/.* 200 OK" | sed -E 's/^.* ([0-9]{3}) .*$/\1/'`
	else
		HTTP_CODE=`head -n 6 "$LOG_PATH$HOST_IP_NAME.log" | grep "HTTP\/.* 200 OK" | sed -r 's/^.* ([0-9]{3}) .*$/\1/'`
	fi
	if [ "$HTTP_CODE" != "200" ]
	then
		RESULT=''
	fi

	# calculate the time needed to request the page
	DIFF_TIME=`echo "$END_TIME - $START_TIME" | bc`

	# check if the trigger time is exceeded
	TRIGGER_EXCEEDED=`echo "$TRIGGER_TIMEOUT - $DIFF_TIME" | bc | grep "-" |wc -l`

	# format the calculated time difference
	DIFF_TIME=`printf "%f" $DIFF_TIME`

	# if the rrdtool db is enabled, update the database
	if [[ "$RRDTOOL_ENABLE" == "YES" ]]; then
		rrdtool_update $MONITOR_TIME $HOST_IP $DIFF_TIME
	fi

	# Check if content is returned
	if [ "$RESULT" != "" ] && [ "$TRIGGER_EXCEEDED" -lt "1" ]
	then
		# check the requersted return format
		case $FORMAT in
			json)
				RESULT_JSON=$RESULT_JSON"{\"ip\":\"$HOST_IP\",\"time\":\"$DIFF_TIME\",\"status\":\"OK\"},"
				;;
			text)
				echo "    Status: OK  , IP: $HOST_IP , Time: $DIFF_TIME"
				;;
			terse)
				RESULT_TERSE=$RESULT_TERSE"    Status: OK  , IP: $HOST_IP , Time: $DIFF_TIME\n"
				;;
		esac

		# define summary status
		if [ "$STATUS_SUMMARY" == "--" ]
		then
			STATUS_SUMMARY="OK"
		fi
		# remove log on success
		rm "$LOG_PATH$HOST_IP_NAME.log"
	else
		# check the requersted return format
		case $FORMAT in
			json)
				RESULT_JSON=$RESULT_JSON"{\"ip\":\"$HOST_IP\",\"time\":\"$DIFF_TIME\",\"status\":\"NOK\"},"
				;;
			text)
				echo "    Status: NOK , IP: $HOST_IP , Time: $DIFF_TIME"
				;;
			terse)
				RESULT_TERSE=$RESULT_TERSE"    Status: NOK , IP: $HOST_IP , Time: $DIFF_TIME\n"
				;;
		esac

		RESULT_TERSE_DETAILS=$RESULT_TERSE_DETAILS"\n\n**********$HOST_IP**********\n"
		if [ "$RESULT" == "" ]; then
			# Add details fro the terse output
			RESULT_LOG_CONTENT=`cat "$LOG_PATH$HOST_IP_NAME.log" | grep -vE "% Total|Dload|--:--:--"`
			RESULT_TERSE_DETAILS=$RESULT_TERSE_DETAILS"$RESULT_LOG_CONTENT\n"
		fi
		if [ "$TRIGGER_EXCEEDED" -gt "0" ]; then
			RESULT_TERSE_DETAILS=$RESULT_TERSE_DETAILS"rrmonitor: Trigger timeout exceeded.\n"
		fi

		# rename log on failure
		mv "$LOG_PATH$HOST_IP_NAME.log" "$LOG_PATH$(date "+%Y-%m-%d_%H-%M-%S_NOK_")$HOST_IP_NAME.log"

		STATUS_SUMMARY="NOK"
	fi
done

# set the number locale back to its original
LC_NUMERIC=$LC_NUMERIC_OLD

# Finish output based on the requested format
# check the requersted return format
case $FORMAT in
	json)
		RESULT_JSON=${RESULT_JSON%?}
		RESULT_JSON=$RESULT_JSON"],\"status\":\"$STATUS_SUMMARY\"}"
		echo -e $RESULT_JSON
		;;
	text)
		echo "Summary: $STATUS_SUMMARY"
		;;
	terse)
		RESULT_TERSE=$RESULT_TERSE"Summary: $STATUS_SUMMARY\n"
		;;
esac

# if the rrdtool db is enabled, update the database
if [[ "$RRDTOOL_GRAPH_ENABLE" == "YES" ]]
then
	rrdtool_graph "$IP_LIST"
fi


if [ "$STATUS_SUMMARY" == "OK" ]
then
	exit 0
else
	RESULT_OUTPUT=`echo "$RESULT_TERSE$RESULT_TERSE_DETAILS" | sed 's/\%/%%/g'`
	printf "$RESULT_OUTPUT\n"
	if [ "$XMPP_NOTIFICATION" == "YES" ]
	then
		MONITORING_HOST=`/bin/hostname -f`
		printf "Monitoring host: $MONITORING_HOST\n$RESULT_OUTPUT\n" | /usr/bin/sendxmpp --username $XMPP_SEND_USER --jserver $XMPP_SERVER --password $XMPP_SEND_PASS $XMPP_OPTIONS $XMPP_RCPT_USER -o $XMPP_RCPT_DOMAIN
	fi
	exit 1
fi

