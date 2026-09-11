-- =============================================================================
--  04-sample-queries.sql
--  개인정보 테이블 확인용 샘플 쿼리
--  실행 : run_all.sh 사용 권장
-- =============================================================================

SET PAGES 100
SET LINES 200
SET LONG 1000

COL member_id  FORMAT 9999
COL name       FORMAT A10
COL name_en    FORMAT A20
COL rrn_masked FORMAT A15
COL email      FORMAT A35
COL mobile     FORMAT A15
COL job        FORMAT A20
COL company    FORMAT A25
COL position   FORMAT A12
COL status     FORMAT A10
COL address    FORMAT A50
COL income     FORMAT 999,999,999

PROMPT
PROMPT ==================== 1. 전체 건수 및 상태별 집계 ====================
SELECT status,
       COUNT(*) AS 인원수,
       ROUND(AVG(annual_income)/10000, 0) AS 평균연봉_만원
FROM   personal_info
GROUP BY status
ORDER BY 1;

PROMPT
PROMPT ==================== 2. 성별 / 연령대 분포 ====================
SELECT CASE gender WHEN 'M' THEN '남' ELSE '여' END AS 성별,
       FLOOR((SYSDATE - birth_date)/365.25/10)*10 AS 연령대,
       COUNT(*) AS 인원수
FROM   personal_info
GROUP BY gender, FLOOR((SYSDATE - birth_date)/365.25/10)*10
ORDER BY 1, 2;

PROMPT
PROMPT ==================== 3. 상위 10명 (연봉 순) ====================
SELECT member_id, name, job, company, position,
       annual_income AS income
FROM   (SELECT * FROM personal_info ORDER BY annual_income DESC)
WHERE  ROWNUM <= 10;

PROMPT
PROMPT ==================== 4. 지역별 회원 분포 (상위 10) ====================
SELECT REGEXP_SUBSTR(address, '[^ ]+') AS 시도,
       COUNT(*) AS 인원수
FROM   personal_info
GROUP BY REGEXP_SUBSTR(address, '[^ ]+')
ORDER BY 2 DESC
FETCH FIRST 10 ROWS ONLY;

PROMPT
PROMPT ==================== 5. 최근 가입자 10명 ====================
SELECT member_id, name, email, mobile,
       TO_CHAR(join_date, 'YYYY-MM-DD') AS 가입일,
       status
FROM   (SELECT * FROM personal_info ORDER BY join_date DESC)
WHERE  ROWNUM <= 10;

PROMPT
PROMPT ==================== 6. 마케팅 수신 동의자 ====================
SELECT COUNT(*) AS 동의자수,
       ROUND(COUNT(*)*100/(SELECT COUNT(*) FROM personal_info), 1) AS 동의율_퍼센트
FROM   personal_info
WHERE  marketing_agree = 'Y';

PROMPT
PROMPT ==================== 7. 회사별 소속 인원 (상위 10) ====================
SELECT company, COUNT(*) AS 인원수
FROM   personal_info
GROUP BY company
ORDER BY 2 DESC
FETCH FIRST 10 ROWS ONLY;

PROMPT
PROMPT ==================== 8. 개인정보 열람 예시 (5건, 상세) ====================
SELECT member_id, name, name_en, rrn_masked, gender,
       TO_CHAR(birth_date, 'YYYY-MM-DD') AS 생년월일,
       email, mobile
FROM   (SELECT * FROM personal_info ORDER BY DBMS_RANDOM.VALUE)
WHERE  ROWNUM <= 5;

PROMPT
PROMPT ==================== 9. 인덱스 사용 확인 ====================
SELECT index_name, column_name
FROM   user_ind_columns
WHERE  table_name = 'PERSONAL_INFO'
ORDER BY index_name, column_position;

PROMPT
PROMPT ==================== 10. 테이블 크기 ====================
SELECT segment_name, segment_type,
       ROUND(bytes/1024, 2) AS size_kb,
       blocks
FROM   user_segments
WHERE  segment_name IN ('PERSONAL_INFO')
   OR  segment_name LIKE 'IDX_PERSONAL_INFO%';

EXIT
