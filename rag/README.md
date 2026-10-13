# RAG 챗봇 설정 가이드

홈페이지(`index.html`)와 보고서(`PRD/`, `report/*.md`) 내용을 근거로 답하는 챗봇입니다.

```
[사용자 질문] → Edge Function(chat) → Gemini 임베딩 → Supabase 벡터 검색 → Gemini 답변 → 챗봇 창
```

| 파일 | 역할 |
|---|---|
| `supabase/schema.sql` | 문서 조각 테이블(`documents`)과 검색 함수(`match_documents`) |
| `supabase/functions/chat/index.ts` | 챗봇 서버 (Gemini 키를 숨기고 검색·답변 생성) |
| `rag/ingest.html` | 문서를 잘라 임베딩해서 Supabase에 올리는 브라우저 도구 |
| `chatbot/chatbot.js` | 홈페이지 오른쪽 아래 챗봇 위젯 |

## 1. 테이블 만들기
Supabase 대시보드 → **SQL Editor** → `supabase/schema.sql` 내용 전체 붙여넣기 → **Run**

## 2. 챗봇 서버(Edge Function) 배포
1. 대시보드 → **Edge Functions** → **Secrets** → `GEMINI_API_KEY` 추가 (Google AI Studio에서 발급)
2. **Edge Functions** → **Deploy a new function** → **Via Editor** → 이름을 `chat`으로 하고 `supabase/functions/chat/index.ts` 내용 붙여넣기 → Deploy
3. 배포된 `chat` 함수 → **Details** → **Enforce JWT verification(Verify JWT)** 끄기 → Save
   (홈페이지에서 키 없이 부를 수 있게 하기 위함)

주소는 `https://znhfsjzrbjbqpccrngzx.supabase.co/functions/v1/chat` 이고, `index.html` 맨 아래 스크립트 태그에 이미 들어 있습니다.

## 3. 문서 업로드 (임베딩)
1. `rag/ingest.html` 열기
   - GitHub Pages에 올린 뒤라면 `https://doeun10.github.io/Physical_AI_2026/rag/ingest.html` → **기본 문서 자동 불러오기**
   - 내 컴퓨터에서 파일을 더블클릭해 열었다면 → 파일 선택으로 `index.html`, `PRD/PRD.md`, `report/*.md` 직접 선택
2. Supabase URL(`https://znhfsjzrbjbqpccrngzx.supabase.co`), service_role 키, Gemini 키 입력
3. **임베딩 & 업로드** 클릭 → "업로드 완료" 메시지 확인

홈페이지나 보고서를 고치면 3번만 다시 하면 됩니다. (같은 파일 이름의 예전 조각은 자동으로 교체)

## 4. 확인
`index.html`을 열고 오른쪽 아래 버튼에 마우스를 올리면 대화창이 열립니다. 질문 예: "얼굴 인식은 어떻게 동작해?", "어떤 비전 모델을 비교했어?"

## 주의
- **service_role 키와 Gemini 키는 절대 `index.html`이나 GitHub에 올리지 마세요.** Gemini 키는 Supabase Secret에만, service_role 키는 업로드 도구에 그때그때 입력합니다.
- JWT 검증을 끈 함수는 누구나 호출할 수 있어서 Gemini 무료 사용량이 소모될 수 있습니다. 과제 시연용으로는 충분하지만, 걱정되면 검증을 켜두고 `index.html` 스크립트 태그에 `data-anon-key="(anon/publishable 키)"`를 추가하세요.
- 답변 모델을 바꾸려면 Secret에 `GEMINI_CHAT_MODEL`(기본값 `gemini-2.5-flash`)을 추가하세요.
