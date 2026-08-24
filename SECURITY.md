# Security

Please report suspected vulnerabilities privately through the GitHub repository
security-advisory form. Do not include credentials, session tokens, private user
data, or exploitable details in a public issue.

Happy Wakey is a client application. Supabase row-level security, OAuth redirect
allowlists, API-provider policy, shared-auth validation, and reminder-gateway
authorization are part of the deployed system's security boundary and must be
reviewed separately from this repository's client-state proof.

Dart defines are compiled into client artifacts and are not secret storage. Do
not ship privileged API keys in a mobile, desktop, or web build.
