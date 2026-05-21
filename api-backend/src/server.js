/**
 * BloodConnect API BFF
 * All database access goes through this server. Flutter sends Firebase ID tokens.
 * Postgres credentials stay server-side only.
 */

const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
// Legacy: Flutter used to load Supabase creds from repo-root .env
require('dotenv').config({ path: path.join(__dirname, '..', '..', '.env') });

const express = require('express');
const rateLimit = require('express-rate-limit');
const { query, testConnection, validateDbConfig } = require('./db');
const { requireFirebaseAuth } = require('./auth');
const { serverError } = require('./errors');

const app = express();
app.use(express.json({ limit: '1mb' }));

const isProduction = process.env.NODE_ENV === 'production';

if (isProduction) {
  app.set('trust proxy', 1);
  app.use((req, res, next) => {
    const proto = req.headers['x-forwarded-proto'];
    if (proto && proto !== 'https') {
      return res.status(403).json({ error: 'https_required' });
    }
    return next();
  });
}

const apiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 120,
  standardHeaders: true,
  legacyHeaders: false,
});

app.use('/api/', apiLimiter);

function uid(req) {
  return req.firebaseUser.uid;
}

function profileSelect() {
  return `SELECT *,
    ST_Y(location::geometry) as latitude,
    ST_X(location::geometry) as longitude
    FROM users`;
}

// ─── Health ───────────────────────────────────────────────────────────────────
app.get('/', (_req, res) => {
  res.status(200).json({ status: 'ok', service: 'bloodconnect-api' });
});

app.get('/health/db', async (_req, res) => {
  const config = validateDbConfig();
  if (!config.ok) {
    return res.status(503).json({
      status: 'misconfigured',
      missing: config.missing,
      hint: 'Copy api-backend/.env.example → api-backend/.env and set Supabase credentials.',
    });
  }
  try {
    const ok = await testConnection();
    return res.status(ok ? 200 : 503).json({ status: ok ? 'ok' : 'failed' });
  } catch (err) {
    return res.status(503).json({
      status: 'error',
      detail: err.message,
    });
  }
});

// ─── Users ────────────────────────────────────────────────────────────────────
app.get('/api/v1/users/me', requireFirebaseAuth, async (req, res) => {
  try {
    const rows = await query(
      `${profileSelect()} WHERE firebase_uid = $1`,
      [uid(req)],
    );
    if (rows.length === 0) return res.status(404).json({ error: 'not_found' });
    return res.json(rows[0]);
  } catch (err) {
    return serverError(res, err, 'GET /users/me');
  }
});

app.post('/api/v1/users/me/bootstrap', requireFirebaseAuth, async (req, res) => {
  try {
    const fb = req.firebaseUser;
    const existing = await query(
      `${profileSelect()} WHERE firebase_uid = $1`,
      [fb.uid],
    );
    if (existing.length > 0) return res.json(existing[0]);

    const hospitalCheck = await query('SELECT is_hospital_email($1) AS v', [
      fb.email,
    ]);
    const accountType =
      hospitalCheck[0]?.v === true ? 'hospital' : 'regular';
    const role = accountType === 'hospital' ? 'hospital' : 'donor';

    const inserted = await query(
      `INSERT INTO users (
        firebase_uid, email, name, account_type,
        is_recipient, donor_status, role
      ) VALUES ($1, $2, $3, $4, FALSE, 'available', $5)
      RETURNING *,
        ST_Y(location::geometry) as latitude,
        ST_X(location::geometry) as longitude`,
      [fb.uid, fb.email, fb.name || 'User', accountType, role],
    );
    return res.status(201).json(inserted[0]);
  } catch (err) {
    console.error('POST /users/me/bootstrap', err);
    return res.status(500).json({ error: 'internal_error' });
  }
});

