# Otis (call-auditor) — Naya setup guide

Ye repo `Sup1port-123/call-auditor` ki copy hai. Code tayyar hai aur build pass
hota hai. App ko **live** karne ke liye neeche ke steps ek baar karne hain.
Total time: ~30–45 minute.

Asli app `web/` folder mein hai (Next.js). Root ka `app.py` purana Streamlit
app hai — use chhod dijiye.

---

## Step 1 — Database (Supabase) · ~10 min

1. https://supabase.com par sign up / login karein → **New project**.
   - Name: `otis-support` (kuch bhi)
   - Database password: koi strong password (kahin save kar lein)
   - Region: **Mumbai (ap-south-1)**
2. Project ban jaaye to left menu → **SQL Editor** → **New query**.
3. Is repo ki file **`web/supabase-setup-all.sql`** kholiye, poora text copy
   karke wahan paste kijiye → **Run**.
   - "Row Level Security" ka popup aaye to **Run without RLS** chuniye.
   - "Success" aana chahiye. Ye file saari tables ek baar mein bana deti hai
     (purani alag-alag `supabase-*.sql` files chalane ki zaroorat nahi).
4. Left menu → **Project Settings → API** se ye 3 cheezein copy kar lein:
   - **Project URL** → `NEXT_PUBLIC_SUPABASE_URL`
   - **anon public** key → `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - **service_role** key → `SUPABASE_SERVICE_ROLE_KEY` (ye secret hai, kisi
     ko na bhejein)

> `web/supabase-seed-inbound-agent.sql` mat chalaiye — usme quoting galat hai
> aur error aayega. Agent app ke **Agents → New** page se bana lijiye.

## Step 2 — API keys · ~10 min

| Key | Kahan se milegi | Zaroori? |
|---|---|---|
| `ASSEMBLYAI_API_KEY` | https://www.assemblyai.com → Dashboard → API Keys | **Haan** (recording → text) |
| `OPENAI_API_KEY` | https://platform.openai.com/api-keys (billing add karni hogi) | **Haan** (scoring) |
| `GOOGLE_API_KEY` | https://aistudio.google.com/apikey | Optional (backup) |
| `ANTHROPIC_API_KEY` | https://console.anthropic.com | Optional (backup) |

Agar purane call-auditor ki keys use karni hain to unke Vercel project →
Settings → Environment Variables se le sakte hain.

## Step 3 — App live karna (Vercel) · ~10 min

1. https://vercel.com par **Continue with GitHub** se login karein
   (`Sup1port-123` account se).
2. **Add New → Project** → `support_project` repo → **Import**.
3. **Root Directory** ke aage **Edit** dabaiye → **`web`** chuniye.
   (Ye zaroori hai, warna build fail hoga.)
4. **Environment Variables** mein ye daaliye:

   ```
   NEXT_PUBLIC_SUPABASE_URL=...        (Step 1)
   NEXT_PUBLIC_SUPABASE_ANON_KEY=...   (Step 1)
   SUPABASE_SERVICE_ROLE_KEY=...       (Step 1)
   ASSEMBLYAI_API_KEY=...              (Step 2)
   OPENAI_API_KEY=...                  (Step 2)
   LLM_PROVIDER=openai
   CRON_SECRET=koi-bhi-lamba-random-text
   ```

5. **Deploy** dabaiye. 2–3 minute mein link milega, jaise
   `https://support-project-xxxx.vercel.app`.
6. Wo link wapas **Settings → Environment Variables** mein
   `NEXT_PUBLIC_APP_URL` naam se daaliye (email ke links isi par jaayenge) →
   **Deployments → ⋯ → Redeploy**.

Ab app khuliye → **Agents → New** se agent banaiye → **New Audit** mein ek
recording URL daal kar test kijiye.

## Step 4 — Daily email report (optional) · ~10 min

1. Gmail account mein **2-Step Verification** on karein, phir
   https://myaccount.google.com/apppasswords se **App password** banaiye.
2. Vercel env vars mein daaliye, phir Redeploy:
   ```
   SMTP_USER=aapka@gmail.com
   SMTP_PASS=16-akshar-ka-app-password
   REPORT_FROM_EMAIL=Otis <aapka@gmail.com>
   ```
3. App mein **Settings** page par emails aur time set karke **Enable** kijiye.
4. https://cron-job.org par free account → **Create cronjob**:
   - URL: `https://<aapka-app>.vercel.app/api/cron/daily-report?key=<CRON_SECRET>`
   - Schedule: har 15 minute

---

## Kuch aur integrations (sirf zaroorat ho to)

Code mein ye bhi hain; inki keys tabhi chahiye jab ye feature use karne hon:
`KARTA_API_KEY` (Karta auto-ingest), `DEEPGRAM_API_KEY`, `SARVAM_API_KEY`,
`GROQ_API_KEY`, `JEV_*`, `AI_GATEWAY_API_KEY`, `ADMIN_EMAIL`.

Poori technical detail: [`HANDOVER.md`](HANDOVER.md).
