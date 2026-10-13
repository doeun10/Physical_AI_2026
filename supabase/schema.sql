-- PawFeeder AI RAG 챗봇: Supabase 테이블/검색 함수
-- Supabase 대시보드 → SQL Editor 에 전체를 붙여넣고 Run 하세요. (여러 번 실행해도 안전)

-- 1) 벡터 확장 켜기
create extension if not exists vector with schema extensions;

-- 2) 문서 조각(chunk) 저장 테이블
--    Gemini 임베딩(gemini-embedding-001)을 768차원으로 받아서 저장합니다.
create table if not exists public.documents (
  id         bigserial primary key,
  source     text not null,          -- 원본 파일 이름 (예: index.html, report/model.md)
  title      text,                   -- 조각이 속한 섹션 제목
  content    text not null,          -- 조각 본문
  embedding  extensions.vector(768) not null,
  created_at timestamptz not null default now()
);

create index if not exists documents_source_idx on public.documents (source);
create index if not exists documents_embedding_idx
  on public.documents using hnsw (embedding extensions.vector_cosine_ops);

-- 3) RLS 켜기: 정책을 만들지 않으므로 anon(공개 키)으로는 읽기/쓰기 불가.
--    서버(Edge Function)와 업로드 도구는 service_role 키로 접근합니다.
alter table public.documents enable row level security;

-- 4) 질문 임베딩과 가장 비슷한 조각을 찾는 함수
create or replace function public.match_documents (
  query_embedding extensions.vector(768),
  match_count     int   default 6,
  match_threshold float default 0.0
)
returns table (
  id         bigint,
  source     text,
  title      text,
  content    text,
  similarity float
)
language sql stable
set search_path = public, extensions
as $$
  select d.id, d.source, d.title, d.content,
         1 - (d.embedding <=> query_embedding) as similarity
  from public.documents d
  where 1 - (d.embedding <=> query_embedding) >= match_threshold
  order by d.embedding <=> query_embedding
  limit match_count;
$$;

-- 공개 키로는 검색 함수도 못 부르게 막기 (Edge Function만 사용)
revoke execute on function public.match_documents from public, anon, authenticated;
grant  execute on function public.match_documents to service_role;
