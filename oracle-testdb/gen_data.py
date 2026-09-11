#!/usr/bin/env python3
# 가상 개인정보 데이터 생성기 (SQL INSERT 문 출력)
import random

random.seed(20260813)

surnames = ["김","이","박","최","정","강","조","윤","장","임",
            "한","오","서","신","권","황","안","송","류","전",
            "홍","고","문","양","손","배","백","허","유","남"]

male_names = ["민준","서준","도윤","예준","시우","주원","하준","지호","지후","준서",
              "준우","현우","도현","우진","건우","선우","서진","연우","유준","은우",
              "정우","성민","진호","동현","재현","태윤","승현","지환","현준","성호"]

female_names = ["서연","서윤","지우","서현","민서","하은","하윤","윤서","지유","지민",
                "채원","수아","지아","지윤","은서","다은","예은","수빈","시은","소율",
                "예린","예서","유나","가은","연서","서아","리아","시아","나연","혜원"]

en_male = ["Minjun","Seojun","Doyun","Yejun","Siwoo","Juwon","Hajun","Jiho","Jihu","Junseo",
           "Junwoo","Hyunwoo","Dohyun","Woojin","Gunwoo","Sunwoo","Seojin","Yeonwoo","Yujun","Eunwoo"]
en_female = ["Seoyeon","Seoyun","Jiwoo","Seohyun","Minseo","Haeun","Hayun","Yunseo","Jiyu","Jimin",
             "Chaewon","Sua","Jia","Jiyun","Eunseo","Daeun","Yeeun","Subin","Sieun","Soyul"]

domains = ["example.com", "example.net", "example.org"]

sido = [
    ("테스트광역시 샘플구", "예시로", "가상동"),
    ("데모특별시 연습구", "튜토리얼로", "실습동"),
    ("예시도 테스트시", "샘플길", "데모동"),
]

jobs_companies = [
    ("소프트웨어 개발자", "예시테크", "개발팀", "선임"),
    ("데이터 분석가", "샘플데이터", "분석팀", "책임"),
    ("프로젝트 매니저", "테스트시스템즈", "PMO", "매니저"),
    ("DBA", "데모클라우드", "인프라팀", "책임"),
]

statuses = ["ACTIVE"]*35 + ["INACTIVE"]*8 + ["DORMANT"]*5 + ["WITHDRAWN"]*2
memos = [None]*35 + ["VIP 고객", "재가입 회원", "이벤트 당첨자", "장기 미접속",
                     "카드결제 등록", "테스트 계정", "우수회원", "베타테스터",
                     "기업고객", "학생할인 적용", "월정액 사용자", "휴면 예정",
                     "탈퇴 요청", "본인인증 완료", "SNS 연동"]

rows = []
used_emails = set()
used_mobiles = set()

