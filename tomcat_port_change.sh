#!/bin/bash

TOMCAT_CONF="/home/markany/tomcat9/conf/server.xml"

OLD_PORT="$1"
NEW_PORT="$2"

# 인자 체크
if [ $# -ne 2 ]; then
    echo "사용법: $0 <기존포트> <변경할포트>"
    exit 1
fi

# 숫자 검증
if ! [[ "$OLD_PORT" =~ ^[0-9]+$ && "$NEW_PORT" =~ ^[0-9]+$ ]]; then
    echo "에러: 포트는 숫자여야 합니다."
    exit 1
fi

# 동일 포트 방지
if [ "$OLD_PORT" = "$NEW_PORT" ]; then
    echo "에러: 기존 포트와 변경 포트가 같습니다."
    exit 1
fi

# 새 포트 사용 중 여부 체크
if ss -lnt | grep -q ":$NEW_PORT "; then
    echo "에러: 포트 $NEW_PORT 는 이미 사용 중입니다."
    exit 1
fi

# 백업
BACKUP_FILE="${TOMCAT_CONF}.$(date +%Y%m%d%H%M%S).bak"
cp "$TOMCAT_CONF" "$BACKUP_FILE" || {
    echo "에러: 백업 실패"
    exit 1
}

# Connector 블록 내에서 port 변경
sed -i "/<Connector/,/>/ s/port=\"$OLD_PORT\"/port=\"$NEW_PORT\"/" "$TOMCAT_CONF"

# 변경 확인
if grep -q "port=\"$NEW_PORT\"" "$TOMCAT_CONF"; then
    echo "✅ Tomcat 포트 변경 완료: $OLD_PORT → $NEW_PORT"
    echo "📦 백업 파일: $BACKUP_FILE"
else
    echo "❌ 포트 변경 실패 (롤백 필요)"
    cp "$BACKUP_FILE" "$TOMCAT_CONF"
    exit 1
fi
