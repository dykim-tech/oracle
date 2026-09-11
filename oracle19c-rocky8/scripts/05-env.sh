#!/bin/bash
# =============================================================================
#  05-env.sh  :  oracle 사용자 환경변수(.bash_profile) 구성
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.env"
source "${SCRIPT_DIR}/lib/common.sh"

require_root
log_step "STEP 05 : oracle 환경변수 설정"

ORA_HOME_DIR="$(oracle_home_dir)"
PROFILE="${ORA_HOME_DIR}/.bash_profile"
BACKUP="${PROFILE}.bak.$(date +%Y%m%d%H%M%S)"

if [[ -f "${PROFILE}" ]]; then
    cp -a "${PROFILE}" "${BACKUP}"
    log_info "기존 .bash_profile 백업: ${BACKUP}"
fi

# 기존 Oracle 블록 제거
if grep -q "# ===== Oracle Database 19c =====" "${PROFILE}" 2>/dev/null; then
    sed -i '/# ===== Oracle Database 19c =====/,/# ===== END Oracle Database 19c =====/d' "${PROFILE}"
    log_info "기존 Oracle 환경변수 블록 제거"
fi

cat >> "${PROFILE}" <<EOF

# ===== Oracle Database 19c =====
export ORACLE_BASE=${ORACLE_BASE}
export ORACLE_HOME=${ORACLE_HOME}
export ORACLE_SID=${ORACLE_SID}
export ORACLE_HOSTNAME=\$(hostname)
export PATH=\$ORACLE_HOME/bin:\$ORACLE_HOME/OPatch:\$PATH
export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:/lib:/usr/lib
export CLASSPATH=\$ORACLE_HOME/JRE:\$ORACLE_HOME/jlib:\$ORACLE_HOME/rdbms/jlib
export NLS_LANG=AMERICAN_AMERICA.${DB_CHARSET}
export TMP=/tmp
export TMPDIR=/tmp
export TNS_ADMIN=\$ORACLE_HOME/network/admin
umask 022
# 편의 alias
alias sqlp='sqlplus / as sysdba'
alias oh='cd \$ORACLE_HOME'
alias tns='cd \$TNS_ADMIN'
alias alertlog='tail -f \$ORACLE_BASE/diag/rdbms/\${ORACLE_SID,,}/\$ORACLE_SID/trace/alert_\$ORACLE_SID.log'
# ===== END Oracle Database 19c =====
EOF

chown "${ORACLE_USER}:oinstall" "${PROFILE}"
chmod 644 "${PROFILE}"

log_ok "환경변수 파일 갱신: ${PROFILE}"
log_info "테스트 실행:"
run_as_oracle "env | grep -E 'ORACLE|NLS_LANG|TNS_ADMIN' | sort" | while read -r line; do
    log_info "  ${line}"
done

log_ok "STEP 05 완료"
