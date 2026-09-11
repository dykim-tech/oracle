#!/bin/bash
# =============================================================================
#  03-sysconfig.sh  :  커널 파라미터, 리소스 제한, SELinux, 방화벽, 시간동기화
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.env"
source "${SCRIPT_DIR}/lib/common.sh"

require_root
log_step "STEP 03 : 시스템 파라미터 설정"

# ----- 커널 파라미터 -----
SYSCTL_FILE="/etc/sysctl.d/98-oracle-database.conf"
log_info "커널 파라미터 설정: ${SYSCTL_FILE}"

# 물리 메모리 기반 shmmax 계산 (RAM 의 50%)
MEM_BYTES=$(($(grep MemTotal /proc/meminfo | awk '{print $2}') * 1024))
SHMMAX=$((MEM_BYTES / 2))
SHMALL=$((SHMMAX / 4096))

cat > "${SYSCTL_FILE}" <<EOF
# Oracle Database 19c 권장 커널 파라미터
fs.aio-max-nr = 1048576
fs.file-max = 6815744
kernel.shmall = ${SHMALL}
kernel.shmmax = ${SHMMAX}
kernel.shmmni = 4096
kernel.sem = 250 32000 100 128
kernel.panic_on_oops = 1
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2
net.ipv4.ip_local_port_range = 9000 65500
vm.swappiness = 10
vm.dirty_background_ratio = 3
vm.dirty_ratio = 15
EOF

sysctl -p "${SYSCTL_FILE}" &>>"${LOG_FILE}"
sysctl --system &>>"${LOG_FILE}"
log_ok "커널 파라미터 적용 완료"

# ----- 리소스 제한 (limits) -----
LIMITS_FILE="/etc/security/limits.d/99-oracle.conf"
log_info "리소스 제한 설정: ${LIMITS_FILE}"

cat > "${LIMITS_FILE}" <<EOF
# Oracle Database 19c 리소스 제한
${ORACLE_USER}   soft   nofile    1024
${ORACLE_USER}   hard   nofile    65536
${ORACLE_USER}   soft   nproc     16384
${ORACLE_USER}   hard   nproc     16384
${ORACLE_USER}   soft   stack     10240
${ORACLE_USER}   hard   stack     32768
${ORACLE_USER}   soft   memlock   134217728
${ORACLE_USER}   hard   memlock   134217728
${ORACLE_USER}   soft   data      unlimited
${ORACLE_USER}   hard   data      unlimited
EOF
log_ok "리소스 제한 설정 완료"

# PAM 설정 (limits 활성화 확인)
if ! grep -q "pam_limits.so" /etc/pam.d/login; then
    echo "session    required     pam_limits.so" >> /etc/pam.d/login
fi

# ----- SELinux -----
if [[ "${CONFIGURE_SELINUX_PERMISSIVE}" == "true" ]]; then
    log_info "SELinux 를 permissive 로 변경"
    if [[ -f /etc/selinux/config ]]; then
        sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
        setenforce 0 2>/dev/null || true
        log_ok "SELinux 상태: $(getenforce)"
    fi
else
    log_info "SELinux 변경 건너뜀 (CONFIGURE_SELINUX_PERMISSIVE=false)"
fi

# ----- 방화벽 -----
if [[ "${CONFIGURE_FIREWALL}" == "true" ]]; then
    if systemctl is-active --quiet firewalld; then
        log_info "방화벽 포트 오픈: ${DB_PORT}, ${EM_PORT}"
        firewall-cmd --permanent --add-port=${DB_PORT}/tcp &>>"${LOG_FILE}"
        firewall-cmd --permanent --add-port=${EM_PORT}/tcp &>>"${LOG_FILE}"
        firewall-cmd --reload &>>"${LOG_FILE}"
        log_ok "방화벽 규칙 적용 완료"
    else
        log_info "firewalld 가 실행중이지 않음 → 방화벽 설정 건너뜀"
    fi
fi

# ----- Transparent HugePages 비활성화 (Oracle 권장) -----
log_info "Transparent HugePages 비활성화"
if [[ -f /sys/kernel/mm/transparent_hugepage/enabled ]]; then
    echo never > /sys/kernel/mm/transparent_hugepage/enabled || true
    echo never > /sys/kernel/mm/transparent_hugepage/defrag || true
fi

# GRUB 에 영구 반영
if ! grep -q "transparent_hugepage=never" /etc/default/grub 2>/dev/null; then
    log_info "GRUB 에 transparent_hugepage=never 추가"
    sed -i 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 transparent_hugepage=never"/' /etc/default/grub
    if [[ -d /boot/grub2 ]]; then
        grub2-mkconfig -o /boot/grub2/grub.cfg &>>"${LOG_FILE}" || true
    fi
    if [[ -d /boot/efi/EFI ]]; then
        find /boot/efi/EFI -name grub.cfg -exec grub2-mkconfig -o {} \; &>>"${LOG_FILE}" || true
    fi
fi

# ----- 시간 동기화 -----
log_info "시간 동기화 서비스 확인"
if systemctl is-enabled --quiet chronyd; then
    systemctl start chronyd &>>"${LOG_FILE}" || true
    log_ok "chronyd 실행 중: $(chronyc tracking 2>/dev/null | grep 'Reference ID' || echo 'N/A')"
else
    systemctl enable --now chronyd &>>"${LOG_FILE}" || log_warn "chronyd 활성화 실패"
fi

# ----- /etc/hosts 검증 -----
HN=$(hostname)
if ! grep -qE "^[0-9\.]+[[:space:]]+.*${HN}" /etc/hosts; then
    log_warn "/etc/hosts 에 ${HN} 항목이 없어 자동 추가합니다."
    IP=$(hostname -I | awk '{print $1}')
    if [[ -n "${IP}" ]]; then
        echo "${IP}   ${HN}.localdomain   ${HN}" >> /etc/hosts
        log_ok "추가: ${IP}   ${HN}.localdomain   ${HN}"
    fi
fi

log_ok "STEP 03 완료"
