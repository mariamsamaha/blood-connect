## Notification Backend (FCM v1)

This is a small Node.js service that the Flutter app calls to send Firebase Cloud Messaging (FCM v1) notifications whenever a new blood request is created.

### 1. Prerequisites

- Node.js 18+ installed.
- A Firebase service account JSON file for your project.
- The `GOOGLE_APPLICATION_CREDENTIALS` environment variable pointing to that JSON file when you run the server or deploy it (Cloud Run, VM, etc.).

### 2. Install dependencies

```bash
cd notification-backend
npm install
```

### 3. Run locally

```bash
export GOOGLE_APPLICATION_CREDENTIALS="/absolute/path/to/your-service-account.json"
export PORT=8080
node src/server.js
```

You should see:

```text
Notification backend listening on port 8080
```

Then set in your Flutter `.env` (already loaded via `flutter_dotenv`):

```text
NOTIFICATION_BACKEND_URL=http://localhost:8080/sendNewRequest
```

### 4. Deploy (Cloud Run example)

From the `notification-backend` folder:

```bash
gcloud builds submit --tag gcr.io/YOUR_PROJECT_ID/bloodconnect-notification-backend
gcloud run deploy bloodconnect-notification-backend \
  --image gcr.io/YOUR_PROJECT_ID/bloodconnect-notification-backend \
  --platform managed \
  --allow-unauthenticated \
  --set-env-vars GOOGLE_APPLICATION_CREDENTIALS=/secrets/service-account.json
```

Configure your service account JSON as a secret/volume according to your hosting setup, then update `NOTIFICATION_BACKEND_URL` in the Flutter `.env` to the HTTPS URL of the deployed service.

