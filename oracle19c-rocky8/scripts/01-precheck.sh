#!/bin/bash
# =============================================================================
#  01-precheck.sh  :  시스템 사전 요구사항 검사 (Rocky 8/9 지원)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.env"
source "${SCRIPT_DIR}/lib/common.sh"

log_step "STEP 01 : 시스템 사전 점검"

# ----- OS 확인 -----
if [[ ! -f /etc/redhat-release ]]; then
    die "지원되지 않는 OS 입니다. Rocky/RHEL/OL 8.x 또는 9.x 가 필요합니다."
fi

OS_ID=$(awk -F= '/^ID=/{gsub(/"/,"",$2); print $2}' /etc/os-release)
OS_VER=$(awk -F= '/^VERSION_ID=/{gsub(/"/,"",$2); print $2}' /etc/os-release)
OS_MAJOR="${OS_VER%%.*}"
log_info "OS: ${OS_ID} ${OS_VER}"

case "${OS_ID}" in
    rocky|rhel|almalinux|ol|centos)
        case "${OS_MAJOR}" in
            8|9) log_ok "지원되는 major 버전: ${OS_MAJOR}" ;;
            *)   die "지원되지 않는 major 버전: ${OS_MAJOR} (8 또는 9 필요)" ;;
        esac
        ;;
    *)
        die "지원되지 않는 배포판입니다: ${OS_ID}"
        ;;
esac

# TARGET_OS 자동 검증
if [[ "${TARGET_OS}" == "rocky8" && "${OS_MAJOR}" != "8" ]]; then
    log_warn "config.env 의 TARGET_OS=${TARGET_OS} 이지만 실제 OS 는 major=${OS_MAJOR}"
    log_warn "TARGET_OS 값을 실제 OS 에 맞게 수정하세요."
fi
if [[ "${TARGET_OS}" == "rocky9" && "${OS_MAJOR}" != "9" ]]; then
    log_warn "config.env 의 TARGET_OS=${TARGET_OS} 이지만 실제 OS 는 major=${OS_MAJOR}"
fi

# ----- 커널 -----
KERNEL_VER=$(uname -r)
log_info "커널: ${KERNEL_VER}"

# ----- 메모리 -----
MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
MEM_MB=$((MEM_KB / 1024))
MEM_GB=$((MEM_MB / 1024))
log_info "메모리: ${MEM_MB} MB (${MEM_GB} GB)"

if [[ ${MEM_MB} -lt 2048 ]]; then
    die "Oracle 19c 는 최소 2GB 이상의 RAM 이 필요합니다. (현재: ${MEM_MB} MB)"
fi

if [[ ${MEM_MB} -lt "${DB_TOTAL_MEMORY_MB}" ]]; then
    log_warn "설정된 DB 메모리(${DB_TOTAL_MEMORY_MB} MB) 가 시스템 RAM 보다 큽니다."
fi

# ----- 스왑 -----
SWAP_KB=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
SWAP_MB=$((SWAP_KB / 1024))
log_info "스왑: ${SWAP_MB} MB"

if [[ ${MEM_MB} -le 2048 ]]; then
    REQ_SWAP=$((MEM_MB * 3 / 2))
elif [[ ${MEM_MB} -le 16384 ]]; then
    REQ_SWAP=${MEM_MB}
else
    REQ_SWAP=16384
fi

if [[ ${SWAP_MB} -lt ${REQ_SWAP} ]]; then
    log_warn "권장 스왑(${REQ_SWAP} MB) 보다 작습니다. (현재: ${SWAP_MB} MB)"
fi

