// Simple Express backend to send FCM v1 notifications.
// Uses Firebase Admin SDK and the service account pointed to by
// GOOGLE_APPLICATION_CREDENTIALS in your environment.

const express = require('express');
const admin = require('firebase-admin');

// Initialize Firebase Admin (uses GOOGLE_APPLICATION_CREDENTIALS env var).
admin.initializeApp();

const app = express();
app.use(express.json());

// Health check
app.get('/', (_req, res) => {
  res.status(200).send('Notification backend is running');
});

// Main endpoint called from the Flutter app.
// Expects body:
// {
//   "request": {
//     "id": "...",
//     "short_id": "...",
//     "blood_type": "...",
//     "units_needed": 2,
//     "hospital_name": "..."
//   },
//   "tokens": ["fcmToken1", "fcmToken2", ...]
// }
app.post('/sendNewRequest', async (req, res) => {
  try {
    const { request, tokens } = req.body || {};

    if (!request || !Array.isArray(tokens)) {
      return res.status(400).json({ error: 'invalid_payload' });
    }

    const cleanTokens = tokens.filter((t) => typeof t === 'string' && t.length > 0);
    if (cleanTokens.length === 0) {
      return res.status(200).json({ sent: 0 });
    }

    const message = {
      notification: {
        title: `Blood request: ${request.blood_type}`,
        body: `${request.units_needed} unit(s) needed at ${request.hospital_name}`,
      },
      data: {
        type: 'new_request',
        request_id: String(request.id ?? ''),
        short_id: String(request.short_id ?? ''),
        blood_type: String(request.blood_type ?? ''),
        hospital_name: String(request.hospital_name ?? ''),
      },
      tokens: cleanTokens,
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    return res.status(200).json({
      sent: response.successCount,
      failed: response.failureCount,
    });
  } catch (err) {
    console.error('Error in /sendNewRequest', err);
    return res.status(500).json({ error: 'internal_error' });
  }
});

// Start HTTP server (for local dev or generic hosting / Cloud Run).
const port = process.env.PORT || 8080;
app.listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`Notification backend listening on port ${port}`);
});

