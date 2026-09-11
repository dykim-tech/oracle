#!/bin/bash
# =============================================================================
#  08-dbca.sh  :  데이터베이스 생성 (CDB + PDB)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.env"
source "${SCRIPT_DIR}/lib/common.sh"

require_root
log_step "STEP 08 : 데이터베이스 생성 (dbca)"

if [[ ! -f "${ORACLE_HOME}/bin/dbca" ]]; then
    die "dbca 를 찾을 수 없습니다: ${ORACLE_HOME}/bin/dbca"
fi

# 이미 SID 로 등록되어 있는지 확인
if grep -q "^${ORACLE_SID}:" /etc/oratab 2>/dev/null; then
    log_warn "이미 /etc/oratab 에 ${ORACLE_SID} 가 등록되어 있습니다."
    if ! confirm "그래도 새 DB 를 생성하시겠습니까?"; then
        log_info "DBCA 단계 건너뜀"
        exit 0
    fi
fi

log_info "DBCA silent 실행 (15~30분 소요)"
log_info "  SID       : ${ORACLE_SID}"
log_info "  PDB       : ${ORACLE_PDB}"
log_info "  Charset   : ${DB_CHARSET}"
log_info "  Memory    : ${DB_TOTAL_MEMORY_MB} MB"
log_info "  Datafile  : ${ORADATA_DIR}"
log_info "  FRA       : ${FRA_DIR} (${DB_FRA_SIZE_MB} MB)"

DBCA_CMD="source ~/.bash_profile && ${ORACLE_HOME}/bin/dbca -silent -createDatabase \
    -templateName General_Purpose.dbc \
    -gdbName ${ORACLE_SID} \
    -sid ${ORACLE_SID} \
    -createAsContainerDatabase true \
    -numberOfPDBs 1 \
    -pdbName ${ORACLE_PDB} \
    -pdbAdminPassword '${PDB_ADMIN_PASSWORD}' \
    -sysPassword '${SYS_PASSWORD}' \
    -systemPassword '${SYSTEM_PASSWORD}' \
    -characterSet ${DB_CHARSET} \
    -nationalCharacterSet ${DB_NCHARSET} \
    -databaseType MULTIPURPOSE \
    -memoryMgmtType AUTO_SGA \
    -totalMemory ${DB_TOTAL_MEMORY_MB} \
    -storageType FS \
    -datafileDestination ${ORADATA_DIR} \
    -recoveryAreaDestination ${FRA_DIR} \
    -recoveryAreaSize ${DB_FRA_SIZE_MB} \
    -enableArchive ${DB_ARCHIVE_MODE} \
    -redoLogFileSize ${DB_REDO_SIZE_MB} \
    -listeners LISTENER \
    -emConfiguration NONE \
    -sampleSchema false \
    -ignorePreReqs"

set +e
run_as_oracle "${DBCA_CMD}" 2>&1 | tee -a "${LOG_FILE}"
DBCA_RC=${PIPESTATUS[0]}
set -e

if [[ ${DBCA_RC} -ne 0 ]]; then
    log_warn "DBCA 종료코드: ${DBCA_RC}"
    log_warn "로그 확인: ${ORACLE_BASE}/cfgtoollogs/dbca/${ORACLE_SID}/"
fi

# ----- .bash_profile 갱신 (config.env 의 최신 ORACLE_SID 반영) -----
# 재실행 시 이전 값이 남아 있을 수 있으므로 강제 갱신
log_info ".bash_profile 의 ORACLE_SID 를 ${ORACLE_SID} 로 재동기화"
ORA_HOME_DIR="$(oracle_home_dir)"
if [[ -f "${ORA_HOME_DIR}/.bash_profile" ]]; then
    sed -i "s|^export ORACLE_SID=.*|export ORACLE_SID=${ORACLE_SID}|" "${ORA_HOME_DIR}/.bash_profile"
fi

# ----- 상태 확인 (ORACLE_SID 를 강제 export 해서 mismatch 방지) -----
log_info "데이터베이스 상태 확인"
STATUS=$(run_as_oracle "export ORACLE_HOME=${ORACLE_HOME}; export ORACLE_SID=${ORACLE_SID}; export PATH=\$ORACLE_HOME/bin:\$PATH; echo 'SELECT status FROM v\$instance;
SELECT name, open_mode FROM v\$database;
SHOW PDBS' | sqlplus -S / as sysdba" 2>&1 || true)
echo "${STATUS}" | tee -a "${LOG_FILE}"

# ----- PDB 오픈 및 자동 오픈 상태 저장 (이미 열려 있어도 무해하게 처리) -----
log_info "PDB 오픈 상태 확인 및 자동 오픈 설정"
run_as_oracle "export ORACLE_HOME=${ORACLE_HOME}; export ORACLE_SID=${ORACLE_SID}; export PATH=\$ORACLE_HOME/bin:\$PATH; sqlplus -S / as sysdba <<EOF
WHENEVER SQLERROR CONTINUE
ALTER PLUGGABLE DATABASE ${ORACLE_PDB} OPEN;
ALTER PLUGGABLE DATABASE ${ORACLE_PDB} SAVE STATE;
SELECT con_name, state FROM cdb_pdb_saved_states;
EXIT
EOF" 2>&1 | tee -a "${LOG_FILE}" || log_warn "PDB SAVE STATE 처리 중 일부 경고 (ORA-65019 이면 정상)"

log_ok "STEP 08 완료"
