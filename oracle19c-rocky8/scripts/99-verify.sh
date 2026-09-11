#!/bin/bash
# =============================================================================
#  99-verify.sh  :  설치 최종 검증
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.env"
source "${SCRIPT_DIR}/lib/common.sh"

log_step "STEP 99 : 설치 검증"

# 사용자/그룹
log_info "▶ 사용자/그룹"
id "${ORACLE_USER}" || log_warn "oracle 사용자 없음"

# 디렉터리
log_info "▶ 디렉터리 구조"
for d in "${ORACLE_HOME}" "${ORA_INVENTORY}" "${ORADATA_DIR}" "${FRA_DIR}"; do
    if [[ -d "${d}" ]]; then
        log_ok "  ${d} (owner=$(stat -c %U:%G "${d}"))"
    else
        log_warn "  ${d} 없음"
    fi
done

# OPatch/버전
log_info "▶ Oracle 버전"
run_as_oracle "${ORACLE_HOME}/bin/sqlplus -V" | tee -a "${LOG_FILE}"
run_as_oracle "${ORACLE_HOME}/OPatch/opatch lspatches" 2>/dev/null | tee -a "${LOG_FILE}" || true

# 리스너 (config 의 ORACLE_HOME/SID 강제 사용)
log_info "▶ 리스너"
run_as_oracle "export ORACLE_HOME=${ORACLE_HOME}; export ORACLE_SID=${ORACLE_SID}; export PATH=\$ORACLE_HOME/bin:\$PATH; lsnrctl status" 2>&1 | \
    grep -E "STATUS|Uptime|Listening|Service" | tee -a "${LOG_FILE}" || true

# 데이터베이스 상태 (config 의 ORACLE_SID 강제 사용 → ORA-01034 방지)
log_info "▶ 데이터베이스 상태"
run_as_oracle "export ORACLE_HOME=${ORACLE_HOME}; export ORACLE_SID=${ORACLE_SID}; export PATH=\$ORACLE_HOME/bin:\$PATH; sqlplus -S / as sysdba <<EOF
SET PAGES 100 LINES 200
COL name FORMAT A20
COL open_mode FORMAT A12
COL version FORMAT A20
SELECT name, open_mode, cdb, version FROM v\\\$database;
SHOW PDBS
SELECT tablespace_name, bytes/1024/1024 MB FROM dba_data_files ORDER BY 1;
ARCHIVE LOG LIST
EXIT
EOF" 2>&1 | tee -a "${LOG_FILE}"

# systemd
log_info "▶ systemd 서비스"
systemctl is-enabled oracle-db.service 2>&1 | tee -a "${LOG_FILE}" || true
systemctl is-active oracle-db.service 2>&1 | tee -a "${LOG_FILE}" || true

# 접속 테스트
log_info "▶ 원격 접속 문자열 예시"
log_info "  sqlplus system@$(hostname -I | awk '{print $1}'):${DB_PORT}/${ORACLE_PDB}"

log_ok "설치 검증 완료 — 로그: ${LOG_FILE}"
