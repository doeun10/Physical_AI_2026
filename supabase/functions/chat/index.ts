// PawFeeder AI RAG 챗봇 Edge Function
// 질문 → Gemini 임베딩 → Supabase에서 비슷한 문서 조각 검색 → Gemini로 답변 생성
//
// Gemini 키: Edge Function Secret GEMINI_API_KEY 가 있으면 그것을, 없으면
//   Supabase Vault 의 'gemini_api_key' 를 get_gemini_key() 함수로 읽어서 사용합니다.
// SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY 는 Supabase가 자동으로 넣어줍니다.

let GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const EMBED_MODEL = "gemini-embedding-001";
const EMBED_DIM = 768; // schema.sql 의 vector(768) 과 같아야 함
// 기본은 빠른 Flash-Lite(약 1~2초). 혼잡(429/503)하면 Flash(생각 단계 끔)로 넘어감
const CHAT_MODEL = Deno.env.get("GEMINI_CHAT_MODEL") ?? "gemini-flash-lite-latest";
const FALLBACK_MODELS = ["gemini-flash-latest", "gemini-3.8-flash"];
const THINKING_OFF: Record<string, unknown> = { "gemini-flash-latest": { thinkingBudget: 0 } };
const MATCH_COUNT = 6;
const MAX_QUESTION_LEN = 500;

const GEMINI = "https://generativelanguage.googleapis.com/v1beta/models";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SYSTEM_PROMPT = `너는 "PawFeeder AI" 제품 홈페이지의 안내 챗봇이다.
규칙:
- 반드시 아래 [참고 자료]에 있는 내용만 근거로 한국어로 답한다.
- 참고 자료에 없는 내용은 지어내지 말고 "제공된 자료에서는 확인되지 않습니다"라고 말한다.
- 존댓말(~습니다, ~해요)로 답한다.
- 답은 핵심만 짧게: 3~4문장 또는 글머리표 3~4개 이내로 쓰고, 300자를 넘기지 않는다.
- 인사말이나 "제공된 자료에 따르면" 같은 군더더기 없이 바로 답한다.
- 수치, 모델 이름, 가격 등은 자료에 적힌 그대로 쓴다.`;

type Match = { id: number; source: string; title: string | null; content: string; similarity: number };
type Turn = { role: "user" | "model"; text: string };

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json; charset=utf-8" },
  });
}

async function loadGeminiKey(): Promise<string> {
  if (GEMINI_API_KEY) return GEMINI_API_KEY;
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/get_gemini_key`, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
    body: "{}",
  });
  if (res.ok) GEMINI_API_KEY = (await res.json()) ?? "";
  return GEMINI_API_KEY;
}

async function embedQuery(text: string): Promise<number[]> {
  const res = await fetch(`${GEMINI}/${EMBED_MODEL}:embedContent`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-goog-api-key": GEMINI_API_KEY },
    body: JSON.stringify({
      model: `models/${EMBED_MODEL}`,
      content: { parts: [{ text }] },
      taskType: "RETRIEVAL_QUERY",
      outputDimensionality: EMBED_DIM,
    }),
  });
  if (!res.ok) throw new Error(`임베딩 실패 (${res.status}): ${await res.text()}`);
  const data = await res.json();
  return data.embedding.values;
}

async function searchDocuments(embedding: number[]): Promise<Match[]> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/match_documents`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
    },
    body: JSON.stringify({ query_embedding: embedding, match_count: MATCH_COUNT }),
  });
  if (!res.ok) throw new Error(`검색 실패 (${res.status}): ${await res.text()}`);
  return await res.json();
}

async function generateAnswer(question: string, matches: Match[], history: Turn[]): Promise<string> {
  const context = matches
    .map((m, i) => `[자료 ${i + 1}] (출처: ${m.source}${m.title ? " / " + m.title : ""})\n${m.content}`)
    .join("\n\n");

  const contents = [
    ...history.map((t) => ({ role: t.role, parts: [{ text: t.text }] })),
    {
      role: "user",
      parts: [{ text: `[참고 자료]\n${context || "(관련 자료 없음)"}\n\n[질문]\n${question}` }],
    },
  ];

  let res: Response | null = null;
  for (const model of [CHAT_MODEL, ...FALLBACK_MODELS.filter((m) => m !== CHAT_MODEL)]) {
    const generationConfig: Record<string, unknown> = { temperature: 0.3, maxOutputTokens: 1024 };
    if (THINKING_OFF[model]) generationConfig.thinkingConfig = THINKING_OFF[model];
    res = await fetch(`${GEMINI}/${model}:generateContent`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": GEMINI_API_KEY },
      body: JSON.stringify({ systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] }, contents, generationConfig }),
    });
    if (res.status !== 429 && res.status !== 503 && res.status !== 404) break;
    console.warn(`${model} 사용 불가 (${res.status}), 다음 모델 시도`);
  }
  if (!res!.ok) throw new Error(`답변 생성 실패 (${res!.status}): ${await res!.text()}`);
  const data = await res!.json();
  const parts = data.candidates?.[0]?.content?.parts ?? [];
  return parts.map((p: { text?: string }) => p.text ?? "").join("").trim() || "답변을 만들지 못했어요. 다시 질문해 주세요.";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "POST만 지원합니다." }, 405);
  if (!(await loadGeminiKey())) return json({ error: "Gemini 키가 설정되지 않았습니다. (Secret GEMINI_API_KEY 또는 Vault gemini_api_key)" }, 500);

  try {
    const body = await req.json().catch(() => ({}));
    const question = String(body.question ?? "").trim().slice(0, MAX_QUESTION_LEN);
    if (!question) return json({ error: "질문을 입력해 주세요." }, 400);

    // 최근 대화 몇 턴만 맥락으로 사용
    const history: Turn[] = Array.isArray(body.history)
      ? body.history
          .filter((t: Turn) => (t?.role === "user" || t?.role === "model") && typeof t.text === "string")
          .slice(-6)
          .map((t: Turn) => ({ role: t.role, text: t.text.slice(0, 1000) }))
      : [];
    // Gemini 대화는 user 차례로 시작해야 함
    while (history.length && history[0].role !== "user") history.shift();

    const embedding = await embedQuery(question);
    const matches = await searchDocuments(embedding);
    const answer = await generateAnswer(question, matches, history);

    return json({
      answer,
      sources: matches.map((m) => ({ source: m.source, title: m.title, similarity: Number(m.similarity.toFixed(3)) })),
    });
  } catch (err) {
    console.error(err);
    return json({ error: err instanceof Error ? err.message : String(err) }, 500);
  }
});
