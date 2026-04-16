#!/bin/bash

# ==============================================================================
# 시스템명: 통합 패치 관리 도구 (Linux)
# 작성일자: 2026-04-16
# 주요기능: 사전검증, 안전백업(cp), 배포, 복구, 자동상태확인, 로깅
# ==============================================================================

# 1. 경로 및 설정
SCRIPT_DIR=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
FILE_LIST="${SCRIPT_DIR}/patch_list.txt"
PATH_MAP="${SCRIPT_DIR}/path_map.txt"
LOG_FILE="${SCRIPT_DIR}/patch.log"
BK_EXT="_bk"

# 로그 기록 함수
function log_msg() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# 2. 데이터 로드 (Map 데이터 로드)
declare -A MASTER_PATHS
if [ ! -f "$PATH_MAP" ]; then
    log_msg "[ERROR] 마스터 경로 맵 파일이 없습니다: $PATH_MAP"
    exit 1
fi

while read -r line || [ -n "$line" ]; do
    [ -z "$line" ] && continue
    # 전체 경로에서 파일명만 추출하여 Key로 저장
    filename="${line##*/}"
    MASTER_PATHS["$filename"]="$line"
done < "$PATH_MAP"

# 3. 사전 검증 함수
function validate_all() {
    local mode=$1
    local error_found=0
    
    log_msg "------------------------------------------------------"
    log_msg "[STEP 1] 사전 검증을 시작합니다... (Mode: $mode)"

    if [ ! -f "$FILE_LIST" ]; then
        log_msg "  [FAIL] 패치 리스트 파일이 없습니다: $FILE_LIST"
        exit 1
    fi

    while read -r entry || [ -n "$entry" ]; do
        [ -z "$entry" ] && continue
        
        # 절대경로 여부에 따른 소스 경로 결정
        if [[ "$entry" == /* ]]; then
            SRC_PATH="$entry"
        else
            SRC_PATH="${SCRIPT_DIR}/${entry}"
        fi
        
        filename="${entry##*/}"

        # A. path_map 등록 여부 체크
        if [ -z "${MASTER_PATHS[$filename]}" ]; then
            log_msg "  [FAIL] '$filename' -> path_map.txt에 정보가 없습니다."
            error_found=1
        fi

        # B. 배포 시 물리적 파일 존재 여부 체크
        if [[ "$mode" == "deploy" || "$mode" == "all" ]]; then
            if [ ! -f "$SRC_PATH" ]; then
                log_msg "  [FAIL] '$SRC_PATH' -> 배포할 파일이 존재하지 않습니다."
                error_found=1
            fi
        fi
    done < "$FILE_LIST"

    if [ $error_found -eq 1 ]; then
        log_msg "[FATAL] 검증 실패! 작업을 중단합니다."
        log_msg "------------------------------------------------------"
        exit 1
    fi
    log_msg "  [PASS] 모든 검증 통과."
}

# 4. 작업 실행 함수
function run_task() {
    local mode=$1
    local count=0
    
    # check 모드가 아닐 때만 시작 로그 기록
    if [ "$mode" != "check" ]; then
        log_msg "------------------------------------------------------"
        log_msg "[STEP 2] $mode 작업을 실행합니다..."
    else
        echo "------------------------------------------------------"
        echo "[STATUS] 현재 파일 상태를 확인합니다..."
    fi

    while read -r entry || [ -n "$entry" ]; do
        [ -z "$entry" ] && continue

        if [[ "$entry" == /* ]]; then SRC_PATH="$entry"; else SRC_PATH="${SCRIPT_DIR}/${entry}"; fi
        filename="${entry##*/}"
        TARGET_PATH="${MASTER_PATHS[$filename]}"

        case "$mode" in
            backup)
                if [ -f "$TARGET_PATH" ]; then
                    cp -a "$TARGET_PATH" "${TARGET_PATH}${BK_EXT}"
                    log_msg "  - [OK] Backup Created: ${filename}${BK_EXT}"
                else
                    log_msg "  - [SKIP] 원본 없음: $filename"
                fi
                ;;
            deploy)
                if [ -f "$SRC_PATH" ]; then
                    cp -a "$SRC_PATH" "$TARGET_PATH"
                    log_msg "  - [OK] Deployed: $filename"
                fi
                ;;
            restore)
                if [ -f "${TARGET_PATH}${BK_EXT}" ]; then
                    rm -f "$TARGET_PATH"
                    mv "${TARGET_PATH}${BK_EXT}" "$TARGET_PATH"
                    log_msg "  - [OK] Restored: $filename"
                else
                    log_msg "  - [SKIP] 백업본 없음: $filename"
                fi
                ;;
            check)
                echo "  < $filename 상태 확인 >"
                [ -f "$TARGET_PATH" ] && ls -l "$TARGET_PATH" || echo "    (운영 파일 없음)"
                [ -f "${TARGET_PATH}${BK_EXT}" ] && ls -l "${TARGET_PATH}${BK_EXT}" || echo "    (백업 파일 없음)"
                echo ""
                ;;
        esac
        ((count++))
    done < "$FILE_LIST"

    if [ "$mode" != "check" ]; then
        log_msg "[COMPLETE] $count건의 $mode 작업이 완료되었습니다."
    fi
}

# 5. 실행부
case "$1" in
    backup|deploy|restore)
        validate_all "$1"
        run_task "$1"
        run_task check
        ;;
    check)
        validate_all "check"
        run_task check
        ;;
    all)
        validate_all "all"
        run_task backup
        run_task deploy
        run_task check
        ;;
    *)
        echo "Usage: $0 {backup|deploy|restore|check|all}"
        ;;
esac
