# 🚀 BloodConnect Running Guide

This guide describes how to run and configure all components of the BloodConnect system for local development.

---

## 🏗️ Tech Stack & Ports

| Component | Directory | Language / Framework | Port |
|-----------|-----------|----------------------|------|
| **AI Service** | `ai-service/` | Python / FastAPI | `8000` |
| **API BFF** | `api-backend/` | Node.js / Express | `8090` |
| **Notification Service** | `notification-backend/` | Node.js / Express | `8080` |
| **Frontend** | Root directory | Flutter (Dart) | - |

---

## ⚡ Option 1: Running Individually (Recommended for Dev Logs)

To run the application, open separate terminal windows for each of the services below:

### 1. AI Service (Python / FastAPI)
Handles eligibility prediction models and the AI doctor chat assistant.
```bash
cd ai-service
pip install -r requirements.txt
python3 -m uvicorn main:app --host 127.0.0.1 --port 8000
```
> [!TIP]
> If you are using the AI chat assistant, add your OpenRouter key to your `.env` file:
> `AI_ASSISTANT_API_KEY=your_openrouter_api_key`

### 2. API BFF Backend (Node.js)
Acts as the central backend connecting to Supabase and Firebase.
```bash
cd api-backend
npm install
npm start
```

### 3. Notification Service (Node.js) - *Optional*
Handles FCM push notifications to donors.
```bash
cd notification-backend
npm install
INTERNAL_SECRET="bloodnotification" GOOGLE_APPLICATION_CREDENTIALS="../keys/bloodconnect-mvp-b605f-firebase-adminsdk-fbsvc-c292f56d04.json" npm start
```

### 4. Flutter App
```bash
# In the root folder
flutter run
```

---

## 🐳 Option 2: Docker Compose (All Backends in One Terminal)

If you have Docker installed, you can start all backend services simultaneously:

```bash
# Set your environment variables first:
export NOTIFICATION_BACKEND_SECRET="bloodnotification"
export GOOGLE_APPLICATION_CREDENTIALS="/Users/apple/blood-connect/keys/bloodconnect-mvp-b605f-firebase-adminsdk-fbsvc-c292f56d04.json"
export DATABASE_URL="postgresql://postgres.icnxkxnjnsirprikiavy:feyi3z5LGv23Bgtq@aws-1-eu-west-1.pooler.supabase.com:6543/postgres"

# Build and start services
docker compose up --build
```
In a second terminal, start the Flutter app:
```bash
flutter run
```

---

## 📱 Network Configurations (Simulator vs. Physical Device)

The Flutter app automatically resolves local network routing based on the target:

* **iOS Simulator / Web / Desktop:** Automatically connects to `127.0.0.1`.
* **Android Emulator:** Automatically routes to the host machine via `10.0.2.2`.
* **Physical Device (Wi-Fi):** 
  If testing on a physical phone, copy `.env_example` to `.env` in the root folder, and set your computer's local Wi-Fi IP address:
  ```env
  API_BASE_URL=http://192.168.100.34:8090
  AI_SERVICE_URL=http://192.168.100.34:8000
  ```
  Then launch your services binding to `0.0.0.0` or your Wi-Fi IP:
  ```bash
  python3 -m uvicorn main:app --host 0.0.0.0 --port 8000
  ```
