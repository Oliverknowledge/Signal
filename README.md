# Policy Aware Learning Agent For Career Retraining And New Year Skill Goals

Signal is an autonomous learning agent that decides when learning should happen and when it should not, turning everyday content into measurable progress.

## Demo Video

https://youtu.be/H9j7-wSRR-I

---

## What This Is

Signal is a production mobile agent that:

- Analyzes real world content using LLMs
- Decides whether to trigger learning or protect user focus
- Generates active recall when learning value is high
- Continuously evaluates its own decisions using Opik

---

## Problem

Most learning products optimize for content consumption.

Real users fail learning goals because:

- Progress is invisible
- Learning is inconsistent
- Content volume overwhelms attention
- No system decides when learning is worth interruption

Signal optimizes for attention, consistency, and measurable progress.

---

## Why This Project Is Strong For This Track

- Real functionality running on a physical iPhone
- Real world relevance for career switchers and New Year skill goals
- Real agent decision making, not just generation
- Real evaluation and observability using Opik
- Human in the loop correction built in

---

## Core Agent Behavior

For every saved item the agent chooses exactly one action:

- Trigger active recall
- Ignore while still saving content silently

Ignored content is preserved. The system chooses not to interrupt, not to discard.

---

## LLM And Agent Usage

LLMs are used where they create real value:

- Content understanding and concept extraction
- Learning value and relevance evaluation
- Recall question generation
- Open ended recall grading
- LLM as judge evaluation in production

Agent capabilities include retrieval from prior captured learning, policy based decision making, and tool driven evaluation pipelines.

---

## Evaluation And Observability

Every decision is fully traceable.

Each trace records:

- Intervention policy
- System decision
- Relevance score
- Learning value score
- Concept density
- Retrieval usage
- Agent step sequence

No raw user content or personal data is logged.

---

## Opik Integration

Offline experiments compare policies and prompt strategies across datasets.

Online evaluation continuously scores live production decisions using a deterministic policy aware LLM judge.

This enables measurable agent quality, regression detection, and real world decision monitoring.

---

## Human In The Loop

If the agent incorrectly ignores useful content, the user can submit feedback and immediately unlock recall questions for that item.

This creates a direct correction path between user signal and agent behavior.

---

## Real World Example

User preparing for a systems engineering interview shares two videos.

C++ memory management video triggers recall and preparation nudges.

General programming video is saved silently with no interruption.

The agent protects focus without losing data.

---

## Privacy And Safety

- No raw article text or transcripts stored in observability logs
- No personally identifiable data logged
- Recall submissions use aggregate metrics only
- Open ended answers are only sent for grading when user requests

---

## Technical Overview

### iOS Application

- Swift based app with Share Extension capture
- Background processing using App Groups
- Runs fully on device with remote inference backend

### Backend

- Content analysis
- Recall generation
- Recall grading
- Feedback processing
- Opik trace logging

---

## Why iPhone Matters

Signal runs where decisions matter most.

Learning happens during real daily behavior, not inside a desktop dashboard.

This proves production viability, not prototype viability.

---

## Demo Flow

1. Create learning goal and upcoming event
2. Share two YouTube videos from the iOS share sheet
3. Observe triggered versus ignored decisions
4. Complete recall session
5. Submit feedback on a missed learning opportunity
6. View Opik traces and online evaluation results

---

## Design Principles

- Explainability over opaque autonomy
- Measured progress over content volume
- Consistency over intensity
- Real world usefulness over novelty

---

## One Line Summary

Signal is an agent that decides when learning is worth your attention and proves those decisions are correct using real evaluation.
