#!/bin/bash
# =============================================================================
#  Oracle Database 19c on Rocky Linux 8.10 - 통합 설치 스크립트
#
#  사용법:
#    sudo ./install.sh                # 전체 단계 순차 실행
#    sudo ./install.sh --step 03      # 특정 단계만 실행
#    sudo ./install.sh --from 06      # 특정 단계부터 끝까지 실행
#    sudo ./install.sh --list         # 실행 가능한 단계 목록
#    sudo ./install.sh --dry-run      # 실제 실행 없이 순서만 표시
#    sudo ./install.sh --yes          # 확인 프롬프트 자동 승인
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.env"
source "${SCRIPT_DIR}/lib/common.sh"

# 실행 순서 정의
declare -a STEPS=(
    "01-precheck.sh"
    "02-packages.sh"
    "03-sysconfig.sh"
    "04-users.sh"
    "05-env.sh"
    "06-install-db.sh"
    "07-listener.sh"
    "08-dbca.sh"
    "09-systemd.sh"
    "99-verify.sh"
)

usage() {
    grep '^#' "$0" | sed 's/^# \{0,1\}//' | head -20
    exit 0
}

list_steps() {
    echo "실행 가능한 단계:"
    for s in "${STEPS[@]}"; do
        echo "  - ${s}"
    done
    exit 0
}

# ----- 파라미터 파싱 -----
STEP_ONLY=""
STEP_FROM=""
DRY_RUN="false"
AUTO_YES="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)      usage ;;
        --list)         list_steps ;;
        --step)         STEP_ONLY="$2"; shift 2 ;;
        --from)         STEP_FROM="$2"; shift 2 ;;
        --dry-run)      DRY_RUN="true"; shift ;;
        --yes|-y)       AUTO_YES="true"; shift ;;
        *) die "알 수 없는 옵션: $1  (--help 참고)" ;;
    esac
done

# ----- 초기화 -----
require_root
log_init

log_step "Oracle 19c on Rocky Linux 8.10 - 통합 설치 시작"
log_info "설치 로그: ${LOG_FILE}"
log_info "설정 파일: ${SCRIPT_DIR}/config.env"
log_info "ORACLE_HOME: ${ORACLE_HOME}"
log_info "ORACLE_SID : ${ORACLE_SID}"
log_info "PDB       : ${ORACLE_PDB}"

# 실행 대상 스텝 계산
declare -a RUN_STEPS=()
if [[ -n "${STEP_ONLY}" ]]; then
    for s in "${STEPS[@]}"; do
        if [[ "${s}" == "${STEP_ONLY}"* ]]; then
            RUN_STEPS=("${s}")
            break
        fi
    done
    [[ ${#RUN_STEPS[@]} -eq 0 ]] && die "일치하는 단계 없음: ${STEP_ONLY}"
elif [[ -n "${STEP_FROM}" ]]; then
    FOUND="false"
    for s in "${STEPS[@]}"; do
        if [[ "${s}" == "${STEP_FROM}"* ]]; then FOUND="true"; fi
        [[ "${FOUND}" == "true" ]] && RUN_STEPS+=("${s}")
    done
    [[ ${#RUN_STEPS[@]} -eq 0 ]] && die "일치하는 시작 단계 없음: ${STEP_FROM}"
else
    RUN_STEPS=("${STEPS[@]}")
fi

# 실행 계획 표시
log_info "실행 계획:"
for s in "${RUN_STEPS[@]}"; do
    log_info "  → ${s}"
done

if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "--dry-run 모드: 실제 실행하지 않고 종료합니다."
    exit 0
fi

# DBCA 단계에서 사용할 비밀번호는 저장소나 로그에 기록하지 않는다.
needs_dbca="false"
for s in "${RUN_STEPS[@]}"; do
    [[ "${s}" == "08-dbca.sh" ]] && needs_dbca="true"
done

read_secret() {
    local var_name="$1" prompt="$2" value="${!1:-}"
    if [[ -z "${value}" ]]; then
        [[ -t 0 ]] || die "${var_name} 환경변수가 필요합니다. 대화형 실행 또는 sudo -E를 사용하세요."
        read -r -s -p "${prompt}: " value
        echo
    fi
    [[ ${#value} -ge 8 ]] || die "${var_name}은 8자 이상이어야 합니다."
    [[ "${value}" =~ ^[A-Za-z0-9_#.-]+$ ]] || die "${var_name}에는 영문, 숫자, _, #, ., -만 사용할 수 있습니다."
    printf -v "${var_name}" '%s' "${value}"
    export "${var_name}"
}

if [[ "${needs_dbca}" == "true" ]]; then
    read_secret SYS_PASSWORD "SYS 비밀번호"
    read_secret SYSTEM_PASSWORD "SYSTEM 비밀번호"
    read_secret PDB_ADMIN_PASSWORD "PDBADMIN 비밀번호"
fi

if [[ "${AUTO_YES}" != "true" ]]; then
    if ! confirm "위 단계를 진행하시겠습니까?"; then
        die "사용자 취소"
    fi
fi

# ----- 순차 실행 -----
START_TS=$(date +%s)
for step in "${RUN_STEPS[@]}"; do
    script="${SCRIPT_DIR}/scripts/${step}"
    if [[ ! -x "${script}" ]]; then
        chmod +x "${script}" 2>/dev/null || true
    fi
    if [[ ! -f "${script}" ]]; then
        die "스크립트 없음: ${script}"
    fi

    log_info "▶ 실행: ${step}"
    STEP_START=$(date +%s)

    if ! bash "${script}"; then
        die "단계 실패: ${step}  (로그: ${LOG_FILE})"
    fi

    STEP_END=$(date +%s)
    log_ok "◀ 완료: ${step}  ($((STEP_END - STEP_START))초)"
done

END_TS=$(date +%s)
TOTAL=$((END_TS - START_TS))

log_step "설치 완료"
log_ok "총 소요 시간: $((TOTAL / 60))분 $((TOTAL % 60))초"
log_ok "로그 파일  : ${LOG_FILE}"
log_ok "SQL*Plus  : su - ${ORACLE_USER} -c 'sqlplus / as sysdba'"
log_ok "PDB 접속  : sqlplus system@localhost:${DB_PORT}/${ORACLE_PDB}"

cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ⚠  보안 권장 사항
     - 입력한 초기 비밀번호를 설치 후 정책에 맞게 변경하세요
     - SELinux 정책을 프로덕션 요건에 맞게 재조정하세요
     - 방화벽 규칙을 최소 필요 IP 로 제한하세요
     - RMAN 백업 정책을 설정하세요
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