app.post('/api/v1/users/me/complete', requireFirebaseAuth, async (req, res) => {
  try {
    const fb = req.firebaseUser;
    const body = req.body || {};
    const {
      name,
      email,
      phone,
      bloodType,
      role,
      accountType,
      hospitalName,
      hospitalCode,
      latitude,
      longitude,
      cityArea,
    } = body;

    const existing = await query(
      `${profileSelect()} WHERE firebase_uid = $1`,
      [fb.uid],
    );
    if (existing.length > 0) return res.json(existing[0]);

    const existingByEmail = await query(
      `${profileSelect()} WHERE email = $1`,
      [email],
    );
    if (existingByEmail.length > 0) {
      const updated = await query(
        `UPDATE users SET firebase_uid = $1, name = $2, phone = $3, updated_at = NOW()
         WHERE email = $4
         RETURNING *,
           ST_Y(location::geometry) as latitude,
           ST_X(location::geometry) as longitude`,
        [fb.uid, name, phone, email],
      );
      return res.json(updated[0]);
    }

    if (accountType === 'hospital') {
      const hasLoc = latitude != null && longitude != null;
      const locSql = hasLoc
        ? 'ST_SetSRID(ST_MakePoint($8, $7), 4326)::geography'
        : 'ST_SetSRID(ST_MakePoint(31.2357, 30.0444), 4326)::geography';
      const params = hasLoc
        ? [
            fb.uid,
            email,
            name,
            phone,
            hospitalName,
            hospitalCode,
            latitude,
            longitude,
            cityArea || '',
          ]
        : [
            fb.uid,
            email,
            name,
            phone,
            hospitalName,
            hospitalCode,
            cityArea || '',
          ];
      const row = await query(
        `INSERT INTO users (
          firebase_uid, email, name, phone,
          account_type, hospital_name, hospital_code,
          is_recipient, donor_status, role, location,
          hospital_verified, city_area
        ) VALUES (
          $1, $2, $3, $4,
          'hospital', $5, $6,
          FALSE, 'unavailable', 'hospital', ${locSql},
          FALSE, $${hasLoc ? 9 : 7}
        ) RETURNING *,
          ST_Y(location::geometry) as latitude,
          ST_X(location::geometry) as longitude`,
        params,
      );
      return res.status(201).json(row[0]);
    }

    const donorStatus = role === 'donor' ? 'available' : 'unavailable';
    const hasLoc = latitude != null && longitude != null;
    const locPart = hasLoc
      ? `ST_SetSRID(ST_MakePoint($9, $8), 4326)::geography`
      : 'NULL';
    const params = hasLoc
      ? [
          fb.uid,
          email,
          name,
          phone,
          bloodType,
          donorStatus,
          role,
          latitude,
          longitude,
          cityArea || '',
        ]
      : [
          fb.uid,
          email,
          name,
          phone,
          bloodType,
          donorStatus,
          role,
          cityArea || '',
        ];
    const row = await query(
      `INSERT INTO users (
        firebase_uid, email, name, phone, blood_type,
        account_type, is_recipient, donor_status, role, location, city_area
      ) VALUES (
        $1, $2, $3, $4, $5,
        'regular', FALSE, $6, $7, ${locPart}, $${hasLoc ? 10 : 8}
      ) RETURNING *,
        ST_Y(location::geometry) as latitude,
        ST_X(location::geometry) as longitude`,
      params,
    );
    return res.status(201).json(row[0]);
  } catch (err) {
    console.error('POST /users/me/complete', err);
    return res.status(500).json({ error: 'internal_error' });
  }
});

app.patch('/api/v1/users/me', requireFirebaseAuth, async (req, res) => {
  try {
    const updates = req.body?.updates;
    if (!updates || typeof updates !== 'object' || Object.keys(updates).length === 0) {
      return res.status(400).json({ error: 'invalid_payload' });
    }
    const allowed = new Set([
      'name',
      'phone',
      'blood_type',
      'donor_status',
      'notification_enabled',
      'notification_radius_km',
      'is_recipient',
      'city_area',
    ]);
    const keys = Object.keys(updates).filter((k) => allowed.has(k));
    if (keys.length === 0) return res.status(400).json({ error: 'no_allowed_fields' });

    const sets = keys.map((k, i) => `${k} = $${i + 2}`).join(', ');
    const values = keys.map((k) => updates[k]);
    await query(
      `UPDATE users SET ${sets}, updated_at = NOW() WHERE firebase_uid = $1`,
      [uid(req), ...values],
    );
    return res.status(204).send();
  } catch (err) {
    console.error('PATCH /users/me', err);
    return res.status(500).json({ error: 'internal_error' });
  }
});

app.patch('/api/v1/users/me/location', requireFirebaseAuth, async (req, res) => {
  try {
    const { latitude, longitude } = req.body || {};
    if (latitude == null || longitude == null) {
      return res.status(400).json({ error: 'invalid_payload' });
    }
    await query(
      `UPDATE users SET location = ST_SetSRID(ST_MakePoint($2::float8, $3::float8), 4326)::geography,
       updated_at = NOW() WHERE firebase_uid = $1`,
      [uid(req), longitude, latitude],
    );
    return res.status(204).send();
  } catch (err) {
    console.error('PATCH /users/me/location', err);
    return res.status(500).json({ error: 'internal_error' });
  }
});

app.patch('/api/v1/users/me/fcm-token', requireFirebaseAuth, async (req, res) => {
  try {
    const token = req.body?.token;
    if (!token) return res.status(204).send();
    await query(
      `UPDATE users SET fcm_token = $2, updated_at = NOW() WHERE firebase_uid = $1`,
      [uid(req), token],
    );
    return res.status(204).send();
  } catch (err) {
    return serverError(res, err, 'PATCH /users/me/fcm-token');
  }
});

app.get('/api/v1/users/me/badges', requireFirebaseAuth, async (req, res) => {
  try {
    const userId = req.query.userId;
    if (!userId) return res.status(400).json({ error: 'userId_required' });
    const rows = await query(
      `SELECT b.id, b.badge_name AS name, b.description,
              b.icon_url AS icon, b.requirement_value AS points_required,
              ub.earned_at
       FROM user_badges ub
       JOIN badges b ON b.id = ub.badge_id
       WHERE ub.user_id = $1::uuid
       ORDER BY ub.earned_at DESC`,
      [userId],
    );
    return res.json(rows);
  } catch (err) {
    console.error('GET /users/me/badges', err);
    return res.json([]);
  }
});

