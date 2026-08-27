# Configuration

Happy Wakey uses compile-time Dart defines so no `.env` parser or plaintext
credential file is needed in the application bundle.

| Define | Purpose | Required |
| --- | --- | --- |
| `SUPABASE_URL` | Supabase project URL for OAuth and optional config sync | No |
| `SUPABASE_ANON_KEY` | Supabase publishable/anonymous client key | No |
| `FINNHUB_API_KEY` | Direct Finnhub development access | No |
| `NEWS_API_KEY` | Direct NewsAPI development access | No |
| `HAPPY_WAKEY_PLATFORM_URL` | Fallback base for shared auth and reminder gateway. No default; fail-closed when unset. HTTPS hostname only (loopback HTTP allowed). | Cloud reminders only |
| `HAPPY_WAKEY_SHARED_AUTH_URL` | Optional dedicated shared-auth base URL | No |
| `HAPPY_WAKEY_GATEWAY_URL` | Optional dedicated reminder-gateway base URL | No |

Both Supabase values must be present to enable identity. Add
`com.happywakey.app://login-callback` to the project's allowed redirect URLs.
Web OAuth returns to the current web origin instead, which must also be allowed.

Google login requests `calendar.readonly`; Microsoft login requests
`Calendars.Read`; Apple login supplies identity but not Apple Calendar access.

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
