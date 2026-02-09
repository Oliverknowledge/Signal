# Signal - Policy-Aware Learning Agent for Career Switchers

Signal is an AI learning agent that helps people retraining for new careers turn everyday content into consistent, measurable learning progress.

It analyzes saved content, decides whether learning is worth interrupting your day, generates active recall questions, and continuously evaluates decision quality using Opik.

Demo video: [https://www.youtube.com/watch?v=bh-UjhOsnSw](https://www.youtube.com/watch?v=bh-UjhOsnSw)

## Problem

Most learning apps assume more content equals more progress.

In reality, New Year learning goals and career transition plans often fail because:

- Progress feels invisible
- Learning is inconsistent
- Users are overwhelmed by content
- There is no system deciding when learning should actually happen

Signal focuses on attention and consistency, not content volume.

## What Signal Does

### Content Capture

Users can:

- Share URLs or text from any app (Share Extension)
- Add content manually inside Signal

Content is queued and analyzed in the main app.

### Agent Decision - Trigger or Ignore

The backend extracts:

- Key concepts
- Relevance score
- Learning value score
- Recall questions (if triggered)

The agent chooses:

Triggered:

- Generates recall prompts
- Can schedule prep-ready nudges (if event exists)

Ignored:

- Saved quietly
- No interruption
- Still accessible later

Signal chooses not to interrupt, not to discard.

### Active Recall Sessions

- Multiple choice -> graded locally
- Open-ended -> graded via backend LLM
- Only aggregate recall metrics are submitted (correct / total)

This makes learning progress measurable without storing raw answers.

### Events and Goal-Driven Learning

Users can add upcoming events (interviews, exams, certifications).

Signal:

- Prioritizes prep content for nearest event
- Sends event reminders (7 / 3 / 1 days)
- Optionally sends prep-ready nudges when high-value learning is detected

### Feedback Loop (False Negative Recovery)

If Signal ignores useful content, users can:

- Submit feedback
- Instantly unlock recall questions for that item

This creates a real human-in-the-loop correction path.

## Opik Integration (Core Differentiator)

### Trace-Level Observability

Each decision logs:

- `intervention_policy` (`focused` / `aggressive`)
- `system_decision` (`triggered` / `ignored`)
- `relevance_score`
- `learning_value_score`
- `concept_count`
- `retrieval_used` and `agent_steps`
- Anonymized reason codes (no raw content)

### Experiments (Offline Evaluation)

We run Opik experiments to compare:

- Intervention policies
- Model or prompt variants
- Decision quality across datasets

### Online Evaluation (Production Monitoring)

Opik continuously evaluates live decisions using a policy-aware judge.

This means:

- Regressions are detectable quickly
- Decision quality is measurable in production
- Agent behavior can improve using real usage data

## Privacy

- No PII in observability logs
- No raw article text or transcripts logged
- Recall submission uses aggregate metrics only
- Open-ended answers only sent when grading is requested

## Technical Overview

### iOS

Targets:

- `Signal/`
- `SignalShare/`

Share queue uses App Group:

`group.OliverStevenson.Signal`

### Backend Endpoints

```
POST /api/analyze
POST /api/grade-recall
POST /api/recall
POST /api/feedback
POST /api/opik-log
```

Authentication:

`X-Signal-Relay-Token`

## Running the Project

### iOS

1. Open project in Xcode
2. Ensure App Group entitlements are enabled
3. Run the `Signal` target

### Backend

1. `cd signal-backend`
2. Configure environment variables
3. Run locally (`npm install && npm run start`) or deploy
4. Ensure the iOS API base URL matches the backend URL

## Demo Flow

1. Add an upcoming event
2. Share two YouTube links
   - One aligned -> triggers recall
   - One misaligned -> ignored quietly
3. Complete a recall session
4. Submit feedback on a false negative
5. Show Opik experiments and online evaluation

## Design Philosophy

- Explainability over black-box autonomy
- Measurable progress over content volume
- Real-world usefulness over novelty
