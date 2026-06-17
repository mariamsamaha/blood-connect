# UX testing guide

## Scope

UX testing covers the Flutter mobile app: donor registration, request creation, matching, and hospital verification flows.

## Test environments

| Environment | URL / Build | Data |
|-------------|-------------|------|
| Local dev | `flutter run` | Local Supabase or staging DB |
| Staging | CI build → staging deployment | Anonymized test data |
| Production | CI build → production | Real data (read-only where possible) |

## Test scenarios

### Onboarding & authentication

- [ ] First-time user registration (Donor, Recipient, Hospital roles)
- [ ] Login / logout with email + password
- [ ] Password reset flow
- [ ] Session persistence across app restarts
- [ ] Role-based navigation: donor sees different screens than hospital

### Blood request flow (Recipient)

- [ ] Create a blood request (select blood type, urgency, hospital)
- [ ] View active requests
- [ ] Cancel a request
- [ ] Receive push notification when a donor accepts

### Donor matching

- [ ] Receive push notification for nearby requests
- [ ] View request details on the map
- [ ] Accept / decline a request
- [ ] Navigate to hospital location
- [ ] Mark donation as completed

### Hospital verification

- [ ] View incoming donation records
- [ ] Verify a donation (mark as confirmed)
- [ ] View donation history

### AI screening (if enabled)

- [ ] Upload CBC report image
- [ ] View prediction result (Normal / Abnormal / Needs Review)
- [ ] View bilingual explanation (English + Arabic)
- [ ] Chat with AI assistant about results

## Metrics to capture

- **Task completion rate**: % of users who complete each flow
- **Time on task**: average time to complete each flow
- **Error rate**: % of flows where the user gets stuck or hits an error
- **Satisfaction**: post-test SUS (System Usability Scale) score
- **AI prediction accuracy**: user-reported feedback vs AI result

## Testing tools

| Tool | Purpose |
|------|---------|
| Firebase Crashlytics | Crash monitoring |
| Sentry / LogRocket | Session replay, error tracking |
| In-app feedback form | Qualitative user feedback |
| Google Forms / Typeform | SUS survey after test sessions |

## Known UX limitations

- AI service has a cold start (~15s) on first request after idle
- CBC image upload requires good lighting and focus
- RTL (Arabic) support is functional but some third-party widgets may have gaps
- Push notifications may be delayed on iOS if the app is in background
