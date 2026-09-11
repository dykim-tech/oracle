-- =============================================================================
--  02-create-table.sql
--  개인정보 테이블 생성 : testuser 계정으로 실행
--  실행 : run_all.sh 사용 권장
-- =============================================================================

WHENEVER SQLERROR CONTINUE

-- 기존 오브젝트 삭제
DROP TABLE personal_info CASCADE CONSTRAINTS PURGE;
DROP SEQUENCE seq_personal_info;

-- 시퀀스 생성 (회원 번호 자동 채번)
CREATE SEQUENCE seq_personal_info
  START WITH 1001
  INCREMENT BY 1
  NOCACHE
  NOCYCLE;

-- 개인정보 테이블 생성
CREATE TABLE personal_info (
    member_id       NUMBER(10)      NOT NULL,     -- 회원번호
    name            VARCHAR2(50)    NOT NULL,     -- 이름
    name_en         VARCHAR2(100),                -- 영문명
    rrn_masked      VARCHAR2(20),                 -- 주민번호(마스킹)
    birth_date      DATE            NOT NULL,     -- 생년월일
    gender          CHAR(1)         NOT NULL,     -- 성별(M/F)
    email           VARCHAR2(100)   NOT NULL,     -- 이메일
    mobile          VARCHAR2(20)    NOT NULL,     -- 휴대폰
    tel             VARCHAR2(20),                 -- 자택전화
    zipcode         VARCHAR2(10),                 -- 우편번호
    address         VARCHAR2(200),                -- 주소
    address_detail  VARCHAR2(100),                -- 상세주소
    job             VARCHAR2(50),                 -- 직업
    company         VARCHAR2(100),                -- 회사명
    department      VARCHAR2(50),                 -- 부서
    position        VARCHAR2(50),                 -- 직급
    annual_income   NUMBER(12),                   -- 연봉(원)
    join_date       DATE            DEFAULT SYSDATE NOT NULL,  -- 가입일
    last_login_date DATE,                         -- 최종 로그인
    marketing_agree CHAR(1)         DEFAULT 'N',  -- 마케팅 수신 동의
    status          VARCHAR2(10)    DEFAULT 'ACTIVE' NOT NULL, -- 상태
    memo            VARCHAR2(500),                -- 비고
    created_at      TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at      TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_personal_info PRIMARY KEY (member_id),
    CONSTRAINT uk_personal_info_email UNIQUE (email),
    CONSTRAINT ck_personal_info_gender CHECK (gender IN ('M', 'F')),
    CONSTRAINT ck_personal_info_status CHECK (status IN ('ACTIVE', 'INACTIVE', 'DORMANT', 'WITHDRAWN')),
    CONSTRAINT ck_personal_info_marketing CHECK (marketing_agree IN ('Y', 'N'))
);

-- 인덱스 생성
CREATE INDEX idx_personal_info_name       ON personal_info(name);
CREATE INDEX idx_personal_info_mobile     ON personal_info(mobile);
CREATE INDEX idx_personal_info_join_date  ON personal_info(join_date);
CREATE INDEX idx_personal_info_status     ON personal_info(status);
CREATE INDEX idx_personal_info_company    ON personal_info(company);

-- 코멘트
COMMENT ON TABLE  personal_info                  IS '개인정보 테이블 (테스트용, 가상 데이터)';
COMMENT ON COLUMN personal_info.member_id        IS '회원번호(PK)';
COMMENT ON COLUMN personal_info.name             IS '한글 이름';
COMMENT ON COLUMN personal_info.name_en          IS '영문 이름';
COMMENT ON COLUMN personal_info.rrn_masked       IS '주민등록번호(뒷자리 마스킹, 예: 900101-1******)';
COMMENT ON COLUMN personal_info.birth_date       IS '생년월일';
COMMENT ON COLUMN personal_info.gender           IS '성별 (M:남, F:여)';
COMMENT ON COLUMN personal_info.email            IS '이메일 (Unique)';
COMMENT ON COLUMN personal_info.mobile           IS '휴대폰 번호';
COMMENT ON COLUMN personal_info.tel              IS '자택 전화';
COMMENT ON COLUMN personal_info.zipcode          IS '우편번호(5자리)';
COMMENT ON COLUMN personal_info.address          IS '기본주소';
COMMENT ON COLUMN personal_info.address_detail   IS '상세주소';
COMMENT ON COLUMN personal_info.job              IS '직업/직군';
COMMENT ON COLUMN personal_info.company          IS '회사명';
COMMENT ON COLUMN personal_info.department       IS '부서명';
COMMENT ON COLUMN personal_info.position         IS '직급';
COMMENT ON COLUMN personal_info.annual_income    IS '연봉(원)';
COMMENT ON COLUMN personal_info.join_date        IS '회원가입일';
COMMENT ON COLUMN personal_info.last_login_date  IS '최종 로그인 일시';
COMMENT ON COLUMN personal_info.marketing_agree  IS '마케팅 수신 동의(Y/N)';
COMMENT ON COLUMN personal_info.status           IS '회원상태 (ACTIVE/INACTIVE/DORMANT/WITHDRAWN)';
COMMENT ON COLUMN personal_info.memo             IS '비고';
COMMENT ON COLUMN personal_info.created_at       IS '레코드 생성일시';
COMMENT ON COLUMN personal_info.updated_at       IS '레코드 수정일시';

-- 확인
SELECT table_name, num_rows FROM user_tables WHERE table_name = 'PERSONAL_INFO';
SELECT COUNT(*) AS index_count FROM user_indexes WHERE table_name = 'PERSONAL_INFO';

PROMPT
PROMPT ===========================================================
PROMPT  personal_info 테이블 생성 완료
PROMPT  다음 : @03-insert-data.sql
PROMPT ===========================================================

EXIT
