-- project_reports 의 보고서를 챗봇 검색용(documents)으로 임베딩하는 절차
-- ingest Edge Function 토큰 없이 DB 안에서 처리합니다. Gemini 키는 get_gemini_key() 로 DB 안에서만 사용합니다.
-- 문서를 조각내는 함수 public.rag_chunk_markdown(source, markdown) 은 마이그레이션
-- rag_markdown_chunker_and_pg_net 으로 생성되어 있습니다 (ingest 함수와 같은 규칙: 제목 단위, 900자, 150자 겹침).

-- 1) Gemini에 임베딩 요청 (비동기). 반환된 request_id 를 기억해 두세요.
select net.http_post(
  url := 'https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:batchEmbedContents',
  headers := jsonb_build_object('Content-Type', 'application/json', 'x-goog-api-key', public.get_gemini_key()),
  body := jsonb_build_object('requests', (
    select jsonb_agg(jsonb_build_object(
      'model', 'models/gemini-embedding-001',
      'content', jsonb_build_object('parts', jsonb_build_array(jsonb_build_object('text', c.content))),
      'title', c.title,
      'taskType', 'RETRIEVAL_DOCUMENT',
      'outputDimensionality', 768) order by c.ord)
    from public.project_reports r cross join lateral public.rag_chunk_markdown(r.file_path, r.content) c
    where r.file_path = 'report/hardware_parts.md')),
  timeout_milliseconds := 60000
) as request_id;

-- 2) 몇 초 뒤 응답 확인 (status_code 200, n = 조각 수)
-- select id, status_code, jsonb_array_length((content::jsonb)->'embeddings') n from net._http_response where id = <request_id>;

-- 3) 같은 source 의 예전 조각을 지우고 새로 저장
-- with emb as (
--   select e.ordinality::int as ord, e.value->'values' as v
--   from net._http_response h, jsonb_array_elements((h.content::jsonb)->'embeddings') with ordinality e
--   where h.id = <request_id>
-- ), chunks as (
--   select c.ord, c.title, c.content
--   from public.project_reports r cross join lateral public.rag_chunk_markdown(r.file_path, r.content) c
--   where r.file_path = 'report/hardware_parts.md'
-- ), del as (
--   delete from public.documents where source = 'report/hardware_parts.md'
-- )
-- insert into public.documents (source, title, content, embedding)
-- select 'report/hardware_parts.md', c.title, c.content, (emb.v::text)::extensions.vector(768)
-- from chunks c join emb using (ord);