app.get('/api/v1/users/me/badges/progress', requireFirebaseAuth, async (req, res) => {
  try {
    const userId = req.query.userId;
    if (!userId) return res.status(400).json({ error: 'userId_required' });
    const rows = await query(
      `SELECT b.id, b.badge_name AS name, b.description, b.icon_url AS icon,
              b.requirement_value, b.requirement_type,
              ub.earned_at IS NOT NULL AS is_earned,
              CASE b.requirement_type
                WHEN 'donation_count' THEN u.total_donations
                WHEN 'points' THEN COALESCE(u.reward_points, 0)
                ELSE 0
              END AS current_value
       FROM badges b
       CROSS JOIN users u
       LEFT JOIN user_badges ub ON ub.badge_id = b.id AND ub.user_id = u.id
       WHERE u.id = $1::uuid
       ORDER BY is_earned DESC, b.requirement_value ASC`,
      [userId],
    );
    return res.json(rows);
  } catch (err) {
    console.error('GET /users/me/badges/progress', err);
    return res.json([]);
  }
});

// ─── Hospitals (recipient) ────────────────────────────────────────────────────
app.get('/api/v1/hospitals', requireFirebaseAuth, async (req, res) => {
  try {
    const lat = req.query.lat != null ? parseFloat(req.query.lat) : null;
    const lng = req.query.lng != null ? parseFloat(req.query.lng) : null;
    const radiusKm = parseInt(req.query.radiusKm || '120', 10);
    const baseWhere = `account_type = 'hospital' AND hospital_verified = TRUE
      AND is_active = TRUE AND location IS NOT NULL`;

    if (lat != null && lng != null && !Number.isNaN(lat) && !Number.isNaN(lng)) {
      const nearbyM = radiusKm * 1000;
      const rows = await query(
        `SELECT id, hospital_name, hospital_code, email,
          ST_Y(location::geometry) as latitude,
          ST_X(location::geometry) as longitude,
          ROUND((ST_Distance(location, ST_SetSRID(ST_MakePoint($2::float8, $1::float8), 4326)::geography) / 1000)::numeric, 2) as distance_km,
          CASE WHEN ST_DWithin(location, ST_SetSRID(ST_MakePoint($2::float8, $1::float8), 4326)::geography, $3::float8) THEN 0 ELSE 1 END as is_far
         FROM users WHERE ${baseWhere}
         ORDER BY is_far ASC, distance_km ASC`,
        [lat, lng, nearbyM],
      );
      return res.json(rows.map(({ is_far, ...r }) => r));
    }

    const rows = await query(
      `SELECT id, hospital_name, hospital_code, email,
        ST_Y(location::geometry) as latitude,
        ST_X(location::geometry) as longitude
       FROM users
       WHERE account_type = 'hospital' AND hospital_verified = TRUE AND is_active = TRUE
       ORDER BY hospital_name ASC`,
    );
    return res.json(rows);
  } catch (err) {
    console.error('GET /hospitals', err);
    return res.status(500).json({ error: 'internal_error' });
  }
});

// ─── Blood requests ───────────────────────────────────────────────────────────
app.post('/api/v1/requests', requireFirebaseAuth, async (req, res) => {
  try {
    const b = req.body || {};
    const hospitalResult = await query(
      `SELECT hospital_code, hospital_name FROM users
       WHERE id = $1::uuid AND account_type = 'hospital'`,
      [b.hospitalId],
    );
    if (hospitalResult.length === 0) {
      return res.status(404).json({ error: 'hospital_not_found' });
    }
    const hospitalCode = hospitalResult[0].hospital_code;
    const hospitalName = hospitalResult[0].hospital_name;

    const shortIdResult = await query(
      'SELECT generate_short_request_id($1) as short_id',
      [hospitalCode],
    );
    const shortId = shortIdResult[0].short_id;

    const matchingLat = b.requesterLat ?? b.hospitalLat;
    const matchingLng = b.requesterLng ?? b.hospitalLng;

    const donorCountResult = await query(
      `SELECT COUNT(*)::int as donor_count FROM find_nearby_donors(
        $1::varchar(3),
        ST_SetSRID(ST_MakePoint($2::float8, $3::float8), 4326)::geography,
        120, 200)`,
      [b.bloodType, matchingLng, matchingLat],
    );
    const donorCount = donorCountResult[0]?.donor_count ?? 0;

    const hasRequesterLoc = b.requesterLat != null && b.requesterLng != null;
    const requesterLocSql = hasRequesterLoc
      ? 'ST_SetSRID(ST_MakePoint($14::float8, $15::float8), 4326)::geography'
      : 'NULL';

    const params = [
      shortId,
      b.requesterId,
      b.bloodType,
      b.unitsNeeded,
      b.urgencyLevel,
      b.hospitalId,
      hospitalName,
      b.hospitalLng,
      b.hospitalLat,
      b.patientName ?? null,
      b.description ?? null,
      b.contactPhone ?? null,
      donorCount,
    ];
    if (hasRequesterLoc) {
      params.push(b.requesterLng, b.requesterLat);
    }

    const requestResult = await query(
      `WITH new_request AS (
        INSERT INTO blood_requests (
          short_id, requester_id, blood_type, units_needed, urgency_level,
          hospital_id, hospital_name, hospital_location, requester_location,
          patient_name, description, contact_phone, status,
          nearby_donors_count, total_eligible_count, expires_at
        ) VALUES (
          $1, $2::uuid, $3, $4, $5, $6::uuid, $7,
          ST_SetSRID(ST_MakePoint($8::float8, $9::float8), 4326)::geography,
          ${requesterLocSql},
          $10, $11, $12, 'active', $13, $13, NOW() + INTERVAL '24 hours'
        )
        RETURNING *,
          ST_Y(hospital_location::geometry) as hospital_lat,
          ST_X(hospital_location::geometry) as hospital_lng,
          ST_Y(requester_location::geometry) as requester_lat,
          ST_X(requester_location::geometry) as requester_lng
      ),
      mark_recipient AS (
        UPDATE users SET is_recipient = TRUE, updated_at = NOW()
        WHERE id = $2::uuid RETURNING id
      )
      SELECT * FROM new_request`,
      params,
    );

    if (requestResult.length === 0) {
      return res.status(500).json({ error: 'insert_failed' });
    }

    const created = requestResult[0];

    try {
      await query(
        `INSERT INTO request_audit_log (request_id, event_type, detail, actor_user_id)
         VALUES ($1::uuid, 'created', $2, $3::uuid)`,
        [
          created.id,
          `Request opened; id=${created.short_id}`,
          b.requesterId,
        ],
      );
    } catch (auditErr) {
      console.warn('Audit log failed:', auditErr.message);
    }

    notifyNewRequest(created).catch((e) =>
      console.warn('Push notification failed:', e.message),
    );

    return res.status(201).json(created);
  } catch (err) {
    console.error('POST /requests', err);
    return res.status(500).json({ error: 'internal_error' });
  }
});

