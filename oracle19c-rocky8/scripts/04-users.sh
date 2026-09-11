#!/bin/bash
# =============================================================================
#  04-users.sh  :  Oracle 사용자, 그룹, 디렉터리 생성
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.env"
source "${SCRIPT_DIR}/lib/common.sh"

require_root
log_step "STEP 04 : 사용자/그룹/디렉터리 생성"

# ----- 그룹 생성 -----
create_group() {
    local gname="$1" gid="$2"
    if getent group "${gname}" &>/dev/null; then
        log_info "그룹 존재: ${gname} (skip)"
    else
        groupadd -g "${gid}" "${gname}"
        log_ok "그룹 생성: ${gname} (gid=${gid})"
    fi
}

create_group oinstall   "${OINSTALL_GID}"
create_group dba        "${DBA_GID}"
create_group oper       "${OPER_GID}"
create_group backupdba  "${BACKUPDBA_GID}"
create_group dgdba      "${DGDBA_GID}"
create_group kmdba      "${KMDBA_GID}"
create_group racdba     "${RACDBA_GID}"

# ----- oracle 사용자 -----
if getent passwd "${ORACLE_USER}" &>/dev/null; then
    log_info "사용자 존재: ${ORACLE_USER} (skip)"
    # 그룹 소속 갱신
    usermod -g oinstall -G dba,oper,backupdba,dgdba,kmdba,racdba "${ORACLE_USER}"
    log_ok "그룹 멤버십 갱신: ${ORACLE_USER}"
else
    useradd -u "${ORACLE_UID}" -g oinstall \
        -G dba,oper,backupdba,dgdba,kmdba,racdba \
        -m -d "/home/${ORACLE_USER}" -s /bin/bash "${ORACLE_USER}"
    log_ok "사용자 생성: ${ORACLE_USER} (uid=${ORACLE_UID})"
fi

# ----- oracle OS 계정 -----
if [[ -z "$(getent shadow "${ORACLE_USER}" | awk -F: '{print $2}' | tr -d '!*')" ]]; then
    passwd -l "${ORACLE_USER}" >/dev/null 2>&1 || true
    log_info "oracle OS 계정은 비밀번호 로그인을 사용하지 않도록 잠금 상태로 유지합니다."
fi

# ----- 디렉터리 -----
log_info "디렉터리 생성"
DIRS=(
    "${ORACLE_HOME}"
    "${ORA_INVENTORY}"
    "${ORADATA_DIR}"
    "${FRA_DIR}"
    "${INSTALL_STAGE}"
)

for d in "${DIRS[@]}"; do
    mkdir -p "${d}"
    chown -R "${ORACLE_USER}:oinstall" "${d}"
    chmod -R 775 "${d}"
    log_ok "  ${d}"
done

# /u01 /u02 /u03 전체 재귀 chown (INS-32012 방지)
# ORACLE_BASE 상위 모든 디렉터리가 oracle 소유여야 runInstaller 가
# ORACLE_BASE 안에 로그·인벤토리를 정상 생성함
for top in /u01 /u02 /u03; do
    if [[ -d "${top}" ]]; then
        chown -R "${ORACLE_USER}:oinstall" "${top}"
        chmod -R 775 "${top}"
        log_ok "  재귀 chown: ${top} (전체 하위 포함)"
    fi
done

log_ok "STEP 04 완료"
