#!/bin/bash
# =============================================================================
#  02-packages.sh  :  Rocky 8.10 필수 패키지 설치
#
#  전략 (우선순위 순):
#   1) 인터넷 접근 가능 시 : Oracle Linux 8 저장소의 preinstall 사용 (최선)
#   2) 로컬 el7 RPM 을 --nodeps 로 강제 설치 시도 (Rocky 8 에서 대부분 작동)
#   3) 그래도 실패 시 : dnf 로 Rocky 8 기본 저장소에서 필수 패키지 직접 설치
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.env"
source "${SCRIPT_DIR}/lib/common.sh"

require_root
log_step "STEP 02 : 패키지 설치 (Rocky 8.10)"

# ----- Rocky 8 필수 저장소 활성화 -----
log_info "PowerTools 리포지토리 활성화 (compat-openssl10 등)"
if command_exists dnf; then
    dnf config-manager --set-enabled powertools 2>/dev/null || \
    dnf config-manager --set-enabled PowerTools 2>/dev/null || \
    dnf config-manager --set-enabled crb 2>/dev/null || true
fi

if ! rpm_installed epel-release; then
    log_info "EPEL 설치"
    dnf install -y epel-release || log_warn "EPEL 설치 실패 (무시)"
fi

# ----- Oracle Linux 8 저장소 등록 (인터넷 가능 시) -----
INTERNET_OK="false"
if curl -s --max-time 5 -o /dev/null -w "%{http_code}" https://yum.oracle.com/ | grep -q "^[23]"; then
    INTERNET_OK="true"
fi

PREINSTALL_SUCCESS="false"

if [[ "${USE_OL8_REPO_PREINSTALL}" == "true" && "${INTERNET_OK}" == "true" ]]; then
    if [[ ! -f /etc/yum.repos.d/oracle-ol8.repo ]]; then
        log_info "Oracle Linux 8 저장소 등록"
        rpm --import https://yum.oracle.com/RPM-GPG-KEY-oracle-ol8 2>/dev/null || true
        cat > /etc/yum.repos.d/oracle-ol8.repo <<'EOF'
[ol8_baseos_latest]
name=Oracle Linux 8 BaseOS Latest
baseurl=https://yum.oracle.com/repo/OracleLinux/OL8/baseos/latest/x86_64/
gpgkey=https://yum.oracle.com/RPM-GPG-KEY-oracle-ol8
gpgcheck=1
enabled=1

[ol8_appstream]
name=Oracle Linux 8 AppStream
baseurl=https://yum.oracle.com/repo/OracleLinux/OL8/appstream/x86_64/
gpgkey=https://yum.oracle.com/RPM-GPG-KEY-oracle-ol8
gpgcheck=1
enabled=1
EOF
    fi

    dnf clean all
    dnf makecache -y || log_warn "makecache 부분 실패"

    log_info "① OL8 저장소의 oracle-database-preinstall-19c 설치 시도"
    if dnf install -y oracle-database-preinstall-19c --nogpgcheck &>>"${LOG_FILE}"; then
        log_ok "OL8 preinstall 설치 완료 (커널 파라미터/사용자 자동 구성됨)"
        PREINSTALL_SUCCESS="true"
    else
        log_warn "OL8 preinstall 설치 실패 → 로컬 RPM 시도"
    fi
fi

