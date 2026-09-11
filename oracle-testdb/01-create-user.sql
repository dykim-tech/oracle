-- =============================================================================
--  01-create-user.sql
--  테스트용 사용자(스키마) 생성 : ORCLPDB1 에서 실행
--  실행 : sqlplus / as sysdba @01-create-user.sql
-- =============================================================================

WHENEVER SQLERROR CONTINUE
DEFINE TESTUSER_PASSWORD = '&1'

-- CDB$ROOT 에서 시작
ALTER SESSION SET CONTAINER = CDB$ROOT;

-- PDB 가 열려있지 않으면 오픈
ALTER PLUGGABLE DATABASE ORCLPDB1 OPEN;

-- ORCLPDB1 로 컨테이너 이동
ALTER SESSION SET CONTAINER = ORCLPDB1;

-- 기존 사용자 삭제(있는 경우)
DROP USER testuser CASCADE;

-- 테스트 사용자 생성
CREATE USER testuser
  IDENTIFIED BY "&&TESTUSER_PASSWORD"
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON USERS;

-- 권한 부여
GRANT CONNECT, RESOURCE TO testuser;
GRANT CREATE VIEW, CREATE PROCEDURE, CREATE SEQUENCE TO testuser;
GRANT CREATE SYNONYM, CREATE TRIGGER TO testuser;
GRANT UNLIMITED TABLESPACE TO testuser;

-- 확인
SELECT username, account_status, default_tablespace
FROM   dba_users
WHERE  username = 'TESTUSER';

PROMPT
PROMPT ===========================================================
PROMPT  testuser 생성 완료
PROMPT  접속 예시:
PROMPT    sqlplus testuser@localhost:1521/ORCLPDB1
PROMPT ===========================================================

EXIT
