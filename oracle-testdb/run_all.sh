#!/bin/bash
# =============================================================================
#  run_all.sh  :  테스트 DB 생성 + 개인정보 테이블 + 가상 데이터 삽입 일괄 실행
#
#  사용법:
#    1) oracle 계정으로 전환      : sudo su - oracle
#    2) 이 디렉터리로 이동         : cd /path/to/oracle-testdb
#    3) 실행 권한 부여            : chmod +x run_all.sh
#    4) 실행                      : ./run_all.sh
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORACLE_PDB="${ORACLE_PDB:-ORCLPDB1}"
DB_PORT="${DB_PORT:-1521}"

if [[ -z "${TESTUSER_PASSWORD:-}" ]]; then
    [[ -t 0 ]] || { echo "ERROR: TESTUSER_PASSWORD 환경변수가 필요합니다."; exit 1; }
    read -r -s -p "testuser 비밀번호(8자 이상): " TESTUSER_PASSWORD
    echo
fi
[[ ${#TESTUSER_PASSWORD} -ge 8 ]] || { echo "ERROR: 비밀번호는 8자 이상이어야 합니다."; exit 1; }
[[ "${TESTUSER_PASSWORD}" =~ ^[A-Za-z0-9_#.-]+$ ]] || { echo "ERROR: 비밀번호에는 영문, 숫자, _, #, ., -만 사용할 수 있습니다."; exit 1; }

# 환경변수 확인
if [[ -z "${ORACLE_HOME:-}" ]]; then
    echo "ERROR: ORACLE_HOME 이 설정되어 있지 않습니다."
    echo "  → sudo su - oracle 로 oracle 계정에서 실행하세요."
    exit 1
fi

echo "======================================================================"
echo "  Oracle 19c 테스트 DB 셋업"
echo "  ORACLE_HOME: ${ORACLE_HOME}"
echo "  ORACLE_SID : ${ORACLE_SID:-ORCLCDB}"
echo "======================================================================"

# 1) 사용자 생성 (sysdba 로)
echo
echo "▶ 1/4 : testuser 사용자 생성 (SYSDBA)"
sqlplus -S / as sysdba @"${SCRIPT_DIR}/01-create-user.sql" "${TESTUSER_PASSWORD}"

# 2) 테이블 생성 (testuser 로)
echo
echo "▶ 2/4 : personal_info 테이블 생성 (testuser)"
sqlplus -S "testuser/\"${TESTUSER_PASSWORD}\"@localhost:${DB_PORT}/${ORACLE_PDB}" @"${SCRIPT_DIR}/02-create-table.sql"

# 3) 데이터 삽입
echo
echo "▶ 3/4 : 가상 개인정보 50건 삽입"
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3가 필요합니다."; exit 1; }
python3 "${SCRIPT_DIR}/gen_data.py" > "${SCRIPT_DIR}/03-insert-data.sql"
sqlplus -S "testuser/\"${TESTUSER_PASSWORD}\"@localhost:${DB_PORT}/${ORACLE_PDB}" @"${SCRIPT_DIR}/03-insert-data.sql"

# 4) 샘플 쿼리
echo
echo "▶ 4/4 : 샘플 쿼리 실행"
sqlplus -S "testuser/\"${TESTUSER_PASSWORD}\"@localhost:${DB_PORT}/${ORACLE_PDB}" @"${SCRIPT_DIR}/04-sample-queries.sql"

echo
echo "======================================================================"
echo "  완료 !"
echo "  접속 : sqlplus testuser@localhost:${DB_PORT}/${ORACLE_PDB}"
echo "  샘플 : SELECT * FROM personal_info WHERE ROWNUM<=5;"
echo "======================================================================"
