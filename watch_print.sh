#!/bin/bash

# Watch_print.sh
#   Copyright (c) 2022 YANO Yasuhiro

PRINTER_HOST=127.0.0.1:631
PRINTER_NAME=dummy_printer
SLEEP_TIME=3s
MAX_LOOPCOUNT=40

if [ $# -ne 1 ]; then
  exit 1
fi

TARGET_FILENAME=$1
echo "- print to ${PRINTER_NAME} (${PRINTER_HOST})."

# printing
LP_CMD_RUN=$(lp -E -h ${PRINTER_HOST} -d ${PRINTER_NAME} "${TARGET_FILENAME}")
LP_QUEUENAME=$(echo ${LP_CMD_RUN} | awk '{print $4}')

LOOP_COUNT=1
while :
do
    # wait
    sleep ${SLEEP_TIME}

    # get printer status
    LPSTAT_CMD_RUN=$(lpstat -h ${PRINTER_HOST} -p ${PRINTER_NAME})
    read STRING_3 STRING_4 STRING_5 <<< $(echo ${LPSTAT_CMD_RUN} | awk '{print $3, $4, $5}')

    # complite?
    if [ "${STRING_3}" = "is" ] && [ "${STRING_4}" = "idle." ]; then
        break
    fi

    # another print-job?
    if [ "${STRING_5}" != "${LP_QUEUENAME}." ]; then
        echo "- finish..? (another job printing, target job:${LP_QUEUENAME} / now printing job:${STRING_5})"
        exit 2
        break
    fi

    # printer error ?
    if [ ${LOOP_COUNT} -gt ${MAX_LOOPCOUNT} ]; then
        echo "- finish..? (over wait count)"
        exit 4
        break
    fi

    echo "-- ${LP_QUEUENAME}: ${STRING_3} ${STRING_4} (${LOOP_COUNT})"

    LOOP_COUNT=`expr ${LOOP_COUNT} + 1`
done

sleep 1

echo "- print complited!"
exit 0