app.get('/api/v1/requests/active', requireFirebaseAuth, async (req, res) => {
  try {
    const userId = req.query.userId;
    const rows = await query(
      `SELECT id, short_id, requester_id, blood_type, units_needed, urgency_level,
        hospital_name, status, nearby_donors_count, total_eligible_count,
        created_at, expires_at,
        ST_Y(hospital_location::geometry) as hospital_lat,
        ST_X(hospital_location::geometry) as hospital_lng,
        ST_Y(requester_location::geometry) as requester_lat,
        ST_X(requester_location::geometry) as requester_lng
       FROM blood_requests
       WHERE requester_id = $1::uuid AND status IN ('active', 'in_progress')
       ORDER BY created_at DESC LIMIT 1`,
      [userId],
    );
    return res.json(rows[0] ?? null);
  } catch (err) {
    console.error('GET /requests/active', err);
    return res.status(500).json({ error: 'internal_error' });
  }
});

app.get('/api/v1/requests/mine', requireFirebaseAuth, async (req, res) => {
  try {
    const userId = req.query.userId;
    const rows = await query(
      `SELECT *,
        ST_Y(hospital_location::geometry) as hospital_lat,
        ST_X(hospital_location::geometry) as hospital_lng,
        ST_Y(requester_location::geometry) as requester_lat,
        ST_X(requester_location::geometry) as requester_lng
       FROM blood_requests WHERE requester_id = $1::uuid ORDER BY created_at DESC`,
      [userId],
    );
    return res.json(rows);
  } catch (err) {
    console.error('GET /requests/mine', err);
    return res.status(500).json({ error: 'internal_error' });
  }
});

app.patch('/api/v1/requests/:id', requireFirebaseAuth, async (req, res) => {
  try {
    const requestId = req.params.id;
    const { requesterId, unitsNeeded, urgencyLevel, description, contactPhone } =
      req.body || {};
    const sets = [];
    const params = [requestId, requesterId];
    let idx = 3;
    if (unitsNeeded != null) {
      sets.push(`units_needed = $${idx++}`);
      params.push(unitsNeeded);
    }
    if (urgencyLevel != null) {
      sets.push(`urgency_level = $${idx++}`);
      params.push(urgencyLevel);
    }
    if (description != null) {
      sets.push(`description = $${idx++}`);
      params.push(description);
    }
    if (contactPhone != null) {
      sets.push(`contact_phone = $${idx++}`);
      params.push(contactPhone);
    }
    if (sets.length === 0) return res.status(400).json({ error: 'nothing_to_update' });

    const result = await query(
      `UPDATE blood_requests SET ${sets.join(', ')}, updated_at = NOW()
       WHERE id = $1::uuid AND requester_id = $2::uuid AND status = 'active'
       RETURNING id`,
      params,
    );
    if (result.length === 0) {
      return res.status(409).json({ error: 'cannot_update' });
    }
    await query(
      `INSERT INTO request_audit_log (request_id, event_type, detail, actor_user_id)
       VALUES ($1::uuid, 'updated', 'Recipient updated request.', $2::uuid)`,
      [requestId, requesterId],
    ).catch(() => {});
    return res.status(204).send();
  } catch (err) {
    console.error('PATCH /requests/:id', err);
    return res.status(500).json({ error: 'internal_error' });
  }
});

app.post('/api/v1/requests/:id/cancel', requireFirebaseAuth, async (req, res) => {
  try {
    const { userId } = req.body || {};
    const result = await query(
      `WITH cancelled AS (
        UPDATE blood_requests SET status = 'cancelled', updated_at = NOW()
        WHERE id = $1::uuid AND requester_id = $2::uuid
          AND status IN ('active', 'in_progress')
        RETURNING id
      )
      UPDATE users SET is_recipient = FALSE, updated_at = NOW()
      WHERE id = $2::uuid AND EXISTS (SELECT 1 FROM cancelled)
      RETURNING id`,
      [req.params.id, userId],
    );
    if (result.length > 0) {
      await query(
        `INSERT INTO request_audit_log (request_id, event_type, detail, actor_user_id)
         VALUES ($1::uuid, 'cancelled', 'Recipient cancelled.', $2::uuid)`,
        [req.params.id, userId],
      ).catch(() => {});
    }
    return res.json({ ok: result.length > 0 });
  } catch (err) {
    console.error('POST /requests/:id/cancel', err);
    return res.status(500).json({ error: 'internal_error' });
  }
});

