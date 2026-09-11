#!/bin/bash
# =============================================================================
#  07-listener.sh  :  리스너 생성 및 기동
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.env"
source "${SCRIPT_DIR}/lib/common.sh"

require_root
log_step "STEP 07 : 리스너 생성"

if [[ ! -f "${ORACLE_HOME}/bin/netca" ]]; then
    die "netca 를 찾을 수 없습니다: ${ORACLE_HOME}/bin/netca"
fi

# NetCA response 파일 (기본 파일 그대로 사용)
NETCA_RSP="${ORACLE_HOME}/assistants/netca/netca.rsp"
if [[ ! -f "${NETCA_RSP}" ]]; then
    die "NetCA response 파일 없음: ${NETCA_RSP}"
fi

log_info "NetCA silent 실행"
run_as_oracle "export ORACLE_HOME=${ORACLE_HOME}; export ORACLE_SID=${ORACLE_SID}; export PATH=\$ORACLE_HOME/bin:\$PATH; ${ORACLE_HOME}/bin/netca -silent -responseFile ${NETCA_RSP}" \
    2>&1 | tee -a "${LOG_FILE}"

sleep 3

# ----- 상태 확인 -----
log_info "리스너 상태 확인"
LSNR_STATUS=$(run_as_oracle "export ORACLE_HOME=${ORACLE_HOME}; export ORACLE_SID=${ORACLE_SID}; export PATH=\$ORACLE_HOME/bin:\$PATH; lsnrctl status" 2>&1 || true)
echo "${LSNR_STATUS}" | tee -a "${LOG_FILE}"

if echo "${LSNR_STATUS}" | grep -q "STATUS of the LISTENER"; then
    log_ok "리스너 정상 기동"
else
    log_warn "리스너 상태 확인 실패 — 수동 확인 필요"
fi

# ----- 방화벽 재확인 -----
if command_exists firewall-cmd && systemctl is-active --quiet firewalld; then
    if ! firewall-cmd --list-ports | grep -q "${DB_PORT}/tcp"; then
        firewall-cmd --permanent --add-port=${DB_PORT}/tcp &>>"${LOG_FILE}"
        firewall-cmd --reload &>>"${LOG_FILE}"
    fi
fi

log_ok "STEP 07 완료"
