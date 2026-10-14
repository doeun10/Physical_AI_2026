-- 챗봇 문서(documents)를 분류별로 나눠 보기 위한 구조
-- documents 테이블과 검색 함수(match_documents)는 그대로 두므로 챗봇 동작에는 영향이 없습니다.
--
--   doc_categories   문서 분류 (홈페이지, 기획, 데이터 전처리, AI 모델, 하드웨어)
--   doc_sources      원본 파일별 분류·제목 (documents.source 와 연결)
--   docs_overview    (뷰) 분류별 문서 목록과 조각 수
--   docs_homepage, docs_plan, docs_data, docs_ai_model, docs_hardware
--                    (뷰) 분류별 문서 조각. 임베딩 숫자는 빼고 읽을 수 있는 내용만 보여줌

-- 1) 문서 분류
create table if not exists public.doc_categories (
  code        text primary key,
  name        text not null,
  description text,
  sort_order  smallint not null
);
comment on table public.doc_categories is '챗봇 문서 분류';

insert into public.doc_categories (code, name, description, sort_order) values
  ('homepage', '홈페이지',          '제품 소개 홈페이지 (index.html)',                    1),
  ('plan',     '기획',              '제품 요구사항 문서 (PRD)',                           2),
  ('data',     '데이터 수집·전처리', '현장 조사 체크리스트, 데이터 전처리 명세서',          3),
  ('ai_model', 'AI 모델',           'AI 모델 설계 보고서, 비전 모델 조사 보고서',           4),
  ('hardware', '하드웨어',          '하드웨어 부품 구성 보고서',                          5)
on conflict (code) do nothing;

-- 2) 원본 파일별 분류
create table if not exists public.doc_sources (
  source        text primary key,
  category_code text not null references public.doc_categories (code),
  doc_title     text not null,
  doc_type      text,
  sort_order    smallint not null default 99
);
comment on table  public.doc_sources is '챗봇 문서의 원본 파일 목록과 분류';
comment on column public.doc_sources.source is 'documents.source 와 같은 파일 경로';

insert into public.doc_sources (source, category_code, doc_title, doc_type, sort_order) values
  ('index.html',               'homepage', 'PawFeeder AI 홈페이지',                          '홈페이지',        1),
  ('PRD/PRD.md',               'plan',     'PRD: 반려동물 개체 인식 자동 급식기',             '제품 요구사항 문서', 2),
  ('report/listcheck.md',      'data',     '데이터 전처리 현장 조사 체크리스트 (작성본)',      '체크리스트',       3),
  ('report/checklist.md',      'data',     '데이터 전처리 현장 조사 체크리스트 (빈 양식)',     '체크리스트',       4),
  ('report/prosss.md',         'data',     '사용자 환경 맞춤형 데이터 전처리 상세 명세서',     '명세서',           5),
  ('report/model.md',          'ai_model', 'AI 모델 선정 및 학습·검증 계획 보고서',           '모델 설계 보고서',  6),
  ('report/vision_models.md',  'ai_model', '비전 AI 모델 조사 보고서',                       '모델 조사 보고서',  7),
  ('report/hardware_parts.md', 'hardware', '하드웨어 부품 구성 보고서',                      '하드웨어 보고서',   8)
on conflict (source) do nothing;


-- 3) 보기용 뷰 (documents 테이블은 건드리지 않고 source 값으로 연결)
create or replace view public.docs_overview with (security_invoker = true) as
select c.name                         as "분류",
       s.doc_title                    as "문서",
       s.doc_type                     as "종류",
       s.source                       as "파일",
       count(d.id)                    as "조각 수",
       count(distinct d.title)        as "섹션 수",
       max(d.created_at)::date        as "업로드일"
from public.doc_sources s
join public.doc_categories c on c.code = s.category_code
left join public.documents d on d.source = s.source
group by c.sort_order, c.name, s.sort_order, s.doc_title, s.doc_type, s.source
order by c.sort_order, s.sort_order;
comment on view public.docs_overview is '분류별 문서 목록과 챗봇 조각 수';

create or replace view public.docs_by_category with (security_invoker = true) as
select c.code                                          as category_code,
       c.name                                          as "분류",
       s.doc_title                                     as "문서",
       coalesce(nullif(split_part(d.title, ' > ', 2), ''), d.title) as "대목차",
       d.title                                         as "섹션 경로",
       d.content                                       as "내용",
       d.id
from public.documents d
join public.doc_sources s    on s.source = d.source
join public.doc_categories c on c.code = s.category_code
order by c.sort_order, s.sort_order, d.id;
comment on view public.docs_by_category is '모든 문서 조각을 분류·문서·섹션 순으로 정렬 (임베딩 제외)';

create or replace view public.docs_homepage with (security_invoker = true) as
  select "문서", "대목차", "섹션 경로", "내용", id from public.docs_by_category where category_code = 'homepage';
create or replace view public.docs_plan with (security_invoker = true) as
  select "문서", "대목차", "섹션 경로", "내용", id from public.docs_by_category where category_code = 'plan';
create or replace view public.docs_data with (security_invoker = true) as
  select "문서", "대목차", "섹션 경로", "내용", id from public.docs_by_category where category_code = 'data';
create or replace view public.docs_ai_model with (security_invoker = true) as
  select "문서", "대목차", "섹션 경로", "내용", id from public.docs_by_category where category_code = 'ai_model';
create or replace view public.docs_hardware with (security_invoker = true) as
  select "문서", "대목차", "섹션 경로", "내용", id from public.docs_by_category where category_code = 'hardware';

comment on view public.docs_homepage is '홈페이지 문서 조각';
comment on view public.docs_plan     is '기획(PRD) 문서 조각';
comment on view public.docs_data     is '데이터 수집·전처리 문서 조각';
comment on view public.docs_ai_model is 'AI 모델 문서 조각';
comment on view public.docs_hardware is '하드웨어 문서 조각';

-- 4) RLS: 다른 테이블과 같이 공개 키로는 접근 불가
alter table public.doc_categories enable row level security;
alter table public.doc_sources    enable row level security;
