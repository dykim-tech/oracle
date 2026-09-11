#!/bin/bash
# =============================================================================
#  06-install-db.sh  :  Oracle 19c 소프트웨어 설치 (RU 동시 적용)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.env"
source "${SCRIPT_DIR}/lib/common.sh"

require_root
log_step "STEP 06 : Oracle 19c 소프트웨어 설치"

# ----- 설치 파일 존재 확인 -----
if [[ ! -f "${DB_ZIP_FILE}" ]]; then
    die "설치 파일 누락(필수): ${DB_ZIP_FILE}"
fi

if [[ "${APPLY_RU}" == "true" ]]; then
    for f in "${RU_ZIP_FILE}" "${OPATCH_ZIP_FILE}"; do
        if [[ ! -f "${f}" ]]; then
            die "RU 파일 누락: ${f}
APPLY_RU=true 인 경우 반드시 아래 두 파일이 필요합니다:
  - p35643107_190000_Linux-x86-64.zip (19.22 RU)
  - p6880880_190000_Linux-x86-64.zip  (OPatch 최신)
파일이 없으시면 config.env 에서 APPLY_RU=false 로 변경하세요.
(Rocky 8.x 는 base 19.3 만으로도 정상 설치 가능. Rocky 9.x 는 RU 필수)"
        fi
    done
else
    log_warn "APPLY_RU=false — RU 없이 base 19.3 만 설치합니다."
    if [[ "${TARGET_OS:-}" == "rocky9" ]]; then
        log_warn "Rocky 9.x 에서는 root.sh / genclntsh / 링킹 단계에서 실패 가능성이 높습니다."
        log_warn "RU 패치 (19.19 이상) 다운로드 후 APPLY_RU=true 로 진행을 권장합니다."
    else
        log_info "Rocky 8.x 에서는 base 19.3 만으로도 정상 설치됩니다."
    fi
    if ! confirm "계속 진행하시겠습니까?"; then
        die "사용자 취소"
    fi
fi

# ----- 이미 설치되어 있는지 확인 -----
if [[ -f "${ORACLE_HOME}/bin/sqlplus" ]]; then
    log_warn "이미 ${ORACLE_HOME} 에 Oracle 이 설치된 것으로 보입니다."
    if ! confirm "덮어쓰지 않고 건너뛰시겠습니까?"; then
        die "사용자 취소"
    fi
    log_info "설치 단계 건너뜀"
    exit 0
fi

# ----- INS-32012 방지: /u01 /u02 /u03 재귀 소유권 재확인 -----
log_info "설치 전 디렉터리 소유권 최종 확인 (INS-32012 방지)"
for top in /u01 /u02 /u03; do
    if [[ -d "${top}" ]]; then
        chown -R "${ORACLE_USER}:oinstall" "${top}"
        chmod -R 775 "${top}"
    fi
done
log_ok "소유권 확인 완료: /u01 /u02 /u03 → ${ORACLE_USER}:oinstall"

# ----- .bash_profile 의 ORACLE_SID 를 config 최신값과 동기화 -----
# (사용자가 --from 06 등으로 05 를 건너뛴 경우에도 SID mismatch 방지)
ORA_HOME_DIR="$(oracle_home_dir)"
if [[ -f "${ORA_HOME_DIR}/.bash_profile" ]]; then
    if grep -q "^export ORACLE_SID=" "${ORA_HOME_DIR}/.bash_profile"; then
        sed -i "s|^export ORACLE_SID=.*|export ORACLE_SID=${ORACLE_SID}|" "${ORA_HOME_DIR}/.bash_profile"
        log_info ".bash_profile 의 ORACLE_SID 를 ${ORACLE_SID} 로 동기화"
    fi
fi

# ----- ORACLE_HOME 에 base zip 압축 해제 (image-based install) -----
log_info "Oracle 19c base 압축 해제 → ${ORACLE_HOME}"
chown -R "${ORACLE_USER}:oinstall" "${ORACLE_HOME}"
run_as_oracle "cd ${ORACLE_HOME} && unzip -q ${DB_ZIP_FILE}"
log_ok "base 압축 해제 완료"

RU_PATCH_DIR=""
if [[ "${APPLY_RU}" == "true" ]]; then
    # ----- RU 패치 압축 해제 -----
    RU_DIR="${INSTALL_STAGE}/RU"
    mkdir -p "${RU_DIR}"
    chown "${ORACLE_USER}:oinstall" "${RU_DIR}"
    log_info "RU 패치 압축 해제 → ${RU_DIR}"
    run_as_oracle "cd ${RU_DIR} && unzip -qo ${RU_ZIP_FILE}"

    RU_PATCH_DIR="${RU_DIR}/${RU_PATCH_NUMBER}"
    if [[ ! -d "${RU_PATCH_DIR}" ]]; then
        RU_PATCH_DIR="$(find "${RU_DIR}" -maxdepth 1 -mindepth 1 -type d | head -1)"
        log_warn "설정된 RU_PATCH_NUMBER 와 실제 디렉터리 불일치 → ${RU_PATCH_DIR} 사용"
    fi
    log_ok "RU 디렉터리: ${RU_PATCH_DIR}"

    # ----- OPatch 최신화 -----
    log_info "OPatch 최신 버전으로 교체"
    run_as_oracle "cd ${ORACLE_HOME} && mv OPatch OPatch.orig.$(date +%s) 2>/dev/null || true"
    run_as_oracle "cd ${ORACLE_HOME} && unzip -qo ${OPATCH_ZIP_FILE}"
    OPATCH_VER=$(run_as_oracle "${ORACLE_HOME}/OPatch/opatch version" | grep 'OPatch Version' || true)
    log_ok "OPatch 버전: ${OPATCH_VER}"
