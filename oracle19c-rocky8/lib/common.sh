#!/bin/bash
# =============================================================================
#  공통 함수 라이브러리
# =============================================================================

# ANSI 색상
readonly C_RED='\033[0;31m'
readonly C_GRN='\033[0;32m'
readonly C_YLW='\033[0;33m'
readonly C_BLU='\033[0;34m'
readonly C_CYN='\033[0;36m'
readonly C_RST='\033[0m'

log_init() {
    mkdir -p "$(dirname "${LOG_FILE}")"
    touch "${LOG_FILE}"
    chmod 644 "${LOG_FILE}"
}

_log() {
    local level="$1"; shift
    local color="$1"; shift
    local msg="$*"
    local ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${color}[${ts}] [${level}] ${msg}${C_RST}"
    echo "[${ts}] [${level}] ${msg}" >> "${LOG_FILE}" 2>/dev/null || true
}

log_info()  { _log "INFO"  "${C_CYN}" "$@"; }
log_ok()    { _log "OK"    "${C_GRN}" "$@"; }
log_warn()  { _log "WARN"  "${C_YLW}" "$@"; }
log_error() { _log "ERROR" "${C_RED}" "$@"; }
log_step()  { echo; _log "STEP"  "${C_BLU}" "==================== $* ===================="; }

die() {
    log_error "$*"
    log_error "설치를 중단합니다. 로그: ${LOG_FILE}"
    exit 1
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        die "root 권한이 필요합니다. sudo 로 실행하세요."
    fi
}

confirm() {
    local prompt="${1:-계속 진행하시겠습니까?}"
    read -r -p "${prompt} [y/N]: " reply
    [[ "${reply,,}" == "y" || "${reply,,}" == "yes" ]]
}

run_as_oracle() {
    su - "${ORACLE_USER}" -c "$*"
}

command_exists() {
    command -v "$1" &>/dev/null
}

# 패키지 존재 여부 (RPM)
rpm_installed() {
    rpm -q "$1" &>/dev/null
}

# ORACLE_USER 환경 조회 (홈 디렉터리 등)
oracle_home_dir() {
    getent passwd "${ORACLE_USER}" | cut -d: -f6
}
