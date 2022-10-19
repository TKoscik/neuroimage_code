#!/bin/sh
#
# chkconfig: 2345 80 20
# description:

Start=""
Stop=""
Check='metamap'
# number of seconds we're willing to wait for Java to stop before killing it:
MAXWAIT=15

RETVAL=0


. /etc/rc.d/init.d/functions


wait_a_second() {
        sleep 1
        echo -n "."
}

case "$1" in
        start)
                echo "Starting $Check"
                $Start
                RETVAL=$?
        ;;
        stop)
                echo "Stopping $Check"
                $Stop
                STILL_LIVING=0
                WAITED=0
                while [ $STILL_LIVING -eq 0 ] && [ $((MAXWAIT - WAITED)) -gt 0 ]; do
                        ps aux | grep $Check | grep java | grep -v grep &>/dev/null
                        STILL_LIVING=$?
                        if [ $STILL_LIVING -eq 0 ]; then
                                wait_a_second
                                let WAITED=$WAITED+1
                        fi
                done
                # if it's not stopped after MAXWAIT seconds, kill it:
                THISPID=$(ps aux | grep $Check | grep java | grep -v grep | awk '{print $2}')
                if [ -n "$THISPID" ]; then
                        kill -9 $THISPID
                fi
		##RM extra files?
                RETVAL=$?
                echo "done."
        ;;
        restart)
                $0 stop
                $0 start
                RETVAL=$?
        ;;
        *)
                echo "Usage: $0 {start|stop|restart}"
                exit 1
esac

exit $RETVAL