// ─── Donors ───────────────────────────────────────────────────────────────────
app.get('/api/v1/donor/matches', requireFirebaseAuth, async (req, res) => {
  try {
    const { donorId, compatibleTypesCsv, donorLat, donorLng, radiusKm } =
      req.query;
    const radiusM = parseInt(radiusKm || '120', 10) * 1000;
    const rows = await query(
      `SELECT br.id, br.short_id, br.requester_id, br.blood_type, br.units_needed,
        br.urgency_level, br.hospital_name,
        ST_Y(br.hospital_location::geometry) AS hospital_lat,
        ST_X(br.hospital_location::geometry) AS hospital_lng,
        ST_Y(br.requester_location::geometry) AS requester_lat,
        ST_X(br.requester_location::geometry) AS requester_lng,
        br.status, br.nearby_donors_count, br.total_eligible_count,
        br.created_at, br.expires_at,
        ROUND((ST_Distance(br.hospital_location,
          ST_SetSRID(ST_MakePoint($3::float8, $2::float8), 4326)::geography) / 1000)::numeric, 2) AS distance_km
       FROM blood_requests br
       WHERE br.status = 'active' AND br.expires_at > NOW()
         AND UPPER(br.blood_type) = ANY(
           SELECT UPPER(v) FROM unnest(string_to_array($4, ',')) AS v)
         AND br.hospital_location IS NOT NULL
         AND ST_Distance(br.hospital_location,
           ST_SetSRID(ST_MakePoint($3::float8, $2::float8), 4326)::geography) <= $5::float8
         AND NOT EXISTS (
           SELECT 1 FROM donor_responses dr
           WHERE dr.request_id = br.id AND dr.donor_id = $1::uuid)
       ORDER BY CASE br.urgency_level WHEN 'critical' THEN 1 WHEN 'urgent' THEN 2 ELSE 3 END,
         br.created_at DESC LIMIT 50`,
      [donorId, donorLat, donorLng, compatibleTypesCsv, radiusM],
    );
    return res.json(rows);
  } catch (err) {
    console.error('GET /donor/matches', err);
    return res.status(500).json({ error: 'internal_error' });
  }
});

app.post('/api/v1/donor/responses/accept', requireFirebaseAuth, async (req, res) => {
  try {
    const { requestId, donorId, donorLat, donorLng } = req.body || {};
    await query(
      `WITH locked AS (
        SELECT id, status FROM blood_requests WHERE id = $1::uuid FOR UPDATE
      ),
      accepted AS (
        INSERT INTO donor_responses (request_id, donor_id, response_type, distance_km)
        SELECT $1::uuid, $2::uuid, 'accepted',
          ROUND((ST_Distance(
            (SELECT hospital_location FROM blood_requests WHERE id = $1::uuid),
            ST_SetSRID(ST_MakePoint($4::float8, $3::float8), 4326)::geography
          ) / 1000)::numeric, 2)
        FROM locked WHERE status = 'active' RETURNING id
      )
      UPDATE blood_requests br SET status = 'in_progress', updated_at = NOW()
      FROM locked, accepted
      WHERE br.id = $1::uuid AND locked.status = 'active'`,
      [requestId, donorId, donorLat, donorLng],
    );

    const check = await query(
      `SELECT response_type FROM donor_responses
       WHERE request_id = $1::uuid AND donor_id = $2::uuid`,
      [requestId, donorId],
    );
    if (check.length === 0 || check[0].response_type !== 'accepted') {
      return res.status(409).json({ error: 'accept_failed' });
    }
    const statusCheck = await query(
      'SELECT status FROM blood_requests WHERE id = $1::uuid',
      [requestId],
    );
    if (statusCheck.length === 0 || statusCheck[0].status !== 'in_progress') {
      return res.status(409).json({ error: 'accept_failed' });
    }
    await query(
      `INSERT INTO request_audit_log (request_id, event_type, detail, actor_user_id)
       VALUES ($1::uuid, 'donor_accepted', $2, $3::uuid)`,
      [requestId, `Atomic assignment to donor ${donorId}.`, donorId],
    ).catch(() => {});
    return res.status(204).send();
  } catch (err) {
    const msg = String(err);
    if (msg.includes('23505') || msg.includes('unique')) {
      return res.status(409).json({ error: 'already_accepted' });
    }
    console.error('POST /donor/responses/accept', err);
    return res.status(500).json({ error: 'internal_error' });
  }
});

app.post('/api/v1/donor/responses/decline', requireFirebaseAuth, async (req, res) => {
  try {
    const { requestId, donorId } = req.body || {};
    await query(
      `INSERT INTO donor_responses (request_id, donor_id, response_type)
       VALUES ($1::uuid, $2::uuid, 'declined')
       ON CONFLICT (request_id, donor_id) DO UPDATE
       SET response_type = 'declined', updated_at = NOW()`,
      [requestId, donorId],
    );
    return res.status(204).send();
  } catch (err) {
    console.error('POST /donor/responses/decline', err);
    return res.status(500).json({ error: 'internal_error' });
  }
});

