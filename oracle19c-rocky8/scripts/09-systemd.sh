#!/bin/bash
# =============================================================================
#  09-systemd.sh  :  자동 시작 서비스 등록
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.env"
source "${SCRIPT_DIR}/lib/common.sh"

require_root
log_step "STEP 09 : 자동 시작 서비스 등록"

# ----- /etc/oratab 갱신 -----
log_info "/etc/oratab 자동 시작 플래그 설정"
if [[ -f /etc/oratab ]]; then
    if grep -q "^${ORACLE_SID}:" /etc/oratab; then
        sed -i "s|^${ORACLE_SID}:.*|${ORACLE_SID}:${ORACLE_HOME}:Y|" /etc/oratab
    else
        echo "${ORACLE_SID}:${ORACLE_HOME}:Y" >> /etc/oratab
    fi
    log_ok "$(grep "^${ORACLE_SID}:" /etc/oratab)"
else
    log_warn "/etc/oratab 파일이 없습니다. root.sh 가 정상 실행되었는지 확인하세요."
fi

# ----- systemd 유닛 파일 -----
SVC_FILE="/etc/systemd/system/oracle-db.service"
log_info "systemd 유닛 파일 작성: ${SVC_FILE}"

cat > "${SVC_FILE}" <<EOF
[Unit]
Description=Oracle Database 19c (${ORACLE_SID})
Documentation=man:dbstart(1)
After=network.target network-online.target remote-fs.target
Wants=network-online.target

[Service]
Type=forking
RemainAfterExit=yes
User=${ORACLE_USER}
Group=oinstall
Environment=ORACLE_HOME=${ORACLE_HOME}
Environment=ORACLE_SID=${ORACLE_SID}
ExecStart=${ORACLE_HOME}/bin/dbstart ${ORACLE_HOME}
ExecStop=${ORACLE_HOME}/bin/dbshut ${ORACLE_HOME}
TimeoutStartSec=600
TimeoutStopSec=300
Restart=no
LimitNOFILE=65536
LimitNPROC=16384
LimitSTACK=32768
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF

chmod 644 "${SVC_FILE}"
systemctl daemon-reload
systemctl enable oracle-db.service &>>"${LOG_FILE}"
log_ok "oracle-db.service 등록 및 부팅 시 자동 시작 활성화"

# ----- 상태 확인 -----
sleep 2
systemctl status oracle-db.service --no-pager -l 2>&1 | tee -a "${LOG_FILE}" || true

log_info "재부팅 후 자동 시작 검증 방법:"
log_info "  1) sudo reboot"
log_info "  2) 부팅 후: systemctl status oracle-db"
log_info "  3) sqlplus / as sysdba 로 접속 확인"

log_ok "STEP 09 완료"
