#!/bin/bash

JOBLIST_SERVER=http://127.0.0.1:8000
JOBLIST_URL=${JOBLIST_SERVER}/api/list
JOBLIST_UPDATE=${JOBLIST_SERVER}/api/update
JOBLIST_FILE=./list.json
PRINTER_NAME=dummy_printer

# 重複起動チェック。すでにファイルが存在する(処理中)の場合は終了する
if [ -f "${JOBLIST_FILE}" ]; then
    echo "${JOBLIST_FILE} exist."
    exit 0;
fi

touch "${JOBLIST_FILE}"

# サーバーから対象ファイルリストを取得する
CURL_STATUS=$(curl -w %{http_code} --silent "${JOBLIST_URL}" --output "${JOBLIST_FILE}")
if [ "${CURL_STATUS}" = "000" ]; then
    echo "ERROR: Could not connect to server."
    rm "${JOBLIST_FILE}"
    exit 1
fi

echo "start print jobs."

# 対象ファイルリストを処理する
cat "${JOBLIST_FILE}" | jq -c '.[]' | while read -r JSONLINE; do
    JOB_ID=$(echo ${JSONLINE} | jq -r '.id') 
    JOB_FILEURL=$(echo ${JSONLINE} | jq -r '.server_filename') 
    JOB_FILEPDF=./printjob/${JOB_ID}.pdf

    # File download
    echo "-----"
    echo "prione job id: ${JOB_ID}," ${JOB_FILEPDF} "from"  ${JOB_FILEURL}
    if [ ! -e "${JOB_FILEPDF}" ]; then
        curl --silent "${JOB_FILEURL}" --output "${JOB_FILEPDF}"
        echo "- download file. ${JOB_FILEURL}"
    fi

    # cups print
    /bin/bash ./watch_print.sh "${JOB_FILEPDF}"
    PRINT_RESULT=$?

    if [ ${PRINT_RESULT} = 0 ]; then
        NOWTIME=$(date +"%Y/%m/%d %I:%M:%S")

        POSTJSON=$(jq -n \
            --arg id "${JOB_ID}" \
            --arg printed_at "${NOWTIME}" \
            '{"id": $id, "printed_at": $printed_at}')
        # echo "${POSTJSON}"

        # result to server
        curl -X POST \
            -H "Content-Type:application/json" \
            -d "${POSTJSON}" \
            --silent \
            "${JOBLIST_UPDATE}/${JOB_ID}" > /dev/null

        # 処理完了後、ファイルを削除する
        rm ./printjob/${JOB_ID}.pdf
    else
        echo "ERROR: Print error. please, check to your printer."
    fi

    sleep 2
done

rm "${JOBLIST_FILE}"

echo "-----"
echo "finish print jobs."
exit 0