app.post('/api/v1/donor/responses/withdraw', requireFirebaseAuth, async (req, res) => {
  try {
    const { requestId, donorId } = req.body || {};
    const result = await query(
      `WITH withdrawn AS (
        UPDATE donor_responses SET response_type = 'declined', updated_at = NOW()
        WHERE request_id = $1::uuid AND donor_id = $2::uuid AND response_type = 'accepted'
        RETURNING id
      )
      UPDATE blood_requests SET status = 'active', updated_at = NOW()
      FROM withdrawn WHERE id = $1::uuid AND status = 'in_progress'
      RETURNING id`,
      [requestId, donorId],
    );
    if (result.length === 0) {
      return res.status(409).json({ error: 'withdraw_failed' });
    }
    await query(
      `INSERT INTO request_audit_log (request_id, event_type, detail, actor_user_id)
       VALUES ($1::uuid, 'donor_withdrew', 'Donor withdrew acceptance.', $2::uuid)`,
      [requestId, donorId],
    ).catch(() => {});
    return res.status(204).send();
  } catch (err) {
    console.error('POST /donor/responses/withdraw', err);
    return res.status(500).json({ error: 'internal_error' });
  }
});

app.get('/api/v1/donor/mission', requireFirebaseAuth, async (req, res) => {
  try {
    const { donorId } = req.query;
    const rows = await query(
      `SELECT br.id, br.short_id, br.requester_id, br.blood_type, br.units_needed,
        br.urgency_level, br.hospital_name,
        ST_Y(br.hospital_location::geometry) AS hospital_lat,
        ST_X(br.hospital_location::geometry) AS hospital_lng,
        ST_Y(br.requester_location::geometry) AS requester_lat,
        ST_X(br.requester_location::geometry) AS requester_lng,
        br.status, br.nearby_donors_count, br.total_eligible_count,
        br.created_at, br.expires_at
       FROM blood_requests br
       INNER JOIN donor_responses dr ON dr.request_id = br.id AND dr.donor_id = $1::uuid
       WHERE dr.response_type = 'accepted' AND br.status IN ('active', 'in_progress')
       ORDER BY br.created_at DESC LIMIT 1`,
      [donorId],
    );
    return res.json(rows[0] ?? null);
  } catch (err) {
    console.error('GET /donor/mission', err);
    return res.status(500).json({ error: 'internal_error' });
  }
});

app.get('/api/v1/donor/responses/history', requireFirebaseAuth, async (req, res) => {
  try {
    const { donorId } = req.query;
    const rows = await query(
      `SELECT br.id AS request_id, br.short_id, br.hospital_name, br.blood_type,
              dr.response_type, dr.responded_at
       FROM donor_responses dr
       LEFT JOIN blood_requests br ON br.id = dr.request_id
       WHERE dr.donor_id = $1::uuid ORDER BY dr.responded_at DESC`,
      [donorId],
    );
    return res.json(rows);
  } catch (err) {
    return res.json([]);
  }
});

app.get('/api/v1/donor/stats', requireFirebaseAuth, async (req, res) => {
  try {
    const { donorId } = req.query;
    const rows = await query(
      'SELECT total_donations, reward_points FROM users WHERE id = $1::uuid',
      [donorId],
    );
    if (rows.length === 0) {
      return res.json({ totalDonations: 0, rewardPoints: 0 });
    }
    return res.json({
      totalDonations: rows[0].total_donations ?? 0,
      rewardPoints: rows[0].reward_points ?? 0,
    });
  } catch (err) {
    return res.json({ totalDonations: 0, rewardPoints: 0 });
  }
});

app.get('/api/v1/donor/donations', requireFirebaseAuth, async (req, res) => {
  try {
    const { donorId } = req.query;
    const rows = await query(
      `SELECT d.id, d.donation_date, d.units_donated, br.blood_type, br.short_id,
              br.urgency_level, u.hospital_name,
              CASE br.urgency_level WHEN 'critical' THEN 30 WHEN 'urgent' THEN 20 ELSE 10 END AS points_earned
       FROM donations d
       LEFT JOIN blood_requests br ON br.id = d.request_id
       LEFT JOIN users u ON u.id = d.verified_by_hospital_id
       WHERE d.donor_id = $1::uuid ORDER BY d.donation_date DESC`,
      [donorId],
    );
    return res.json(rows);
  } catch (err) {
    return res.json([]);
  }
});

app.get('/api/v1/donor/leaderboard', requireFirebaseAuth, async (req, res) => {
  try {
    const limit = parseInt(req.query.limit || '20', 10);
    const rows = await query(
      `SELECT u.id, u.name, u.blood_type, u.total_donations, u.reward_points,
              RANK() OVER (ORDER BY u.reward_points DESC) AS rank
       FROM users u WHERE u.role = 'donor' AND u.total_donations > 0
       ORDER BY u.reward_points DESC LIMIT $1`,
      [limit],
    );
    return res.json(rows);
  } catch (err) {
    return res.json([]);
  }
});

app.get('/api/v1/donor/rank', requireFirebaseAuth, async (req, res) => {
  try {
    const { userId } = req.query;
    const rows = await query(
      `SELECT rank FROM (
        SELECT id, RANK() OVER (ORDER BY reward_points DESC) AS rank
        FROM users WHERE role = 'donor'
      ) r WHERE id = $1::uuid`,
      [userId],
    );
    return res.json({ rank: rows[0]?.rank ?? null });
  } catch (err) {
    return res.json({ rank: null });
  }
});

