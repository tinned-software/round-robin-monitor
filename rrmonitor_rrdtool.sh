#!/bin/bash
#
# @author Gerhard Steinbeis (info [at] tinned-software [dot] net)
# @copyright Copyright (c) 2014
version=0.0.2
# @license http://opensource.org/licenses/GPL-3.0 GNU General Public License, version 3
# @package monitoring
#

# Path to the rrdtool binary
RRD_CMD="/usr/local/bin/rrdtool"


function rrdtool_create
{
	# Get the parameter 1, the IP_ADDRESS
	IP_ADDRESS=$1

	# get the start time for generating the db
	START_TIME=`date +%s`

	# create RRD with an entry every 5 monites and a everage 
	$RRD_CMD create ${RRDTOOL_DBPATH}${IP_ADDRESS}.rrd --start $START_TIME --step=$RRDTOOL_STEP_TIME \
		DS:value:GAUGE:$RRDTOOL_STEP_TIME_MISSING:U:U \
		RRA:AVERAGE:0.5:1:$RRDTOOL_ENTRIES}
}



function rrdtool_update
{
	# Get the time of the data set
	CURRENT_TIME=$1

	# Get the parameter 1, the IP_ADDRESS
	IP_ADDRESS=$2

	# Get the parameter 2, the VALUE
	VALUE=$3

	$RRD_CMD update ${RRDTOOL_DBPATH}${IP_ADDRESS}.rrd $CURRENT_TIME:${VALUE}
}



function rrdtool_graph
{
	# get parameters as array (IP LIST)
	IP_LIST=(`echo "$@"  | tr ' ' '\n' | sort`)

	# get the current date - end date for the graph
	END_TIME=`date +%s`
	GEN_DATE=`date +"%Y-%m-%d %T"`

	# get all IP addresses for this monitor and add them into the list
	LINE=""
	for (( i=0; i<${#IP_LIST[@]}; i++ ))
	do
		REG=${IP_LIST[$i]}
		REG_SPECIAL=`echo "$REG" | sed 's/\./_/g'`
		COLOR=${RRDTOOL_GRAPH_COLORS[$i]}
		LINE="$LINE DEF:$REG_SPECIAL=${RRDTOOL_DBPATH}$REG.rrd:value:AVERAGE LINE:$REG_SPECIAL#$COLOR:$REG "
	done


	for (( i=0; i<${#RRDTOOL_TIMEFRAME[@]}; i++ ))
	do
		START_TIME=$(($END_TIME-${RRDTOOL_TIMEFRAME[$i]}))
		INTERVAL=${RRDTOOL_TIMEFRAME_LABLE[$i]}
		GRAPH_DETAILS="(Generated: $GEN_DATE, Interval: $INTERVAL)"

		RESULT=`$RRD_CMD graph $RRDTOOL_GRAPH_PATH/rrmonitor_$INTERVAL.png \
			--start $START_TIME --end $END_TIME \
			--title="Round-Robin-Monitor $GRAPH_DETAILS" \
			--width $RRDTOOL_GRAPH_WIDTH --height $RRDTOOL_GRAPH_HEIGHT \
			--legend-position=south \
			--force-rules-legend \
			--slope-mode \
			--units-exponent 1 \
			--imginfo '' \
			$LINE`

	done
}