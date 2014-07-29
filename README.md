round-robin-monitor
===================

This monitoring script will monitor the availability of all web-servers configured in one Round-Robin DNS entry.


Requirements

yum install bind-utils ... for the command "host" which is used to resolve the host name.
yum install bc ........... for calculation of the request time.


Optional Requirements

yum install rrdtool ...... for generating rrd data files and generating graphs.
yum install sendxmpp ..... for sending alert messages via xmpp protocol.