// ─── Hospital admin ───────────────────────────────────────────────────────────
function normalizeFourDigitCode(raw) {
  const digits = String(raw).replace(/\D/g, '');
  if (!digits) return '';
  const tail = digits.length > 4 ? digits.slice(-4) : digits;
  return tail.padStart(4, '0');
}

app.get('/api/v1/hospital/search', requireFirebaseAuth, async (req, res) => {
  try {
    const code = normalizeFourDigitCode(req.query.code || '');
    if (code.length !== 4) return res.json([]);
    const rows = await query(
      `SELECT br.id, br.short_id, br.requester_id, br.blood_type, br.units_needed,
        br.urgency_level, br.hospital_name,
        ST_Y(br.hospital_location::geometry) AS hospital_lat,
        ST_X(br.hospital_location::geometry) AS hospital_lng,
        ST_Y(br.requester_location::geometry) AS requester_lat,
        ST_X(br.requester_location::geometry) AS requester_lng,
        br.status, br.nearby_donors_count, br.total_eligible_count,
        br.created_at, br.expires_at,
        u.name AS donor_name, u.phone AS donor_phone
       FROM blood_requests br
       LEFT JOIN donor_responses dr ON dr.request_id = br.id AND dr.response_type = 'accepted'
       LEFT JOIN users u ON u.id = dr.donor_id
       WHERE br.hospital_id = $1::uuid AND RIGHT(br.short_id, 4) = $2
         AND br.status IN ('active', 'in_progress')
       ORDER BY br.created_at DESC`,
      [req.query.hospitalUserId, code],
    );
    return res.json(
      rows.map((row) => ({
        request: row,
        donorName: row.donor_name || null,
        donorPhone: row.donor_phone || null,
      })),
    );
  } catch (err) {
    console.error('GET /hospital/search', err);
    return res.status(500).json({ error: 'internal_error' });
  }
});

app.post('/api/v1/hospital/verify', requireFirebaseAuth, async (req, res) => {
  try {
    const { hospitalUserId, requestId, staffName } = req.body || {};
    const rows = await query(
      `SELECT success, error_message FROM verify_request_donation($1::uuid, $2::uuid, $3)`,
      [requestId, hospitalUserId, staffName ?? null],
    );
    if (rows.length === 0) {
      return res.json({
        error:
          'Run database/mvp_incremental.sql on Supabase (verify_request_donation).',
      });
    }
    if (rows[0].success === true) return res.json({ error: null });
    return res.json({ error: rows[0].error_message || 'Verification failed' });
  } catch (err) {
    console.error('POST /hospital/verify', err);
    return res.status(500).json({ error: 'internal_error' });
  }
});

app.get('/api/v1/hospital/requests/:id/audit', requireFirebaseAuth, async (req, res) => {
  try {
    const rows = await query(
      `SELECT event_type, detail, created_at FROM request_audit_log
       WHERE request_id = $1::uuid ORDER BY created_at ASC`,
      [req.params.id],
    );
    return res.json(rows);
  } catch (err) {
    return res.json([]);
  }
});

app.get('/api/v1/hospital/inventory', requireFirebaseAuth, async (req, res) => {
  try {
    const { hospitalId } = req.query;
    const rows = await query(
      `SELECT blood_type, units_available, minimum_threshold,
              units_available < minimum_threshold AS is_low, last_updated
       FROM hospital_inventory WHERE hospital_id = $1::uuid ORDER BY blood_type`,
      [hospitalId],
    );
    return res.json(rows);
  } catch (err) {
    return res.json([]);
  }
});

app.get('/api/v1/hospital/stats', requireFirebaseAuth, async (req, res) => {
  try {
    const { hospitalId } = req.query;
    const rows = await query(
      `SELECT
        COUNT(*) FILTER (WHERE status = 'in_progress') AS pending,
        COUNT(*) FILTER (WHERE status = 'fulfilled' AND DATE(fulfilled_at) = CURRENT_DATE) AS today,
        COUNT(*) FILTER (WHERE status = 'fulfilled') AS fulfilled_total
       FROM blood_requests WHERE hospital_id = $1::uuid`,
      [hospitalId],
    );
    if (rows.length === 0) {
      return res.json({ pending: 0, today: 0, fulfilled: 0 });
    }
    return res.json({
      pending: rows[0].pending ?? 0,
      today: rows[0].today ?? 0,
      fulfilled: rows[0].fulfilled_total ?? 0,
    });
  } catch (err) {
    return res.json({ pending: 0, today: 0, fulfilled: 0 });
  }
});

app.get('/api/v1/hospital/pending', requireFirebaseAuth, async (req, res) => {
  try {
    const { hospitalId } = req.query;
    const rows = await query(
      `SELECT br.id, br.short_id, br.blood_type, br.urgency_level, br.status,
        br.units_needed, br.created_at, br.expires_at,
        COALESCE(u_req.name, 'Direct Request') AS requester_name,
        u_req.phone AS requester_phone,
        d.name AS donor_name, d.blood_type AS donor_blood_type, d.phone AS donor_phone,
        RIGHT(br.short_id, 4) AS display_code
       FROM blood_requests br
       LEFT JOIN users u_req ON u_req.id = br.requester_id
       LEFT JOIN donor_responses dr ON dr.request_id = br.id AND dr.response_type = 'accepted'
       LEFT JOIN users d ON d.id = dr.donor_id
       WHERE br.hospital_id = $1::uuid AND br.status IN ('active', 'in_progress')
       ORDER BY CASE br.urgency_level WHEN 'critical' THEN 1 WHEN 'urgent' THEN 2 ELSE 3 END,
         br.created_at DESC`,
      [hospitalId],
    );
    return res.json(rows);
  } catch (err) {
    return res.json([]);
  }
});

