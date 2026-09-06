# Configuration

Happy Wakey uses compile-time Dart defines so no `.env` parser or plaintext
credential file is needed in the application bundle.

| Define | Purpose | Required |
| --- | --- | --- |
| `SUPABASE_URL` | Supabase project URL for OAuth and optional config sync | No |
| `SUPABASE_ANON_KEY` | Supabase publishable/anonymous client key | No |
| `FINNHUB_API_KEY` | Direct Finnhub development access | No |
| `NEWS_API_KEY` | Direct NewsAPI development access | No |
| `HAPPY_WAKEY_PLATFORM_URL` | Fallback base for shared auth, reminder, and direct-message gateway calls. No default; fail-closed when unset. HTTPS hostname only (loopback HTTP allowed). | Cloud reminders or direct messages |
| `HAPPY_WAKEY_SHARED_AUTH_URL` | Optional dedicated shared-auth base URL | No |
| `HAPPY_WAKEY_GATEWAY_URL` | Optional dedicated reminder/direct-message gateway base URL | No |

Both Supabase values must be present to enable identity. Add
`com.happywakey.app://login-callback` to the project's allowed redirect URLs.
Web OAuth returns to the current web origin instead, which must also be allowed.

Google login requests `calendar.readonly` and `gmail.readonly`; Microsoft login
requests `Calendars.Read` and `Mail.Read`; Apple login supplies identity but
not Apple Calendar or mail access. Mail is read-only and bounded to recent
unread messages; the app never marks, moves, deletes, or sends mail.

The direct-message gateway is intentionally server-mediated. It should perform
provider OAuth and consent for Slack, Discord, Teams, or other approved sources,
then expose the bounded read-only response at
`GET /v1/briefing/direct-messages` with the user's Supabase bearer. The Flutter
client never receives provider tokens and treats links as untrusted until they
pass the same HTTP(S)-only URL guard.

On iOS, HealthKit requires the checked-in HealthKit capability and iOS 15 or
later. On Android, Health Connect permissions are requested at runtime. Health
results are aggregated locally for the morning brief; raw records are not
persisted or synchronized.

The app stores weather coordinates, watchlist symbols, news keywords,
bookmarks, reminder preferences, planner tasks, focus duration, and onboarding
progress. It does not put OAuth sessions, provider tokens, API keys, or shared
auth tokens into that document.

## Production key policy

Dart defines are build configuration, not secret storage. Values can be
recovered from client binaries and are plainly observable in web builds. Use
direct Finnhub and NewsAPI keys only when their account and origin policies make
that acceptable. A production deployment should expose a narrow backend API
that enforces authentication, rate limits, response bounds, and provider terms.