# ----- 로컬 el7 preinstall RPM 강제 설치 (Rocky 8 에서 대부분 성공) -----
if [[ "${PREINSTALL_SUCCESS}" == "false" && "${USE_LOCAL_PREINSTALL_RPM}" == "true" ]]; then
    if [[ -f "${PREINSTALL_RPM}" ]]; then
        log_info "② 로컬 el7 preinstall RPM 강제 설치 시도 (--nodeps)"

        # 먼저 el7 RPM 이 요구하는 주요 종속 패키지를 Rocky 8 에서 미리 설치
        PRE_DEPS=(
            bc binutils elfutils-libelf glibc glibc-devel ksh
            libaio libaio-devel libX11 libXau libXi libXtst
            libgcc libnsl librdmacm libstdc++ libstdc++-devel
            libxcb libxml2 make net-tools nfs-utils
            policycoreutils policycoreutils-python-utils
            smartmontools sysstat unzip xorg-x11-utils
            xorg-x11-xauth compat-openssl10
        )
        for pkg in "${PRE_DEPS[@]}"; do
            rpm_installed "${pkg}" || dnf install -y "${pkg}" &>>"${LOG_FILE}" || true
        done

        # 강제 설치
        if rpm -Uvh --nodeps --force "${PREINSTALL_RPM}" 2>&1 | tee -a "${LOG_FILE}"; then
            log_ok "el7 preinstall RPM 강제 설치 완료"
            PREINSTALL_SUCCESS="true"

            # el7 RPM 이 만든 커널 파라미터 파일이 있는지 확인
            if [[ -f /etc/sysctl.d/99-oracle-database-preinstall-19c-sysctl.conf ]]; then
                sysctl -p /etc/sysctl.d/99-oracle-database-preinstall-19c-sysctl.conf &>>"${LOG_FILE}" || true
                log_ok "el7 preinstall 커널 파라미터 적용됨"
            fi
        else
            log_warn "el7 preinstall RPM 설치 실패"
        fi
    else
        log_warn "로컬 preinstall RPM 파일 없음: ${PREINSTALL_RPM}"
    fi
fi

# ----- 최후 수단: Rocky 8 기본 저장소로 필수 패키지 수동 설치 -----
log_info "③ 필수 패키지 최종 검증 및 보완 설치"

REQUIRED_PKGS=(
    # 빌드/링킹
    bc binutils gcc gcc-c++ make
    # C 라이브러리
    glibc glibc-devel glibc-headers
    libgcc libstdc++ libstdc++-devel
    # AIO / RDMA
    libaio libaio-devel librdmacm libibverbs
    # X11
    libX11 libXau libXi libXtst libXrender libXrender-devel libxcb
    xorg-x11-utils xorg-x11-xauth
    fontconfig-devel
    # 네트워크 (RHEL 8 에서는 libnsl 만 있으면 됨)
    libnsl
    # 보안/암호화 (Rocky 8 은 compat-openssl10 사용)
    compat-openssl10
    # ELF
    elfutils-libelf elfutils-libelf-devel
    # 셸 / 시스템 도구
    ksh net-tools sysstat smartmontools
    policycoreutils policycoreutils-python-utils
    # 유틸리티
    unzip tar which wget curl
    # GUI 설치 시 (선택)
    tigervnc-server
)

FAILED_PKGS=()
for pkg in "${REQUIRED_PKGS[@]}"; do
    if rpm_installed "${pkg}"; then
        continue
    fi
    if ! dnf install -y "${pkg}" &>>"${LOG_FILE}"; then
        FAILED_PKGS+=("${pkg}")
    fi
done

if [[ ${#FAILED_PKGS[@]} -gt 0 ]]; then
    log_warn "다음 패키지 설치 실패: ${FAILED_PKGS[*]}"
fi

# ----- 핵심 패키지 검증 -----
log_info "핵심 패키지 검증"
CRITICAL=(compat-openssl10 libaio libnsl ksh binutils gcc glibc-devel libstdc++-devel)
MISSING_CRITICAL=()
for pkg in "${CRITICAL[@]}"; do
    if rpm_installed "${pkg}"; then
        log_ok "  ✓ ${pkg} ($(rpm -q --qf '%{VERSION}-%{RELEASE}' "${pkg}"))"
    else
        MISSING_CRITICAL+=("${pkg}")
        log_error "  ✗ ${pkg} (누락)"
    fi
done

if [[ ${#MISSING_CRITICAL[@]} -gt 0 ]]; then
    log_error "핵심 패키지가 누락되었습니다: ${MISSING_CRITICAL[*]}"
    log_error "해결: dnf install -y ${MISSING_CRITICAL[*]} --enablerepo=powertools"
    die "핵심 패키지 부족으로 설치를 중단합니다."
fi

# ----- preinstall 로 만들어진 oracle 사용자 존재 여부 알림 -----
if id oracle &>/dev/null; then
    log_ok "oracle 사용자 존재 (preinstall 로 생성됨)"
    log_info "  UID=$(id -u oracle), primary group=$(id -gn oracle)"
    log_info "04-users.sh 에서 그룹 멤버십을 보완합니다."
fi

log_ok "STEP 02 완료"
