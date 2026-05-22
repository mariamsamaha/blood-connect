const swaggerJsdoc = require('swagger-jsdoc');

const options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'BloodConnect API',
      version: '1.0.0',
      description: 'REST API BFF for the BloodConnect blood donation platform. All authenticated endpoints require a Firebase ID token in the `Authorization: Bearer <token>` header.',
      contact: {
        name: 'BloodConnect Team',
      },
    },
    servers: [
      { url: 'http://localhost:8090', description: 'Local development' },
      { url: 'https://api.bloodconnect.app', description: 'Production' },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
          description: 'Firebase ID token (obtained via Firebase Auth SDK)',
        },
      },
      schemas: {
        Error: {
          type: 'object',
          properties: {
            error: { type: 'string', example: 'internal_error' },
            detail: { type: 'string', example: 'Cannot read properties of undefined' },
            requestId: { type: 'string', example: 'uuid' },
          },
        },
        HealthResponse: {
          type: 'object',
          properties: {
            status: { type: 'string', example: 'ok' },
            service: { type: 'string', example: 'bloodconnect-api' },
          },
        },
        DbHealthResponse: {
          type: 'object',
          properties: {
            status: { type: 'string', example: 'ok' },
            latency_ms: { type: 'integer' },
            pool: {
              type: 'object',
              properties: {
                total: { type: 'integer' },
                idle: { type: 'integer' },
                waiting: { type: 'integer' },
              },
            },
            uptime_s: { type: 'integer' },
          },
        },
        UserProfile: {
          type: 'object',
          properties: {
            id: { type: 'string', format: 'uuid' },
            firebase_uid: { type: 'string' },
            email: { type: 'string', format: 'email' },
            name: { type: 'string' },
            phone: { type: 'string' },
            blood_type: { type: 'string', enum: ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'] },
            role: { type: 'string', enum: ['donor', 'recipient', 'hospital'] },
            latitude: { type: 'number' },
            longitude: { type: 'number' },
          },
        },
        BloodRequest: {
          type: 'object',
          properties: {
            id: { type: 'string', format: 'uuid' },
            short_id: { type: 'string' },
            blood_type: { type: 'string' },
            units_needed: { type: 'integer' },
            urgency_level: { type: 'string', enum: ['routine', 'urgent', 'critical'] },
            status: { type: 'string', enum: ['active', 'in_progress', 'fulfilled', 'cancelled'] },
            hospital_name: { type: 'string' },
            created_at: { type: 'string', format: 'date-time' },
          },
        },
      },
    },
    paths: {},
  },
  apis: ['./src/server.js'],
};

module.exports = swaggerJsdoc(options);
