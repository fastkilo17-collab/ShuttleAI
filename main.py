"""ShuttleAI prototype API. Vision inference is intentionally a stub."""
from collections import defaultdict
from datetime import datetime, timezone
from typing import Literal
import asyncio
import json
import os
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

app = FastAPI(title="ShuttleAI Cloud API", version="0.1.0-prototype")
app.add_middleware(CORSMiddleware, allow_origins=os.getenv("CORS_ORIGINS", "*").split(","), allow_credentials=False, allow_methods=["GET", "POST"], allow_headers=["*"])

scores = defaultdict(lambda: {"match_id": "", "side_a": "ฝั่ง A", "side_b": "ฝั่ง B", "points_a": 0, "points_b": 0, "status": "setup", "ai_status": "not_integrated", "last_event": None, "updated_at": None})
seen_events = set()
connections: dict[str, set[WebSocket]] = defaultdict(set)

class MatchInit(BaseModel):
    match_id: str = Field(min_length=1, max_length=120)
    side_a: str = "ฝั่ง A"
    side_b: str = "ฝั่ง B"

class ScoreEvent(BaseModel):
    match_id: str
    event_key: str = Field(min_length=1, max_length=200)
    source: Literal["manual", "ai_test", "undo", "system"]
    point_to: Literal["A", "B"]
    confidence: float | None = Field(default=None, ge=0, le=1)
    reason: str = ""

async def broadcast(match_id: str):
    dead = []
    payload = json.dumps(scores[match_id], ensure_ascii=False)
    for ws in list(connections[match_id]):
        try: await ws.send_text(payload)
        except Exception: dead.append(ws)
    for ws in dead: connections[match_id].discard(ws)

@app.get("/health")
async def health():
    return {"ok": True, "service": "shuttleai-cloud-api", "time": datetime.now(timezone.utc).isoformat(), "vision_model": "not-integrated", "automatic_scoring_enabled": False}

@app.post("/matches")
async def init_match(body: MatchInit):
    scores[body.match_id].update({"match_id": body.match_id, "side_a": body.side_a, "side_b": body.side_b, "status": "live", "updated_at": datetime.now(timezone.utc).isoformat()})
    await broadcast(body.match_id)
    return scores[body.match_id]

@app.get("/matches/{match_id}")
async def get_match(match_id: str):
    state = scores[match_id]
    if not state["match_id"]: state["match_id"] = match_id
    return state

@app.post("/matches/{match_id}/events")
async def add_event(match_id: str, body: ScoreEvent):
    if body.match_id != match_id: raise HTTPException(400, "match_id mismatch")
    dedupe_key = (match_id, body.event_key)
    if dedupe_key in seen_events:
        return {"ok": True, "duplicate": True, "score": scores[match_id]}
    # AI events deliberately cannot change the score until a validated model is integrated.
    if body.source == "ai_test":
        return {"ok": False, "accepted": False, "reason": "AI vision model not integrated; no automatic point was awarded", "score": scores[match_id]}
    seen_events.add(dedupe_key)
    key = "points_a" if body.point_to == "A" else "points_b"
    scores[match_id][key] += 1
    scores[match_id]["last_event"] = {"event_key": body.event_key, "source": body.source, "point_to": body.point_to, "confidence": body.confidence, "reason": body.reason}
    scores[match_id]["updated_at"] = datetime.now(timezone.utc).isoformat()
    await broadcast(match_id)
    return {"ok": True, "duplicate": False, "score": scores[match_id]}

@app.websocket("/ws/scores/{match_id}")
async def score_socket(ws: WebSocket, match_id: str):
    await ws.accept(); connections[match_id].add(ws)
    try:
        await ws.send_text(json.dumps(scores[match_id], ensure_ascii=False))
        while True: await ws.receive_text()
    except WebSocketDisconnect: pass
    finally: connections[match_id].discard(ws)

@app.post("/vision/frame")
async def vision_frame_stub():
    """Placeholder endpoint. Real frame upload/inference is not implemented yet."""
    return {"ok": False, "decision": "uncertain", "confidence": None, "reason": "Vision inference adapter not integrated. No score change made."}
