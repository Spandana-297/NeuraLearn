# NeuraLearn — animations that are computed, not hallucinated

NeuraLearn teaches data structures and algorithms by running the real algorithm, recording every intermediate state, and animating that trace with narration. The AI directs the lesson; it never draws it.

## App structure
The app at `/app` moves through four screens (hash routes in `public/app/shell.js`):

| Screen | Route | What happens |
|---|---|---|
| Library | `#/` | Search box, progress, and the curriculum: 6 modules in teaching order (stacks and queues, recursion, searching, sorting, trees, graphs). |
| Topic page | `#/learn/<id>` | Choose or type the input, see validation messages, check the lesson plan and a preview of the starting state, pick AI narration and voice, then start. |
| Lesson | `#/lesson/<id>` | The computed player (`computed.js`) with the ask-the-professor panel. |
| Summary | `#/done/<id>` | Checkpoint result, key points, time, and the next lesson. |

The AI tutor for other topics lives at `#/tutor` (`app.js`). Progress is stored in the browser.

Server side, `lib/catalog.mjs` describes the curriculum and parses the topic page's input, and `lib/lessonService.mjs` is the one code path `server.mjs` uses (Netlify and Vercel run `server.mjs`'s handler too) to build a lesson. `GET /api/catalog` returns the curriculum; `POST /api/computed-lesson` accepts `{topic}` or `{algorithm, input, target}`.

## Deploy on Vercel
No git repository is needed: the Vercel CLI uploads this folder directly. (Connecting a GitHub repository is optional; it redeploys automatically on every push.)

1. Install the CLI and sign in: `npm i -g vercel`, then `vercel login`.
2. From this folder, create the project: `vercel` (accept the defaults; there is no build step, `public/` is served as is).
3. Add the environment variables (paste the values when asked):
   `vercel env add GEMINI_API_KEY production`, `vercel env add LLM_PROVIDER production` (value `gemini`), `vercel env add GEMINI_MODELS production` (value `gemini-3.5-flash,gemini-3.8-flash,gemini-flash-lite-latest`).
4. Deploy: `vercel deploy --prod`.

`.vercelignore` keeps `.env` out of the upload. Each file in `api/` is a function that runs the same request handler as `server.mjs`; `vercel.json` allows the lecture generator up to 300 seconds and sets the security headers.

## OpenAI and Grok fallback
The app tries the selected model first. If it is busy, rate-limited, or unavailable, it proceeds through the remaining configured models: Gemini models, then OpenAI, then xAI/Grok. OpenAI and xAI choices appear in the model menu once their server-side API keys are configured. Defaults are `gpt-5.4-mini` and `grok-4.7`; set `OPENAI_MODEL`, `OPENAI_MODELS`, `XAI_MODEL`, or `XAI_MODELS` to use other model IDs your accounts can access.

For Netlify, create API keys in the OpenAI and xAI developer consoles, then add each as a secret scoped to production Functions. From the linked project folder, run:
```powershell
npx netlify-cli env:set OPENAI_API_KEY "your-key" --context production --scope functions --secret
npx netlify-cli env:set XAI_API_KEY "your-key" --context production --scope functions --secret
npx netlify-cli deploy --prod
```
On Netlify, `netlify/functions/api.mjs` serves every `/api/*` route through `lib/netlify.mjs`, which runs the same handler as `server.mjs` and streams responses. Requests stop at 55 seconds (`NL_TIME_LIMIT_MS`) with a clear error, before Netlify's 60 second limit.

Do not paste provider keys into browser code, chat, or a committed `.env` file. The app accepts `GROK_API_KEY` as an alias for `XAI_API_KEY`.

## Speed
- Computed lessons build in milliseconds; nothing waits for a model.
- AI tutor answers stream into the chat as they are written, and the key points appear on the board straight away.
- Lecture part 1 starts generating as soon as its paragraphs are written, while the answer is still streaming; the remaining parts are generated in parallel and play in order.
- Lecture code is generated with low thinking: the content is already written (and fact-checked) in the explanation, so only the drawing is generated.
- A model that is busy, rate-limited, unavailable, or slow to start hands over to the next configured model, including OpenAI or xAI when their keys are present.
- Repeated questions and lectures are answered from a cache.

## Computed lessons (DSA)
Typing a supported topic (optionally with your own input, e.g. `binary search for 4 in [9, 3, 7, 1]` or `inorder of [8,3,10,1,6,null,14]`) builds a computed lesson:

