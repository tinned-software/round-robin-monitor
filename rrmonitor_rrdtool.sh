#!/bin/bash
#
# @author Gerhard Steinbeis (info [at] tinned-software [dot] net)
# @copyright Copyright (c) 2014
version=0.2.1
# @license http://opensource.org/licenses/GPL-3.0 GNU General Public License, version 3
# @package monitoring
#

# Path to the rrdtool binary
if [[ "$RRDTOOL_CMD" == "" ]]
then
	RRDTOOL_CMD="rrdtool"
fi
DS_NAME="value"

function rrdtool_create
{
	#echo "started rrdtool_create $@"

	# Get the parameter 1, the IP_ADDRESS
	IP_ADDRESS=$1
	IP_NAME=`echo "$IP_ADDRESS" | sed 's/[:\.]/_/g'`

	# get the start time for generating the db
	START_TIME=`date +%s`
	START_TIME=$((START_TIME-$RRDTOOL_STEP_TIME))

	# create RRD with an entry every 5 monites and a everage
	$RRDTOOL_CMD create ${RRDTOOL_DBPATH}${IP_NAME}.rrd --start $START_TIME --step=$RRDTOOL_STEP_TIME \
		DS:$DS_NAME:GAUGE:$RRDTOOL_STEP_TIME_MISSING:U:U \
		RRA:AVERAGE:0.5:1:$RRDTOOL_ENTRIES
}



function rrdtool_update
{
	#echo "started rrdtool_update $@"

	# Get the time of the data set
	CURRENT_TIME=$1

	# Get the parameter 2, the IP_ADDRESS
	IP_ADDRESS=$2
	IP_NAME=`echo "$IP_ADDRESS" | sed 's/[:\.]/_/g'`

	# Get the parameter 3, the VALUE
	VALUE=$3
	if [ ! -f "${RRDTOOL_DBPATH}${IP_NAME}.rrd" ]
	then
		rrdtool_create $IP_ADDRESS
	fi

	$RRDTOOL_CMD update ${RRDTOOL_DBPATH}${IP_NAME}.rrd $CURRENT_TIME:${VALUE}
}



function rrdtool_graph
{
	#echo "started rrdtool_graph $@"

	# get parameters as array (IP LIST)
	IP_LIST=(`echo "$@"  | tr ' ' '\n' | sort`)

	# get the current date - end date for the graph
	END_TIME=`date +%s`
	GEN_DATE=`date +"%Y-%m-%d %T %Z"`

	# get all IP addresses for this monitor and add them into the list
	LINE=""
	for (( i=0; i<${#IP_LIST[@]}; i++ ))
	do
		IP_NAME=`echo "${IP_LIST[$i]}" | sed 's/[:\.]/_/g'`
		REG=`echo "${IP_LIST[$i]}" | sed 's/:/\\\:/g'`
		REG_SPECIAL=`echo "$REG" | sed 's/[:\.]/_/g'`
		COLOR=${RRDTOOL_GRAPH_COLORS[$i]}
		LINE="$LINE DEF:$REG_SPECIAL=${RRDTOOL_DBPATH}$IP_NAME.rrd:$DS_NAME:AVERAGE LINE:$REG_SPECIAL#$COLOR:$REG "
	done


	for (( i=0; i<${#RRDTOOL_GRAPH_TIMEFRAME[@]}; i++ ))
	do
		START_TIME=$(($END_TIME-${RRDTOOL_GRAPH_TIMEFRAME[$i]}))
		INTERVAL=`echo "${RRDTOOL_GRAPH_TIMEFRAME_LABLE[$i]}" | sed 's/ /_/g'`
		GRAPH_DETAILS="(Generated: $GEN_DATE, Interval: $INTERVAL)"

		RESULT=`$RRDTOOL_CMD graph $RRDTOOL_GRAPH_PATH/rrmonitor_$INTERVAL.png \
			--start $START_TIME --end $END_TIME \
			--title="Round-Robin-Monitor $GRAPH_DETAILS" \
			--width $RRDTOOL_GRAPH_WIDTH --height $RRDTOOL_GRAPH_HEIGHT \
			--force-rules-legend \
			--slope-mode \
			--units-exponent 1 \
			$LINE`
	done
}
