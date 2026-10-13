// 문서 업로드(임베딩) Edge Function — rag/ingest.html 과 같은 방식으로 문서를 잘라 documents 테이블에 저장
// 요청: POST { token, source, text }  (source 예: index.html, report/model.md)
// 같은 source 의 예전 조각은 지우고 새로 넣습니다.
// token 은 업로드하는 사람만 가진 값이고, 아래 TOKEN_SHA256 과 해시가 맞아야 동작합니다.

import { parseHTML } from "npm:linkedom@0.18.5";

const TOKEN_SHA256 = "9f6e6cd645e58a3e114846bf49f3b8234ca0935ce787fd1da0bf6b970531f6dd";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const EMBED_MODEL = "gemini-embedding-001";
const EMBED_DIM = 768;
const CHUNK_SIZE = 900;
const CHUNK_OVERLAP = 150;
const BATCH = 20;

type Unit = { title: string; text: string };
type Chunk = { title: string; content: string };

const sbHeaders = { "Content-Type": "application/json", apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` };
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function sha256(s: string) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function geminiKey(): Promise<string> {
  const env = Deno.env.get("GEMINI_API_KEY");
  if (env) return env;
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/get_gemini_key`, { method: "POST", headers: sbHeaders, body: "{}" });
  if (!res.ok) throw new Error(`Gemini 키 조회 실패 (${res.status})`);
  return (await res.json()) ?? "";
}

// ---------- 텍스트 추출 (rag/ingest.html 과 동일한 규칙) ----------
function htmlToUnits(html: string): Unit[] {
  const { document: doc } = parseHTML(html);
  doc.querySelectorAll("script, style, svg, noscript, img, picture, video, iframe, input, button, link, meta").forEach((el: Element) => el.remove());

  const blocks = "p,div,li,h1,h2,h3,h4,h5,h6,section,article,header,footer,nav,ul,ol,blockquote,figure,figcaption,pre,dl,dt,dd";
  doc.querySelectorAll("td, th").forEach((el: Element) => el.append(" | "));
  doc.querySelectorAll("tr, br").forEach((el: Element) => el.after("\n"));
  doc.querySelectorAll(blocks).forEach((el: Element) => { el.before("\n"); el.after("\n"); });

  const textOf = (el: Element) =>
    (el.textContent ?? "").split("\n").map((s) => s.replace(/\s+/g, " ").trim()).filter(Boolean).join("\n");

  const units: Unit[] = [];
  const roots = [...doc.body.querySelectorAll("section, header, footer")].filter(
    (el: Element) => !el.parentElement?.closest("section, header, footer"),
  );
  for (const el of roots as Element[]) {
    const h = el.querySelector("h1, h2, h3");
    const title = h ? (h.textContent ?? "").replace(/\s+/g, " ").trim() : (el.id || el.tagName.toLowerCase());
    const text = textOf(el);
    if (text) units.push({ title, text });
    el.remove();
  }
  const rest = textOf(doc.body);
  if (rest) units.push({ title: doc.title || "기타", text: rest });
  return units;
}

function markdownToUnits(md: string): Unit[] {
  const units: Unit[] = [];
  const stack: string[] = [];
  let buf: string[] = [];
  const flush = () => {
    const text = buf.join("\n").trim();
    if (text) units.push({ title: stack.filter(Boolean).join(" > "), text });
    buf = [];
  };
  let inCode = false;
  for (const line of md.replace(/\r\n/g, "\n").split("\n")) {
    if (line.trim().startsWith("```")) inCode = !inCode;
    const m = !inCode && line.match(/^(#{1,4})\s+(.*)$/);
    if (m) {
      flush();
      const level = m[1].length;
      stack.length = level - 1;
      stack[level - 1] = m[2].trim();
      continue;
    }
    buf.push(line);
  }
  flush();
  return units;
}

function splitText(text: string): string[] {
  if (text.length <= CHUNK_SIZE) return [text];
  const chunks: string[] = [];
  let cur = "";
  for (let line of text.split("\n")) {
    while (line.length > CHUNK_SIZE) {
      let cut = line.lastIndexOf(". ", CHUNK_SIZE);
      if (cut < CHUNK_SIZE / 2) cut = CHUNK_SIZE; else cut += 1;
      if (cur) { chunks.push(cur); cur = ""; }
      chunks.push(line.slice(0, cut).trim());
      line = line.slice(cut).trim();
    }
    if (cur && cur.length + line.length + 1 > CHUNK_SIZE) {
      chunks.push(cur);
      const tail = cur.slice(-CHUNK_OVERLAP);
      const nl = tail.indexOf("\n");
      cur = nl >= 0 ? tail.slice(nl + 1) : "";
    }
    cur = cur ? cur + "\n" + line : line;
  }
  if (cur.trim()) chunks.push(cur);
  return chunks;
}

function buildChunks(source: string, raw: string): Chunk[] {
  const units = /\.html?$/i.test(source) ? htmlToUnits(raw) : markdownToUnits(raw);
  const chunks: Chunk[] = [];
  for (const u of units) {
    for (const c of splitText(u.text)) {
      if (c.trim().length >= 30) chunks.push({ title: u.title || source, content: c.trim() });
    }
  }
  return chunks;
}

// ---------- 임베딩 & 저장 ----------
async function embedBatch(items: Chunk[], key: string): Promise<number[][]> {
  const body = {
    requests: items.map((c) => ({
      model: `models/${EMBED_MODEL}`,
      content: { parts: [{ text: c.content }] },
      title: c.title,
      taskType: "RETRIEVAL_DOCUMENT",
      outputDimensionality: EMBED_DIM,
    })),
  };
  for (let attempt = 0; attempt < 4; attempt++) {
    const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${EMBED_MODEL}:batchEmbedContents`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": key },
      body: JSON.stringify(body),
    });
    if (res.status === 429 || res.status >= 500) { await sleep(10000 * (attempt + 1)); continue; }
    if (!res.ok) throw new Error(`Gemini ${res.status}: ${await res.text()}`);
    const data = await res.json();
    return data.embeddings.map((e: { values: number[] }) => e.values);
  }
  throw new Error("Gemini 요청 제한이 계속됩니다.");
}

async function sb(path: string, init: RequestInit) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, { ...init, headers: { ...sbHeaders, ...(init.headers ?? {}) } });
  if (!res.ok) throw new Error(`Supabase ${res.status}: ${await res.text()}`);
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("POST only", { status: 405 });
  try {
    const { token, source, text } = await req.json();
    if (typeof token !== "string" || (await sha256(token)) !== TOKEN_SHA256) {
      return new Response("forbidden", { status: 403 });
    }
    if (!source || !text) return new Response("source, text 필요", { status: 400 });

    const key = await geminiKey();
    const chunks = buildChunks(source, text);
    await sb(`documents?source=eq.${encodeURIComponent(source)}`, { method: "DELETE" });
    for (let i = 0; i < chunks.length; i += BATCH) {
      const part = chunks.slice(i, i + BATCH);
      const vectors = await embedBatch(part, key);
      const rows = part.map((c, j) => ({ source, title: c.title, content: c.content, embedding: vectors[j] }));
      await sb("documents", { method: "POST", headers: { Prefer: "return=minimal" }, body: JSON.stringify(rows) });
    }
    return Response.json({ source, chunks: chunks.length });
  } catch (err) {
    console.error(err);
    return Response.json({ error: err instanceof Error ? err.message : String(err) }, { status: 500 });
  }
});