# ----- 디스크 -----
check_disk() {
    local mount="$1"
    local required_gb="$2"
    # 존재하는 상위 경로로 자동 대체 (INS-32012 및 df 실패 방지)
    local check_path="${mount}"
    while [[ ! -d "${check_path}" && "${check_path}" != "/" ]]; do
        check_path=$(dirname "${check_path}")
    done
    local avail_kb
    avail_kb=$(df -Pk "${check_path}" 2>/dev/null | awk 'NR==2{print $4}' || echo "")
    if [[ -z "${avail_kb}" ]]; then
        log_warn "${mount} 마운트 포인트 확인 불가 (skip)"
        return 0
    fi
    local avail_gb=$((avail_kb / 1024 / 1024))
    if [[ "${check_path}" != "${mount}" ]]; then
        log_info "${mount} → ${check_path} 로 대체 검사, 여유 공간: ${avail_gb} GB"
    else
        log_info "${mount} 여유 공간: ${avail_gb} GB"
    fi
    if [[ ${avail_gb} -lt ${required_gb} ]]; then
        log_warn "${mount} 여유 공간이 부족합니다. (권장: ${required_gb} GB 이상)"
    fi
    return 0
}

check_disk "/tmp" 1
check_disk "/" 10
for d in "$(dirname "${ORACLE_BASE}")" "$(dirname "${ORADATA_DIR}")" "$(dirname "${FRA_DIR}")"; do
    check_disk "${d}" 5
done

# ----- 호스트명 -----
HN=$(hostname)
log_info "호스트명: ${HN}"
if ! grep -qE "^[0-9\.]+[[:space:]]+.*${HN}" /etc/hosts; then
    log_warn "/etc/hosts 에 '${HN}' 항목이 없습니다. 03 단계에서 자동 추가됩니다."
fi

# ----- 필수 명령어 -----
for cmd in unzip tar gcc make wget curl; do
    if ! command_exists "${cmd}"; then
        log_warn "명령어 없음: ${cmd} (02-packages.sh 에서 설치됩니다)"
    fi
done

# ----- 설치 파일 확인 -----
log_info "설치 파일 확인 중: ${INSTALL_STAGE}"

if [[ ! -f "${DB_ZIP_FILE}" ]]; then
    log_error "누락(필수): ${DB_ZIP_FILE}"
    log_error "Oracle 공식 사이트에서 LINUX.X64_193000_db_home.zip 다운로드 후 업로드하세요."
else
    log_ok "확인: $(basename "${DB_ZIP_FILE}") ($(du -h "${DB_ZIP_FILE}" | awk '{print $1}'))"
fi

if [[ -f "${PREINSTALL_RPM}" ]]; then
    log_ok "확인: $(basename "${PREINSTALL_RPM}")"
    log_info "  → Rocky 8 에서는 이 el7 RPM 을 강제 설치(--nodeps)로 사용 가능"
else
    log_warn "누락: ${PREINSTALL_RPM}"
    log_warn "  → OL8 저장소의 oracle-database-preinstall-19c 를 대신 사용 시도"
fi

# ----- RU 파일 확인 (옵션) -----
if [[ "${APPLY_RU}" == "true" ]]; then
    ru_missing=0
    for f in "${RU_ZIP_FILE}" "${OPATCH_ZIP_FILE}"; do
        if [[ ! -f "${f}" ]]; then
            log_error "RU 파일 누락: ${f}"
            ru_missing=$((ru_missing+1))
        else
            log_ok "확인: $(basename "${f}")"
        fi
    done
    if [[ ${ru_missing} -gt 0 ]]; then
        die "APPLY_RU=true 인데 RU 파일이 없습니다. config.env 확인."
    fi
else
    log_info "APPLY_RU=false — base 19.3 만 설치합니다."
    log_info "Rocky 8.10 에서는 이 조합으로도 정상 설치됩니다."
fi

# ----- 인터넷 접근 확인 -----
log_info "yum.oracle.com 접근 확인"
if curl -s --max-time 5 -o /dev/null -w "%{http_code}" https://yum.oracle.com/ | grep -q "^[23]"; then
    log_ok "yum.oracle.com 접근 가능 → OL8 저장소 활용 가능"
    export INTERNET_AVAILABLE="true"
else
    log_warn "yum.oracle.com 접근 불가 → 로컬 el7 RPM 만 사용"
    export INTERNET_AVAILABLE="false"
fi

log_ok "STEP 01 완료"
