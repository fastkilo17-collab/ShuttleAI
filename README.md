# ShuttleAI — Android + Cloud AI + Supabase + OBS (Prototype)

ภาษาไทยเป็นหลัก • โครงสร้างต้นแบบที่แยกส่วนและทดสอบการเชื่อมต่อได้

## สถานะจริงของต้นแบบ
- Android Flutter source: กล้อง preview, หน้าคะแนน, health check ไปยัง Cloud API, ปุ่มทดสอบแต้ม (event ที่ผู้ใช้กดเท่านั้น)
- Cloud API: FastAPI health endpoint, session/status endpoints, websocket score updates, idempotent event handling
- AI inference: **ยังเป็น adapter/stub เท่านั้น** ไม่มีการตรวจจับลูกแบดหรือการตัดสินแต้มจากภาพจริงในแพ็กเกจนี้
- Supabase: migration สำหรับตาราง ShuttleAI ถูกสร้างแยกชื่อจากตารางเดิม
- OBS: Browser Source overlay แสดงคะแนนจาก WebSocket
- APK: ยังไม่ได้ build ในสภาพแวดล้อมนี้เพราะไม่มี Flutter/Android SDK ติดตั้ง ให้ใช้ GitHub Actions workflow หรือเครื่องที่ติดตั้ง Flutter SDK

อย่าใช้คะแนนทดสอบเป็นผลการแข่งขันจริง และอย่าเปิด auto-scoring ในการแข่งขันจนกว่าจะทดสอบกับวิดีโอที่ติดป้ายกำกับผลจริง

## Architecture
Phone camera → Flutter app / future WebRTC or RTMP publisher → Cloud ingest + GPU inference adapter → Score decision engine → Supabase + WebSocket → Android dashboard / OBS Browser Source.

ข้อจำกัดใน MVP นี้: แอปเปิด preview กล้องและทดสอบการเชื่อมต่อ API แต่ยังไม่ได้ส่ง video stream จากกล้องไป Cloud GPU โดยตรง; ต้องเพิ่ม WebRTC/RTMP publisher และ ingest service ก่อนทดสอบ inference แบบ real-time.

## Run Cloud API locally
```bash
cd cloud-ai
python -m venv .venv
source .venv/bin/activate # Windows: .venv\\Scripts\\activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000
```
Check `http://localhost:8000/health`.

## Configure Flutter app
Install Flutter stable + Android SDK. In `android/`, run:
```bash
flutter create . --platforms=android
flutter pub get
flutter run
```
Before running, set API URL in `lib/main.dart` (`http://10.0.2.2:8000` for Android emulator; use your computer LAN IP for physical phone). Android camera permission is declared in `android/app/src/main/AndroidManifest.xml` after `flutter create`—add `<uses-permission android:name="android.permission.CAMERA"/>` and `android.permission.INTERNET`.

## Build APK
```bash
flutter build apk --release
```
APK output: `build/app/outputs/flutter-apk/app-release.apk`.

## Cloud deploy
Deploy `cloud-ai/` to a container host with GPU support when a real model is integrated. Set `PORT` as required by provider. Keep the API private or add authentication before public use. Do not put Supabase service-role keys in the Android app.

## Supabase
Project configured for initial database: `https://ufcsprbsqungrnifeaue.supabase.co` (project name MDBadmintonLive). ShuttleAI tables are prefixed `shuttleai_`, RLS enabled and owner-scoped. The migration used for creation is in `supabase/migrations/202610210001_shuttleai_initial_schema.sql`.

The app source intentionally does not embed a Supabase secret. Use Supabase Auth and a publishable key for client access, or call Supabase through a trusted backend.

## OBS
Add `obs-overlay/index.html` as a Browser Source. For local demo, start Cloud API and use `ws://localhost:8000/ws/scores/demo-match`. For production, use `wss://` and authenticated WebSocket channels. Set the same match id in the API and overlay.

## Reliability safeguards
- `event_key` unique per match prevents duplicate event writes.
- AI candidate, accepted, rejected and uncertain decisions are distinct.
- No AI scoring decision is emitted by the stub.
- Score updates should be committed transactionally and include before/after state.
- If frames are missing, camera changes, or confidence is low, hold the score and request review.
- Record ground-truth labels and report precision/recall, false score changes, and P95 end-of-rally latency before enabling unattended scoring.
