#!/bin/bash

###############################################
####################config#####################
##### 쉘 색상 정의
GREEN='\033[0;32m'
RESET='\033[0m'

##### set TIME
YMD="2026-07-03"
HMS="22:30:00"

##### set command
command(){
	/home/markany/stop.sh all
	shutdown -h now
}

###############################################
###############################################

NOWTIME=$(date +%s)
UNIXTIME=$(date +%s --date "$YMD $HMS")

# 남은 시간(초) 계산
TARGET_SLEEP=$(( UNIXTIME - NOWTIME ))

if [ ${TARGET_SLEEP} -gt 0 ]; then
    echo -e "${GREEN}${YMD} ${HMS}에 실행 됩니다. (남은 시간: ${TARGET_SLEEP}초)${RESET}"

    # 설정한 시간까지 한 번에 대기 (3초마다 반복 호출하지 않음)
    sleep ${TARGET_SLEEP}
else
    echo -e "${GREEN}설정 시간이 이미 지났습니다. 즉시 실행합니다.${RESET}"
fi

##### command 함수 호출
command