1. **Route**: `lib/director.mjs` matches the topic to an algorithm and reads any input values.
2. **Execute**: `lib/tracers.mjs` runs the algorithm and records one step per operation (`{op, fact, phase, state}`). Supported: inorder, preorder, postorder and level-order traversal, binary search, bubble, insertion, selection and merge sort.
3. **Scenes**: the trace is cut into scenes, and intro, misconception, remedial and recap scenes are added. Checkpoint answers are read from the trace.
4. **Narration**: with AI narration on, the model rewrites the spoken lines only. `guardLine` rejects any line that mentions a number not in the line it replaces; rejected lines keep the computed sentence.
5. **Validation**: every scene must pass `lib/lessonSchema.mjs`. Actions can only point at real trace steps, existing nodes or indices, and real tree edges.
6. **Play**: `public/app/computed.js` renders tree and array states as SVG, plays the beats with browser speech, and handles checkpoints (a wrong answer branches to the remedial scene).

**Interrupt the professor**: while a computed lesson plays, any question in the chat pauses it and calls `POST /api/interrupt`. The server re-runs the algorithm (the client's copy of the trace is never trusted), asks the model for 1 to 3 scenes in the schema, validates them, retries once with the errors, and otherwise falls back to replaying the recorded steps around that point. The new scenes are inserted at the current beat and the lesson resumes afterwards.

**Instant mode** (Settings): no AI calls at all. Narration uses the computed sentences and questions are answered by replaying steps, so it works offline and is the safe mode for live demos.

API: `POST /api/computed-lesson {topic, narrate:'template'|'ai'}` returns `{supported:false}` or `{supported:true, lesson, narration}`; `POST /api/interrupt {algorithm, data, target?, stepIndex, question, offline?}` returns `{scenes, source:'ai'|'replay'}`.

## Other topics (generated lessons)
Topics the router does not recognise use the earlier engine: the configured model writes an explanation, then generates a complete runnable HTML/CSS/vanilla-JavaScript lesson that runs in a sandboxed iframe. These visuals are generated, not computed.

## Requirements
- Node.js 20 or newer.
- A configured model endpoint for AI narration and non-DSA topics: Gemini by default, with optional OpenAI and xAI fallback keys, Ollama, or another OpenAI-compatible endpoint. Computed lessons in Instant mode need no model at all.
- A modern browser. Narration uses browser speech synthesis, whose voices vary by operating system/browser.

## Run on Windows PowerShell
1. Open PowerShell in this folder.
2. Copy `.env.example` to `.env`.
3. For local inference, install Ollama and pull a code-capable model, for example `ollama pull qwen2.5-coder:7b`, then set `OLLAMA_MODEL=qwen2.5-coder:7b` in `.env`. Use a stronger model if it produces weak code or shallow teaching.
4. Start the server: `node server.mjs` (or `npm start`).
5. Open `http://127.0.0.1:4173`.

No API key is required when using Ollama locally. For a hosted OpenAI-compatible endpoint, configure `.env`:
```
LLM_PROVIDER=openai-compatible
LLM_BASE_URL=https://your-provider.example/v1
LLM_API_KEY=your-secret-key
LLM_MODEL=your-code-capable-model
```
Some providers, including Gemini's OpenAI-compatible API, may be usable through this endpoint format; use that provider's documented base URL and model identifier. Keep `.env` private and never place secrets in browser code.

## How the new engine works
- `POST /api/code-lesson` asks the configured model for a full standalone teaching program, not a JSON description of diagram nodes.
- The generated lesson chooses a representation appropriate to the topic: for example, a binary tree and traversal output, photosynthesis process, packet movement, address translation, or equation transformations.
- The lesson runs in an iframe with `sandbox="allow-scripts"` and without same-origin privileges. It cannot access the parent application's DOM or cookies. Generated code is still untrusted code; do not remove the sandbox or add `allow-same-origin` casually.
- The generated program reports chapter/beat events to the host. The host UI handles synchronized subtitles, browser narration, outline, progress, pause/resume/replay, speed control, and lesson-aware Q&A.
- The host retains the existing visual design and outer controls. No separate Next button is required.

## Honest limitations
Computed lessons: the frames, step facts and checkpoint answers come from executing the algorithm, but the AI-rewritten narration is only fact-checked for numbers, so its wording can still be imperfect. Fourteen algorithms are computed, with tree, array, graph, stack, queue and recursion-tree visualizers; equation steps are not built yet. Narration is English only. AI narration and AI interrupt answers are covered by tests with a mocked model but have not been run against a live model in this environment.

Generated lessons: This is a working code-generation architecture, not a guarantee that every model response is excellent. Lesson correctness, animation quality, and compliance with the event protocol depend on the selected model. Small local models may return incomplete HTML, use generic visuals, or miss a control message; a stronger code-capable model is recommended. Live generation against your own Gemini/API key has not been verified in this environment. Validate important course content before relying on it. Browser speech voices are platform-dependent.

This is a local-first starter, not a deployed multi-user SaaS. There is no account system, cloud persistence, billing, robust PDF parsing, or hosted deployment. The server binds to `127.0.0.1`. Before public deployment, add authentication, authorization, secure secret storage, HTTPS, rate limits, per-user quotas, upload parsing/scanning, privacy/data-retention controls, observability, and automated browser/content tests.

## Tests
Run `node --test`.
