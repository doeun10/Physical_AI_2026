/* PawFeeder AI RAG 챗봇 위젯
 * 평소에는 오른쪽 아래 둥근 버튼, 마우스를 올리면 작은 대화창이 열립니다.
 * 사용법: <script src="chatbot/chatbot.js" data-endpoint="https://<ref>.supabase.co/functions/v1/chat" defer></script>
 */
(function () {
  const script = document.currentScript;
  const ENDPOINT = script?.dataset.endpoint || "";
  const ANON_KEY = script?.dataset.anonKey || ""; // Edge Function의 JWT 검증을 켜둔 경우에만 필요
  const CLOSE_DELAY = 700;

  const css = `
  #pf-chat { position:fixed; right:20px; bottom:20px; z-index:9999; font-family:"Plus Jakarta Sans","Noto Sans KR",system-ui,sans-serif; }
  #pf-chat * { box-sizing:border-box; }
  #pf-chat .pf-launcher { width:56px; height:56px; border-radius:50%; border:0; background:#a8381c; color:#fff; cursor:pointer;
    box-shadow:0 6px 20px rgba(168,56,28,.35); display:flex; align-items:center; justify-content:center; margin-left:auto;
    transition:transform .2s ease, opacity .2s ease; }
  #pf-chat .pf-launcher svg { width:26px; height:26px; }
  #pf-chat.open .pf-launcher { transform:scale(.85); opacity:0; pointer-events:none; height:0; }
  #pf-chat .pf-panel { position:absolute; right:0; bottom:0; width:340px; max-width:calc(100vw - 32px); height:460px; max-height:calc(100vh - 40px);
    background:#fff; border:1px solid #ebe3dd; border-radius:16px; box-shadow:0 12px 40px rgba(24,28,35,.18);
    display:flex; flex-direction:column; overflow:hidden; transform-origin:bottom right;
    transform:scale(.2); opacity:0; pointer-events:none; transition:transform .22s ease, opacity .18s ease; }
  #pf-chat.open .pf-panel { transform:scale(1); opacity:1; pointer-events:auto; }
  #pf-chat .pf-head { background:#a8381c; color:#fff; padding:12px 14px; display:flex; align-items:center; gap:8px; }
  #pf-chat .pf-head strong { font-size:14px; flex:1; }
  #pf-chat .pf-head button { background:none; border:0; color:#fff; font-size:20px; line-height:1; cursor:pointer; padding:0 4px; }
  #pf-chat .pf-body { flex:1; overflow-y:auto; padding:12px; background:#FAF8F5; display:flex; flex-direction:column; gap:8px; }
  #pf-chat .pf-msg { max-width:85%; padding:8px 11px; border-radius:12px; font-size:13.5px; line-height:1.55; white-space:pre-wrap; word-break:break-word; }
  #pf-chat .pf-bot { background:#fff; border:1px solid #ebe3dd; color:#181c23; align-self:flex-start; border-bottom-left-radius:4px; }
  #pf-chat .pf-user { background:#a8381c; color:#fff; align-self:flex-end; border-bottom-right-radius:4px; }
  #pf-chat .pf-err { background:#ffdad6; color:#93000a; align-self:flex-start; }
  #pf-chat .pf-src { font-size:11px; color:#8b716b; margin-top:4px; }
  #pf-chat .pf-typing { color:#8b716b; font-style:italic; }
  #pf-chat .pf-suggest { display:flex; flex-wrap:wrap; gap:6px; align-self:flex-start; max-width:100%; }
  #pf-chat .pf-suggest button { background:#fff; border:1px solid #dfc0b8; color:#a8381c; border-radius:999px; padding:6px 11px;
    font:inherit; font-size:12.5px; cursor:pointer; text-align:left; transition:background .15s ease; }
  #pf-chat .pf-suggest button:hover { background:#fbeee9; }
  #pf-chat .pf-suggest button:disabled { opacity:.5; cursor:not-allowed; }
  #pf-chat form { display:flex; gap:6px; padding:10px; border-top:1px solid #ebe3dd; background:#fff; }
  #pf-chat input { flex:1; border:1px solid #dfc0b8; border-radius:10px; padding:9px 11px; font:inherit; font-size:13.5px; outline:none; min-width:0; }
  #pf-chat input:focus { border-color:#a8381c; }
  #pf-chat form button { background:#a8381c; color:#fff; border:0; border-radius:10px; padding:0 14px; font:inherit; font-size:13px; font-weight:600; cursor:pointer; }
  #pf-chat form button:disabled { opacity:.5; cursor:not-allowed; }
  @media (max-width:480px) { #pf-chat { right:16px; bottom:16px; } }
  `;

  const style = document.createElement("style");
  style.textContent = css;
  document.head.appendChild(style);

  const root = document.createElement("div");
  root.id = "pf-chat";
  root.innerHTML = `
    <div class="pf-panel" role="dialog" aria-label="PawFeeder AI 챗봇">
      <div class="pf-head"><strong>PawFeeder AI에게 물어보세요</strong><button type="button" class="pf-close" aria-label="닫기">×</button></div>
      <div class="pf-body"></div>
      <form><input type="text" placeholder="궁금한 점을 입력해 주세요" maxlength="500" aria-label="질문 입력"><button type="submit">전송</button></form>
    </div>
    <button type="button" class="pf-launcher" aria-label="챗봇 열기">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a8 8 0 0 1-11.6 7.1L4 20l1-4.6A8 8 0 1 1 21 12z"/></svg>
    </button>`;
  document.body.appendChild(root);

  const body = root.querySelector(".pf-body");
  const form = root.querySelector("form");
  const input = root.querySelector("input");
  const sendBtn = form.querySelector("button");
  const history = [];
  let closeTimer = null;
  let busy = false;

  function addMsg(text, cls) {
    const el = document.createElement("div");
    el.className = `pf-msg ${cls}`;
    el.textContent = text;
    body.appendChild(el);
    body.scrollTop = body.scrollHeight;
    return el;
  }

  addMsg("안녕하세요! PawFeeder AI 제품, 기술, 모델 조사 내용에 대해 궁금한 점을 물어보세요.", "pf-bot");

  // ----- 추천 질문 (누르면 바로 질문). 처음엔 앞의 4개, 답변 뒤엔 아직 안 물어본 것 중 3개 -----
  const SUGGESTIONS = [
    "얼굴 인식은 어떻게 동작하나요?",
    "여러 마리를 어떻게 구분하나요?",
    "사료 정량 오차는 얼마인가요?",
    "네트워크가 끊기면 어떻게 되나요?",
    "어떤 비전 모델을 비교했나요?",
    "전처리는 어떤 순서로 하나요?",
    "새 반려동물은 어떻게 등록하나요?",
    "야간에도 인식이 되나요?",
    "등록되지 않은 동물이 오면 어떻게 되나요?",
    "어떤 하드웨어를 사용하나요?",
    "개체 식별 정확도 목표는 얼마인가요?",
    "도입하면 비용을 얼마나 절감할 수 있나요?",
  ];
  const asked = new Set();
  let suggest = null;

  function showSuggestions(count) {
    suggest?.remove();
    const picks = SUGGESTIONS.filter((q) => !asked.has(q)).slice(0, count);
    if (!picks.length) { suggest = null; return; }
    suggest = document.createElement("div");
    suggest.className = "pf-suggest";
    for (const q of picks) {
      const b = document.createElement("button");
      b.type = "button";
      b.textContent = q;
      b.addEventListener("click", () => ask(q));
      suggest.appendChild(b);
    }
    body.appendChild(suggest);
    body.scrollTop = body.scrollHeight;
  }
  showSuggestions(4);

  // ----- 열기/닫기 (마우스 올리면 열림, 벗어나면 잠시 후 닫힘. 입력 중이면 유지) -----
  const open = () => { clearTimeout(closeTimer); root.classList.add("open"); };
  const close = () => { root.classList.remove("open"); };
  const shouldStayOpen = () => busy || document.activeElement === input || input.value.trim() !== "";

  root.addEventListener("mouseenter", open);
  root.addEventListener("mouseleave", () => {
    clearTimeout(closeTimer);
    closeTimer = setTimeout(() => { if (!shouldStayOpen()) close(); }, CLOSE_DELAY);
  });
  root.querySelector(".pf-launcher").addEventListener("click", () => { open(); input.focus(); }); // 터치 기기용
  root.querySelector(".pf-close").addEventListener("click", () => { input.blur(); close(); });
  document.addEventListener("keydown", (e) => { if (e.key === "Escape") { input.blur(); close(); } });
  document.addEventListener("click", (e) => { if (!root.contains(e.target) && !busy) close(); });

  // ----- 질문 보내기 -----
  form.addEventListener("submit", (e) => {
    e.preventDefault();
    ask(input.value.trim());
  });

  async function ask(question) {
    if (!question || busy) return;
    if (!ENDPOINT) { addMsg("챗봇 서버 주소(data-endpoint)가 설정되지 않았어요.", "pf-err"); return; }

    suggest?.remove();
    asked.add(question);
    addMsg(question, "pf-user");
    input.value = "";
    busy = true;
    sendBtn.disabled = true;
    const typing = addMsg("답변을 찾는 중…", "pf-bot pf-typing");

    try {
      const headers = { "Content-Type": "application/json" };
      if (ANON_KEY) { headers.apikey = ANON_KEY; headers.Authorization = `Bearer ${ANON_KEY}`; }
      const res = await fetch(ENDPOINT, {
        method: "POST",
        headers,
        body: JSON.stringify({ question, history: history.slice(-6) }),
      });
      const data = await res.json().catch(() => ({}));
      typing.remove();
      if (!res.ok || data.error) throw new Error(data.error || `서버 오류 (${res.status})`);

      const answer = String(data.answer || "").replace(/\*\*(.+?)\*\*/g, "$1").replace(/`([^`]+)`/g, "$1").replace(/^\s*[*-] /gm, "• ");
      const el = addMsg(answer, "pf-bot");
      const srcs = [...new Set((data.sources || []).map((s) => s.source))];
      if (srcs.length) {
        const src = document.createElement("div");
        src.className = "pf-src";
        src.textContent = `참고: ${srcs.join(", ")}`;
        el.appendChild(src);
      }
      history.push({ role: "user", text: question }, { role: "model", text: answer });
    } catch (err) {
      typing.remove();
      addMsg(`죄송해요, 답변을 가져오지 못했어요. (${err.message})`, "pf-err");
    } finally {
      busy = false;
      sendBtn.disabled = false;
      showSuggestions(3);
      body.scrollTop = body.scrollHeight;
    }
  }
})();