// ─── Push notifications (server-side donor query) ─────────────────────────────
const DONOR_TYPES_MAP = {
  'O-': ['O-'],
  'O+': ['O-', 'O+'],
  'A-': ['O-', 'A-'],
  'A+': ['O-', 'O+', 'A-', 'A+'],
  'B-': ['O-', 'B-'],
  'B+': ['O-', 'O+', 'B-', 'B+'],
  'AB-': ['O-', 'A-', 'B-', 'AB-'],
  'AB+': ['O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+'],
};

async function notifyNewRequest(request) {
  const backendUrl = process.env.NOTIFICATION_BACKEND_URL;
  const secret = process.env.NOTIFICATION_BACKEND_SECRET;
  if (!backendUrl || !secret) return;

  const bloodType = request.blood_type;
  const donorTypes = DONOR_TYPES_MAP[bloodType] || [bloodType];
  if (donorTypes.length === 0) return;

  const hospitalLat = request.hospital_lat;
  const hospitalLng = request.hospital_lng;
  if (hospitalLat == null || hospitalLng == null) return;

  const donors = await query(
    `SELECT DISTINCT u.fcm_token FROM users u
     WHERE u.fcm_token IS NOT NULL AND u.account_type = 'regular'
       AND u.role = 'donor' AND u.donor_status = 'available' AND u.is_active = TRUE
       AND u.notification_enabled = TRUE AND u.location IS NOT NULL
       AND u.blood_type = ANY(string_to_array($1, ',')::varchar[])
       AND ST_DWithin(u.location,
         ST_SetSRID(ST_MakePoint($3::float8, $2::float8), 4326)::geography,
         (GREATEST(COALESCE(u.notification_radius_km, 50), 10) * 1000)::double precision)`,
    [donorTypes.join(','), hospitalLat, hospitalLng],
  );

  const tokens = donors
    .map((r) => r.fcm_token)
    .filter((t) => t && String(t).length > 0);
  if (tokens.length === 0) return;

  const url = new URL('/sendNewRequest', backendUrl.replace(/\/$/, ''));
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-internal-secret': secret,
    },
    body: JSON.stringify({
      request: {
        id: request.id,
        short_id: request.short_id,
        blood_type: request.blood_type,
        units_needed: request.units_needed,
        hospital_name: request.hospital_name,
      },
      tokens,
    }),
  });

  if (response.ok) {
    const body = await response.json();
    const stale = body.stale_tokens;
    if (Array.isArray(stale) && stale.length > 0) {
      await query(
        'UPDATE users SET fcm_token = NULL WHERE fcm_token = ANY($1::text[])',
        [stale],
      );
    }
  }
}

// ─── Start server ─────────────────────────────────────────────────────────────
async function startServer() {
  const dbConfig = validateDbConfig();
  if (!dbConfig.ok) {
    console.error(`
╔══════════════════════════════════════════════════════════════════╗
║  Supabase database credentials missing in api-backend/.env       ║
╠══════════════════════════════════════════════════════════════════╣
║  Set SUPABASE_HOST, SUPABASE_USERNAME, SUPABASE_DB_PASSWORD        ║
║  (or DATABASE_URL from Supabase → Settings → Database)             ║
║  Copy from your old repo-root .env if you used direct Postgres.    ║
╚══════════════════════════════════════════════════════════════════╝
Missing: ${dbConfig.missing.join(', ')}
`);
    process.exit(1);
  }

  try {
    await testConnection();
    console.log(`Database connected (${dbConfig.mode})`);
  } catch (err) {
    console.error('Database connection failed:', err.message);
    console.error(
      'Check Supabase host/port (pooler: port 5432 or 6543), password, and SSL settings.',
    );
    process.exit(1);
  }

  const port = parseInt(process.env.PORT || '8090', 10);
  const useTls =
    isProduction &&
    process.env.TLS_KEY_PATH &&
    process.env.TLS_CERT_PATH;

  if (useTls) {
  const fs = require('fs');
  const https = require('https');
  const options = {
    key: fs.readFileSync(process.env.TLS_KEY_PATH),
    cert: fs.readFileSync(process.env.TLS_CERT_PATH),
  };
    https.createServer(options, app).listen(port, '0.0.0.0', () => {
      console.log(`BloodConnect API listening on HTTPS port ${port} (0.0.0.0)`);
    });
  } else {
    const http = require('http');
    http.createServer(app).listen(port, '0.0.0.0', () => {
      console.log(
        `BloodConnect API listening on HTTP port ${port} (0.0.0.0 — reachable from emulators/LAN)${isProduction ? ' (set TLS_KEY_PATH/TLS_CERT_PATH or terminate TLS at proxy)' : ''}`,
      );
    });
  }
}

if (process.env.NODE_ENV !== 'test') {
  startServer();
}

module.exports = app;
