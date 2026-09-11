# Oracle 19c 테스트 설치 도구

Rocky Linux 8 테스트 VM에 Oracle Database 19c **단일 인스턴스**를 설치하는 스크립트와 안전한 가상 테스트 데이터를 제공합니다.

> 이 저장소의 설치 스크립트는 Oracle RAC 또는 RAC One Node 설치용이 아닙니다. RAC 실습에는 Oracle Grid Infrastructure와 공유 스토리지 구성이 별도로 필요합니다.

## 준비 사항

Oracle 라이선스 조건 때문에 데이터베이스 설치 ZIP과 RU/OPatch 파일은 이 저장소에 포함하지 않습니다. Oracle 공식 사이트에서 `LINUX.X64_193000_db_home.zip`을 내려받아 대상 VM의 `/tmp/oracle_install/`에 배치하세요.

Rocky Linux는 Oracle Database 인증 운영체제가 아닙니다. 이 구성은 개발·학습용이며 운영 또는 Oracle Support가 필요한 환경에는 Oracle Linux와 현재 인증된 19c RU를 사용하세요.

## CLI 설치

```bash
git clone https://github.com/dykim-tech/oracle.git
cd oracle/oracle19c-rocky8

sudo mkdir -p /tmp/oracle_install
sudo cp /path/to/LINUX.X64_193000_db_home.zip /tmp/oracle_install/

vi config.env
sudo bash ./install.sh --dry-run
sudo bash ./install.sh
```

비밀번호는 GitHub에 저장되지 않으며 DBCA 단계에서 화면에 표시하지 않고 입력받습니다. 자동화가 필요하면 실행 환경에서 `SYS_PASSWORD`, `SYSTEM_PASSWORD`, `PDB_ADMIN_PASSWORD`를 설정하고 `sudo -E bash ./install.sh`를 사용하세요. 셸 히스토리에 비밀번호를 직접 입력하지 않는 것을 권장합니다.

세부 옵션은 [`oracle19c-rocky8/README.md`](oracle19c-rocky8/README.md)를 참고하세요.

## 테스트 데이터

설치 완료 후 다음을 실행합니다.

```bash
cd ../oracle-testdb
chmod +x run_all.sh
bash ./run_all.sh
```

테스트 데이터의 이메일은 RFC 예약 도메인인 `example.com`, `example.net`, `example.org`만 사용하며, 전화번호·주소·식별번호도 명백한 예시값으로 생성됩니다.

## 저장소에 포함하지 않는 항목

- Oracle Database 설치 ZIP
- Oracle RU 및 OPatch ZIP
- Oracle 제공 RPM
- 비밀번호, 토큰, 개인키
- 실제 개인정보
