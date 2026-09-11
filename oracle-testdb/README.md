# Oracle 19c 테스트 DB - 개인정보 테이블 및 가상 데이터

Oracle 19c PDB(`ORCLPDB1`) 에 테스트용 스키마와 개인정보 테이블을 만들고 가상 데이터 50건을 삽입합니다.

## 파일 구성

| 파일 | 용도 |
|---|---|
| `01-create-user.sql` | `testuser` 스키마 생성 (SYSDBA 필요) |
| `02-create-table.sql` | `personal_info` 테이블 + 인덱스 + 시퀀스 생성 |
| `03-insert-data.sql` | 실행 시 안전한 예시 데이터로 자동 생성되는 INSERT 문 |
| `04-sample-queries.sql` | 10가지 샘플 조회 쿼리 |
| `gen_data.py` | 03-insert-data.sql 재생성용 Python 스크립트 (선택) |
| `run_all.sh` | 일괄 실행 스크립트 |

## 실행 방법

### 방법 1: 일괄 실행 (권장)

```bash
# oracle 계정으로 전환
sudo su - oracle

# 스크립트 폴더로 이동 후 실행
cd /path/to/oracle-testdb
chmod +x run_all.sh
bash ./run_all.sh
```

### 방법 2: 단계별 실행

```bash
sudo su - oracle

# 1) 사용자 생성
sqlplus / as sysdba @01-create-user.sql

# 2) 이후 단계는 비밀번호를 안전하게 입력받는 run_all.sh 사용 권장
bash ./run_all.sh

# 직접 실행할 때는 명령줄에 비밀번호를 남기지 않도록 주의하세요.
```

## 생성되는 오브젝트

**사용자**: `testuser` (실행 시 비밀번호 입력, PDB: `ORCLPDB1`)

**테이블**: `personal_info`
- PK: `member_id` (시퀀스 자동 채번, 1001 부터)
- UK: `email`
- Check: `gender ∈ {M, F}`, `status ∈ {ACTIVE, INACTIVE, DORMANT, WITHDRAWN}`

**인덱스**: 5개 (name, mobile, join_date, status, company)

**시퀀스**: `seq_personal_info`

## 컬럼 목록

| 컬럼 | 타입 | 설명 |
|---|---|---|
| `member_id` | NUMBER(10) | 회원번호 (PK) |
| `name` | VARCHAR2(50) | 한글 이름 |
| `name_en` | VARCHAR2(100) | 영문 이름 |
| `rrn_masked` | VARCHAR2(20) | 주민번호 (뒷자리 마스킹) |
| `birth_date` | DATE | 생년월일 |
| `gender` | CHAR(1) | 성별 (M/F) |
| `email` | VARCHAR2(100) | 이메일 (UK) |
| `mobile` | VARCHAR2(20) | 휴대폰 |
| `tel` | VARCHAR2(20) | 자택전화 |
| `zipcode` | VARCHAR2(10) | 우편번호 |
| `address` | VARCHAR2(200) | 기본주소 |
| `address_detail` | VARCHAR2(100) | 상세주소 |
| `job` | VARCHAR2(50) | 직업 |
| `company` | VARCHAR2(100) | 회사명 |
| `department` | VARCHAR2(50) | 부서 |
| `position` | VARCHAR2(50) | 직급 |
| `annual_income` | NUMBER(12) | 연봉 |
| `join_date` | DATE | 가입일 |
| `last_login_date` | DATE | 최종로그인 |
| `marketing_agree` | CHAR(1) | 마케팅수신 (Y/N) |
| `status` | VARCHAR2(10) | 회원상태 |
| `memo` | VARCHAR2(500) | 비고 |
| `created_at` | TIMESTAMP | 생성일시 |
| `updated_at` | TIMESTAMP | 수정일시 |

## 데이터 특성

- **50건**, 성별·연령·지역·직업·회사·직급 랜덤 분포
- 이름: 한국 성씨 30개 + 자주 쓰이는 이름 조합
- 식별번호: `TEST-0001` 형태의 명백한 예시값
- 이메일: RFC 예약 도메인 `example.com`, `example.net`, `example.org`만 사용
- 전화번호와 주소: 실제 연락처로 오인하기 어려운 예시값
- 회사·직업: 가상 회사명과 다양한 직군
- 상태: ACTIVE 70%, INACTIVE 16%, DORMANT 10%, WITHDRAWN 4%
- 완전 가공된 데이터 (실제 개인정보 아님)

## 자주 쓰는 쿼리

```sql
-- 전체 조회
SELECT * FROM personal_info WHERE ROWNUM <= 10;

-- 조건 검색
SELECT name, mobile, company
FROM   personal_info
WHERE  status = 'ACTIVE'
  AND  gender = 'F'
  AND  birth_date >= DATE '1990-01-01'
ORDER BY join_date DESC;

-- 통계
SELECT company, COUNT(*), AVG(annual_income)
FROM   personal_info
GROUP BY company
ORDER BY 2 DESC;

-- 최근 30일 가입자
SELECT * FROM personal_info
WHERE  join_date >= SYSDATE - 30;
```

## 데이터 재생성

가상 데이터를 새로 뽑으려면:

```bash
python3 gen_data.py > 03-insert-data.sql
```

`gen_data.py` 안의 `random.seed(20260813)` 를 다른 값으로 바꾸면 다른 데이터가 생성됩니다.

## 정리 (제거)

```sql
-- testuser 접속 상태에서
DROP TABLE personal_info CASCADE CONSTRAINTS PURGE;
DROP SEQUENCE seq_personal_info;

-- 또는 SYSDBA 로 사용자 자체 제거
sqlplus / as sysdba
ALTER SESSION SET CONTAINER = ORCLPDB1;
DROP USER testuser CASCADE;
```