for i in range(50):
    gender = random.choice(['M', 'F'])
    if gender == 'M':
        given = random.choice(male_names)
        given_en = random.choice(en_male)
        rrn_gender = random.choice(['1','3'])
    else:
        given = random.choice(female_names)
        given_en = random.choice(en_female)
        rrn_gender = random.choice(['2','4'])

    surname = random.choice(surnames)
    name = surname + given

    surname_en_map = {"김":"Kim","이":"Lee","박":"Park","최":"Choi","정":"Jung","강":"Kang",
                      "조":"Cho","윤":"Yoon","장":"Jang","임":"Lim","한":"Han","오":"Oh",
                      "서":"Seo","신":"Shin","권":"Kwon","황":"Hwang","안":"Ahn","송":"Song",
                      "류":"Ryu","전":"Jeon","홍":"Hong","고":"Ko","문":"Moon","양":"Yang",
                      "손":"Son","배":"Bae","백":"Baek","허":"Heo","유":"Yoo","남":"Nam"}
    name_en = f"{given_en} {surname_en_map.get(surname, 'X')}"

    # 생년월일 (1970 ~ 2005)
    year = random.randint(1970, 2005)
    month = random.randint(1, 12)
    day = random.randint(1, 28)
    birth_date = f"{year:04d}-{month:02d}-{day:02d}"
    rrn_year = f"{year%100:02d}"
    rrn_masked = f"TEST-{i+1:04d}"

    # 이메일
    while True:
        prefix_choices = [given_en.lower(), given_en.lower()+str(random.randint(1,999)),
                          surname_en_map.get(surname,'x').lower()+given_en.lower()[:3],
                          given_en.lower()+"_"+surname_en_map.get(surname,'x').lower()]
        email = f"{random.choice(prefix_choices)}@{random.choice(domains)}"
        if email not in used_emails:
            used_emails.add(email)
            break

    # 휴대폰
    while True:
        mobile = f"010-0000-{i+1:04d}"
        if mobile not in used_mobiles:
            used_mobiles.add(mobile)
            break

    # 자택전화
    area_codes = ['02','031','032','033','041','042','043','051','052','053','054','055','061','062','063','064']
    if random.random() < 0.4:
        tel = f"02-000-{i+1:04d}"
    else:
        tel = None

    # 주소
    si, ro, dong = random.choice(sido)
    zipcode = "00000"
    address = f"{si} {ro} {random.randint(1,999)}"
    address_detail = f"샘플아파트 {i+1:03d}동 {i+1:04d}호"

    # 직업
    job, company, dept, pos = random.choice(jobs_companies)
    annual_income = random.choice([35000000, 42000000, 48000000, 55000000, 62000000,
                                    70000000, 78000000, 85000000, 92000000, 100000000,
                                    115000000, 130000000, 150000000, 180000000, 220000000])

    # 가입일 (2020-01-01 ~ 2026-08-01)
    join_year = random.randint(2020, 2026)
    join_month = random.randint(1, 8) if join_year == 2026 else random.randint(1, 12)
    join_day = random.randint(1, 28)
    join_date = f"{join_year:04d}-{join_month:02d}-{join_day:02d}"

    # 최종 로그인 (가입일 이후 ~ 2026-08-13)
    last_login_year = random.randint(join_year, 2026)
    last_login_month = random.randint(1,8) if last_login_year == 2026 else random.randint(1,12)
    last_login_day = random.randint(1, 28)
    last_login = f"{last_login_year:04d}-{last_login_month:02d}-{last_login_day:02d}"

    marketing = random.choice(['Y','Y','N','N','N'])
    status = random.choice(statuses)
    memo = random.choice(memos)

    rows.append({
        'name': name, 'name_en': name_en, 'rrn': rrn_masked, 'birth': birth_date,
        'gender': gender, 'email': email, 'mobile': mobile, 'tel': tel,
        'zipcode': zipcode, 'address': address, 'address_detail': address_detail,
        'job': job, 'company': company, 'dept': dept, 'position': pos,
        'income': annual_income, 'join': join_date, 'last_login': last_login,
        'marketing': marketing, 'status': status, 'memo': memo
    })

# SQL INSERT 문 출력
print("-- =============================================================================")
print("--  03-insert-data.sql")
print("--  가상 개인정보 50건 삽입 (Python 스크립트로 자동 생성됨)")
print("--  실행 : run_all.sh 사용 권장")
print("-- =============================================================================")
print()
print("SET DEFINE OFF")
print("WHENEVER SQLERROR CONTINUE")
print()
print("-- 기존 데이터 정리")
print("TRUNCATE TABLE personal_info;")
print("ALTER SEQUENCE seq_personal_info RESTART START WITH 1001;")
print()
print("-- 데이터 삽입 시작")

def q(v):
    if v is None:
        return "NULL"
    s = str(v).replace("'","''")
    return f"'{s}'"

for r in rows:
    tel_val = q(r['tel'])
    memo_val = q(r['memo'])
    print(f"""INSERT INTO personal_info (
  member_id, name, name_en, rrn_masked, birth_date, gender,
  email, mobile, tel, zipcode, address, address_detail,
  job, company, department, position, annual_income,
  join_date, last_login_date, marketing_agree, status, memo
) VALUES (
  seq_personal_info.NEXTVAL, {q(r['name'])}, {q(r['name_en'])}, {q(r['rrn'])},
  TO_DATE({q(r['birth'])}, 'YYYY-MM-DD'), {q(r['gender'])},
  {q(r['email'])}, {q(r['mobile'])}, {tel_val}, {q(r['zipcode'])},
  {q(r['address'])}, {q(r['address_detail'])},
  {q(r['job'])}, {q(r['company'])}, {q(r['dept'])}, {q(r['position'])}, {r['income']},
  TO_DATE({q(r['join'])}, 'YYYY-MM-DD'), TO_DATE({q(r['last_login'])}, 'YYYY-MM-DD'),
  {q(r['marketing'])}, {q(r['status'])}, {memo_val}
);""")

print()
print("COMMIT;")
print()
print("-- 통계 갱신")
print("EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'PERSONAL_INFO');")
print()
print("-- 확인")
print("SELECT COUNT(*) AS total_rows FROM personal_info;")
print("SELECT status, COUNT(*) FROM personal_info GROUP BY status ORDER BY 1;")
print("SELECT gender, COUNT(*) FROM personal_info GROUP BY gender ORDER BY 1;")
print()
print("PROMPT")
print("PROMPT ===========================================================")
print("PROMPT  개인정보 데이터 50건 삽입 완료")
print("PROMPT ===========================================================")
print()
print("EXIT")