else
    log_info "APPLY_RU=false — RU/OPatch 교체 단계 생략"
fi

# ----- Response 파일 생성 -----
RSP_FILE="/tmp/db_install_$(date +%s).rsp"
log_info "Response 파일 생성: ${RSP_FILE}"

cat > "${RSP_FILE}" <<EOF
oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v19.0.0
oracle.install.option=INSTALL_DB_SWONLY
UNIX_GROUP_NAME=oinstall
INVENTORY_LOCATION=${ORA_INVENTORY}
ORACLE_HOME=${ORACLE_HOME}
ORACLE_BASE=${ORACLE_BASE}
oracle.install.db.InstallEdition=EE
oracle.install.db.OSDBA_GROUP=dba
oracle.install.db.OSOPER_GROUP=oper
oracle.install.db.OSBACKUPDBA_GROUP=backupdba
oracle.install.db.OSDGDBA_GROUP=dgdba
oracle.install.db.OSKMDBA_GROUP=kmdba
oracle.install.db.OSRACDBA_GROUP=racdba
oracle.install.db.rootconfig.executeRootScript=false
EOF

chown "${ORACLE_USER}:oinstall" "${RSP_FILE}"

# ----- Silent 설치 실행 -----
EXTRA_OPTS=""
if [[ "${IGNORE_PREREQ}" == "true" ]]; then
    EXTRA_OPTS="-ignorePrereqFailure"
fi
# CV_ASSUME_DISTID : Rocky 를 인증 OS 로 위장하기 위한 환경변수
if [[ -n "${CV_ASSUME_DISTID_VAL:-}" ]]; then
    ASSUME="export CV_ASSUME_DISTID=${CV_ASSUME_DISTID_VAL};"
    log_info "CV_ASSUME_DISTID=${CV_ASSUME_DISTID_VAL} 설정"
else
    ASSUME=""
fi

if [[ "${APPLY_RU}" == "true" && -n "${RU_PATCH_DIR}" ]]; then
    APPLY_RU_OPT="-applyRU ${RU_PATCH_DIR}"
    log_info "runInstaller 실행 (RU 동시 적용: ${RU_PATCH_DIR})"
else
    APPLY_RU_OPT=""
    log_info "runInstaller 실행 (RU 미적용)"
fi
log_info "이 과정은 15~30분 소요될 수 있습니다..."

set +e
run_as_oracle "${ASSUME} cd ${ORACLE_HOME} && ./runInstaller -silent \
    ${APPLY_RU_OPT} \
    -responseFile ${RSP_FILE} \
    ${EXTRA_OPTS} \
    -waitforcompletion" 2>&1 | tee -a "${LOG_FILE}"
INSTALL_RC=${PIPESTATUS[0]}
set -e

# runInstaller 는 root.sh 필요 시에도 exit code 6 등을 반환할 수 있음
case ${INSTALL_RC} in
    0)  log_ok "runInstaller 정상 종료" ;;
    6)  log_info "runInstaller 종료코드 6 (root.sh 실행 필요) — 정상" ;;
    *)  log_warn "runInstaller 종료코드: ${INSTALL_RC} — 로그 확인 필요" ;;
esac

# ----- root 스크립트 실행 -----
log_info "root 스크립트 실행"
if [[ -f "${ORA_INVENTORY}/orainstRoot.sh" ]]; then
    "${ORA_INVENTORY}/orainstRoot.sh" 2>&1 | tee -a "${LOG_FILE}"
    log_ok "orainstRoot.sh 완료"
fi

if [[ -f "${ORACLE_HOME}/root.sh" ]]; then
    "${ORACLE_HOME}/root.sh" 2>&1 | tee -a "${LOG_FILE}"
    log_ok "root.sh 완료"
fi

# ----- 설치 검증 -----
log_info "설치 검증"
if [[ ! -f "${ORACLE_HOME}/bin/sqlplus" ]]; then
    die "sqlplus 바이너리가 생성되지 않았습니다. 설치 실패로 판단."
fi

SQLPLUS_VER=$(run_as_oracle "export ORACLE_HOME=${ORACLE_HOME}; ${ORACLE_HOME}/bin/sqlplus -V" 2>&1 | grep -i release || true)
log_ok "SQL*Plus: ${SQLPLUS_VER}"

PATCH_INFO=$(run_as_oracle "export ORACLE_HOME=${ORACLE_HOME}; ${ORACLE_HOME}/OPatch/opatch lspatches" 2>/dev/null || echo "n/a")
log_ok "적용된 패치:"
echo "${PATCH_INFO}" | while read -r line; do log_info "  ${line}"; done

log_ok "STEP 06 완료"
