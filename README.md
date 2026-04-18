# Helmet Violation Detection and Notification System

A smart city traffic monitoring solution that detects two-wheeler riders without helmets, performs ANPR, and sends automated notifications.

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Traffic Camera │────▶│  Flask Backend   │────▶│  Flutter App    │
│  / Mobile Cam   │     │  - Detection     │     │  - Real-time    │
└─────────────────┘     │  - ANPR          │     │  - Dashboards   │
                        │  - Notifications │     │  - Analytics    │
                        └────────┬─────────┘     └─────────────────┘
                                 │
                        ┌────────▼─────────┐
                        │  MySQL/MongoDB   │
                        │  + JSON Export  │
                        └─────────────────┘
```

## Setup

### 1. Backend (Python)

```bash
cd backend
pip install -r requirements.txt
```

Copy `.env.example` to `.env` and configure:
- **SQLite** (default): No config needed – uses `backend/data/helmet_violations.db`
- **MongoDB**: Set `MONGODB_URI` and `DATABASE_TYPE=mongodb`
- **Twilio** (SMS/WhatsApp): Set `TWILIO_*` variables

```bash
# Initialize database (creates SQLite file if needed)
python scripts/init_db.py

# Start Flask API
python run.py
```

API runs at `http://localhost:5000`

### 2. Mobile App (Flutter)

```bash
cd mobile_app
flutter pub get
flutter run
```

**Settings**: In the app, go to Settings and set the API URL:
- Android emulator: `http://10.0.2.2:5000`
- iOS simulator: `http://localhost:5000`
- Physical device: `http://<your-pc-ip>:5000`

### 3. Traffic Camera Processing (Optional)

```bash
cd backend
python video_processor.py --source 0 --api http://localhost:5000 --location "Intersection A"
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/health` | GET | Health check |
| `/api/detect` | POST | Upload image, detect violations, run ANPR |
| `/api/violations` | GET | List violations |
| `/api/owner/lookup` | GET | Lookup vehicle owner |
| `/api/owner/register` | POST | Register vehicle owner |
| `/api/notify` | POST | Send SMS/WhatsApp notification |
| `/api/analytics/daily` | GET | Daily violation counts |
| `/api/analytics/weekly` | GET | Weekly comparison |
| `/api/analytics/monthly` | GET | Monthly trends |

## Features
- **Helmet Detection**: YOLOv8 + OpenCV (train custom model for helmet/no-helmet)
- **ANPR**: EasyOCR for license plate extraction
- **Database**: SQLite (local file) by default, MongoDB optional; JSON export
- **Notifications**: Twilio SMS & WhatsApp with fine details and payment link
- **Analytics**: Daily, weekly, monthly charts in Flutter
- **Mobile**: Real-time camera capture, gallery pick, violation logs, dashboards
