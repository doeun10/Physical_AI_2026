-- 챗봇 문서(documents)를 홈페이지 상단 메뉴 9개와 같은 분류로 나눠 보기
-- documents 와 검색 함수는 그대로 두고, 분류표(doc_menu_map)와 메뉴별 뷰만 추가합니다.
-- 홈페이지 내용은 index.html 을 메뉴별 섹션("PawFeeder AI 홈페이지 > 메뉴")으로 정리해 임베딩했습니다.

-- 메뉴 분류표: section_title 이 비어 있으면 파일 전체를 그 메뉴로 분류
-- (실제 행은 Supabase 의 doc_menu_map 테이블 참고)

create or replace view public.docs_by_menu with (security_invoker = true) as
select coalesce(s.menu, f.menu, '기타')           as "메뉴",
       coalesce(s.doc_name, f.doc_name, d.source) as "문서",
       d.title                                    as "섹션",
       d.content                                  as "내용",
       d.id
from public.documents d
left join public.doc_menu_map s on s.source = d.source and s.section_title = d.title
left join public.doc_menu_map f on f.source = d.source and f.section_title is null
order by coalesce(s.menu_order, f.menu_order, 99), d.source, d.id;

create or replace view public.overview      with (security_invoker = true) as select "문서", "섹션", "내용", id from public.docs_by_menu where "메뉴" = '제품 소개';
create or replace view public.technology    with (security_invoker = true) as select "문서", "섹션", "내용", id from public.docs_by_menu where "메뉴" = '피지컬 AI 기술';
create or replace view public.motivation    with (security_invoker = true) as select "문서", "섹션", "내용", id from public.docs_by_menu where "메뉴" = '왜 필요한가?';
create or replace view public.specs         with (security_invoker = true) as select "문서", "섹션", "내용", id from public.docs_by_menu where "메뉴" = '제품 스펙';
create or replace view public.hardware      with (security_invoker = true) as select "문서", "섹션", "내용", id from public.docs_by_menu where "메뉴" = '하드웨어';
create or replace view public.preprocessing with (security_invoker = true) as select "문서", "섹션", "내용", id from public.docs_by_menu where "메뉴" = '데이터 전처리';
create or replace view public.model         with (security_invoker = true) as select "문서", "섹션", "내용", id from public.docs_by_menu where "메뉴" = 'AI 모델';
create or replace view public.inference     with (security_invoker = true) as select "문서", "섹션", "내용", id from public.docs_by_menu where "메뉴" = '추론 엔진';
create or replace view public.research      with (security_invoker = true) as select "문서", "섹션", "내용", id from public.docs_by_menu where "메뉴" = '모델 조사';
