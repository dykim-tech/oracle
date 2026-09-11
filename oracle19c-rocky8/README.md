# Oracle Database 19c on Rocky Linux 8.10 - 자동 설치 스크립트

Rocky Linux **8.10** 환경에서 **가지고 계신 두 파일만으로** Oracle 19c 를 설치·구성하는 스크립트 모음입니다.

## ✅ 필요한 파일 (두 개만)

```
/tmp/oracle_install/
├── LINUX.X64_193000_db_home.zip                          (필수, 약 3 GB)
└── oracle-database-preinstall-19c-1.0-1.el7.x86_64.rpm   (선택, 있으면 활용)
```

두 파일 모두 이미 가지고 계십니다. **RU 패치는 필요 없습니다.**

## Rocky 8.10 이 Rocky 9.4 대비 유리한 이유

| 항목 | Rocky 8.10 (RHEL 8) | Rocky 9.4 (RHEL 9) |
|---|---|---|
| glibc | 2.28 | 2.34 |
| OpenSSL | 1.1.1 기본 (compat-openssl10 도 있음) | 3.0 기본 |
| Oracle 19c 인증 | **19.7+ 공식** | 19.19+ RU 필수 |
| **base 19.3 만으로 설치** | **가능** | 링킹 실패 확률 높음 |
| el7 preinstall RPM | 강제 설치 시 대부분 작동 | 대부분 실패 |

Rocky 8.10 은 RHEL 8 계열이므로 Oracle 19c 가 공식 인증되는 환경입니다. base 19.3 만으로도 정상 설치되며, RU 는 프로덕션에서만 필요합니다.

## 설치 전략 (자동 폴백)

`02-packages.sh` 는 다음 순서로 시도합니다.

**1) Oracle Linux 8 저장소 preinstall 우선** (인터넷 가능 시)
`yum.oracle.com` 에서 `oracle-database-preinstall-19c` (el8 버전) 을 자동 다운로드. 가장 안정적.

**2) 가지고 계신 el7 preinstall RPM 강제 설치**
인터넷이 안 되거나 1) 실패 시, 필수 종속 패키지를 먼저 Rocky 8 저장소에서 설치한 후 `rpm -Uvh --nodeps --force` 로 el7 RPM 강제 설치. Rocky 8 은 RHEL 7 과 라이브러리 체계가 상당히 유사해서 이 방법이 대부분 작동합니다.

**3) Rocky 8 기본 저장소 수동 설치**
위 두 방법이 모두 실패해도 스크립트가 필요한 개별 패키지를 Rocky 8 기본 저장소에서 하나씩 설치.

## 디렉터리 구조

```
oracle19c-rocky8/
├── install.sh              # 통합 실행 스크립트
├── uninstall.sh            # 롤백/제거 스크립트
├── config.env              # 환경 설정 (반드시 수정)
├── lib/
│   └── common.sh
└── scripts/
    ├── 01-precheck.sh      # Rocky 8/9 자동 감지, 파일 확인
    ├── 02-packages.sh      # OL8 repo → el7 RPM → 수동 설치 (자동 폴백)
    ├── 03-sysconfig.sh     # 커널/limits/SELinux/방화벽
    ├── 04-users.sh         # oracle 사용자/그룹/디렉터리 (preinstall 이미 만든 경우 skip)
    ├── 05-env.sh           # .bash_profile 환경변수
    ├── 06-install-db.sh    # 19c 설치 (CV_ASSUME_DISTID=OEL8)
    ├── 07-listener.sh      # 리스너 생성
    ├── 08-dbca.sh          # DB 생성 (CDB+PDB)
    ├── 09-systemd.sh       # 자동 시작 서비스
    └── 99-verify.sh        # 최종 검증
```

## 사용 순서

**1) 파일 배치** — `/tmp/oracle_install/` 에 두 파일 업로드
```bash
sudo mkdir -p /tmp/oracle_install
sudo chmod 777 /tmp/oracle_install
# SCP/WinSCP 로 두 파일 업로드
ls -lh /tmp/oracle_install/
```

**2) 스크립트 배포**
```bash
tar -xzf oracle19c-rocky8.tar.gz
cd oracle19c-rocky8
chmod +x install.sh uninstall.sh scripts/*.sh
```

**3) 설정 확인** — 비밀번호는 파일에 저장하지 않음
```bash
vi config.env
# 수정 권장 항목:
#   DB_TOTAL_MEMORY_MB (서버 RAM 의 40~60%)
#   ORACLE_SID, ORACLE_PDB (원하는 이름으로)
```

**4) 실행**
```bash
sudo ./install.sh
```

## 부분 실행 옵션

```bash
sudo ./install.sh --list              # 실행 가능한 단계 목록
sudo ./install.sh --dry-run           # 실제 실행 없이 순서만 확인
sudo ./install.sh --step 03           # 특정 단계만 실행
sudo ./install.sh --from 06           # 특정 단계부터 끝까지
sudo ./install.sh --yes               # 확인 프롬프트 자동 승인
```

## config.env 주요 옵션

| 옵션 | 기본값 | 설명 |
|---|---|---|
| `TARGET_OS` | `rocky8` | `rocky8` 또는 `rocky9` |
| `APPLY_RU` | `false` | Rocky 8 에서는 false 로 두어도 정상 설치됨 |
| `USE_LOCAL_PREINSTALL_RPM` | `true` | 가지고 있는 el7 RPM 사용 여부 |
| `USE_OL8_REPO_PREINSTALL` | `true` | 인터넷 가능 시 OL8 저장소 우선 사용 |
| `CV_ASSUME_DISTID_VAL` | `OEL8` | runInstaller 에게 인증 OS 로 위장 |
| `IGNORE_PREREQ` | `true` | 사전검증 실패 무시 (Rocky 미인증) |
| `DB_TOTAL_MEMORY_MB` | `2048` | 서버 RAM 에 맞춰 조정 |

## 로그

`/var/log/oracle-install/install-YYYYMMDD-HHMMSS.log`

## 롤백

```bash
sudo ./uninstall.sh
```

## 주의사항

- Rocky Linux 는 Oracle 공식 인증 OS 가 아닙니다. 프로덕션 SR 지원이 필요하면 Oracle Linux 8 사용을 권장합니다.
- DB 비밀번호는 DBCA 단계에서 화면에 표시되지 않게 입력받습니다.
- 두 파일만으로도 정상 설치되지만, 프로덕션 환경이라면 향후 19.22+ RU 적용을 계획하세요.

## 인터넷 접근이 불가한 폐쇄망 환경

`02-packages.sh` 는 다음 순서로 동작합니다.
1. `yum.oracle.com` 접근 확인 → 실패 시 로컬 RPM 강제 설치로 자동 전환
2. 로컬 RPM 강제 설치 → 실패 시 Rocky 8 사내 미러 저장소에서 개별 설치

폐쇄망이라면 사전에 사내 미러(Rocky 8 base/appstream/powertools) 가 활성화되어 있는지 확인하세요. `compat-openssl10` 은 반드시 필요합니다.
