# Recall, Feedback & Opik

## Does the app call the recall route on the backend?

**Yes.** When the user finishes a recall session, the app calls **POST /api/recall** with:

- `trace_id`, `content_id`, `recall_correct`, `recall_total`

Data is queued locally and sent when online; if offline, it is retried later. Open-ended answers are **not** sent.

---

## Does feedback use Opik correctly?

**Yes.**

- **"Was this useful?"** (ContentDetailView) → **POST /api/feedback** with `trace_id`, `content_id`, `feedback` (useful/not_useful), optional `recall_correct`/`recall_total`. The backend logs this to Opik for evaluation.
- **Recall completion** → **POST /api/recall** with recall metrics; backend logs to Opik (recall ratio, etc.).

Opik is used for evaluation and product improvement. Changing future **relevance to the user’s goals** based on feedback would require additional backend (or app) logic that consumes Opik data to adjust analysis; that is not implemented yet.

---

## Notification intensity and number of notifications

**Yes.** Notification intensity is tied to **Learning Mode** (Settings):

- **Casual** → recall reminder delay **24h** (fewer notifications).
- **Deep Focus** → **12h**.
- **Exam Prep** → **2h** (more frequent).

Learning mode is persisted and used when scheduling recall reminders (new content, “see again later”, abandonment). So a higher-intensity mode means **more frequent** recall notifications.

---

## Notification timers and the calendar

**Yes.** Scheduled recall reminders are stored and shown on the **Review Schedule** tab:

- When a recall reminder is scheduled (new triggered content, “see again later”, or abandonment), the app adds an entry to `ScheduledRecallStore` with the **fire date**.
- **Review Schedule** calendar and “Upcoming Sessions” list are driven by that store (recall items appear as “Recall: &lt;title&gt;”).
- Completing a recall session or choosing “No” to “see again later?” removes that content from the calendar.

---

## Insights and real data

**Yes.** The **Insights** tab is wired to local stores:

- **Interventions triggered**, **below threshold**, **false positives**, **total content analyzed** → from `ObservabilityStore` (Opik-style events stored locally).
- **Recall attempts**, **success rate** (MCQ), **concepts learned** → from `RecallSessionStore` and `ContentStore`.
- **Key insights** text is generated from that data (e.g. “Signal triggered N recall sessions…”, “You completed N sessions with X% correct…”).

Refreshes when you open the Insights screen.
