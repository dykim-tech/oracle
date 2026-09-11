#!/bin/bash
# =============================================================================
#  uninstall.sh  :  Oracle 19c 제거 (설치 실패 후 롤백 용도)
#  ⚠  프로덕션 데이터가 있는 경우 사용 금지
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.env"
source "${SCRIPT_DIR}/lib/common.sh"

require_root
log_init

log_step "Oracle 19c 제거 (롤백)"
log_warn "이 스크립트는 ${ORACLE_BASE} 및 관련 파일을 모두 삭제합니다."
log_warn "  - ORACLE_BASE   : ${ORACLE_BASE}"
log_warn "  - ORA_INVENTORY : ${ORA_INVENTORY}"
log_warn "  - ORADATA_DIR   : ${ORADATA_DIR}"
log_warn "  - FRA_DIR       : ${FRA_DIR}"
log_warn "  - systemd 유닛  : /etc/systemd/system/oracle-db.service"

if ! confirm "정말로 계속하시겠습니까? (프로덕션 데이터 손실 위험)"; then
    die "사용자 취소"
fi

# systemd
if systemctl list-unit-files | grep -q oracle-db.service; then
    systemctl stop oracle-db.service 2>/dev/null || true
    systemctl disable oracle-db.service 2>/dev/null || true
    rm -f /etc/systemd/system/oracle-db.service
    systemctl daemon-reload
    log_ok "systemd 유닛 제거"
fi

# 실행 중 프로세스 종료
pkill -u "${ORACLE_USER}" -9 2>/dev/null || true

# 디렉터리 제거
for d in "${ORACLE_BASE}" "${ORA_INVENTORY}" "${ORADATA_DIR}" "${FRA_DIR}"; do
    if [[ -d "${d}" ]]; then
        rm -rf "${d}"
        log_ok "삭제: ${d}"
    fi
done

# 설정 파일 제거
rm -f /etc/oratab
rm -f /etc/sysctl.d/98-oracle-database.conf
rm -f /etc/security/limits.d/99-oracle.conf
rm -f /etc/yum.repos.d/oracle-ol9.repo
log_ok "설정 파일 제거"

# 사용자/그룹 (선택)
if confirm "oracle 사용자와 그룹도 제거하시겠습니까?"; then
    userdel -r "${ORACLE_USER}" 2>/dev/null || true
    for g in oinstall dba oper backupdba dgdba kmdba racdba; do
        groupdel "${g}" 2>/dev/null || true
    done
    log_ok "사용자/그룹 제거"
fi

log_ok "제거 완료 — 재설치 가능 상태"
