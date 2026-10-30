# ShuttleAI test plan

## Smoke tests now
1. Start API and verify `GET /health` reports `ok: true` and `automatic_scoring_enabled: false`.
2. `POST /matches` with `demo-match`.
3. Connect WebSocket `/ws/scores/demo-match`; verify initial state arrives.
4. `POST /matches/demo-match/events` with a unique `source: manual` event; verify exactly one point and WebSocket update.
5. Repeat the same `event_key`; verify `duplicate: true` and no second point.
6. Send `source: ai_test`; verify rejected and score unchanged.
7. Add `obs-overlay/index.html` as an OBS Browser Source and verify the demo score updates.
8. On Android, verify camera preview, API health status and manual test buttons.

## Real-video validation before auto-scoring
- Gather consented court videos with reference labels for every rally result.
- Include shuttle occlusion, line calls, flicker, motion blur, side/end angles and dropped frames.
- Measure rally-winner accuracy, false score changes, missed points, duplicate events and P95 decision latency.
- Require a no-decision state when visual evidence is insufficient.
- Keep auto-scoring disabled until a held-out test set meets agreed acceptance thresholds.
