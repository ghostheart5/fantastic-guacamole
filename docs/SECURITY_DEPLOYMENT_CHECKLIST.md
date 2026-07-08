# Security deployment checklist

Repository safeguards cannot configure external consoles. Before production:

- Restrict Firebase API keys to the exact Android package and release SHA-256,
  Apple bundle IDs, approved web origins, and required Firebase APIs only.
- Rotation runbook after any leak:
  1) Rotate Android upload keystore password/key password and regenerate local
     `android/key.properties` outside version control.
  2) Rotate any backend provider key (Anthropic, service-role keys, etc.) and
     redeploy functions.
  3) Invalidate old CI secrets and re-add fresh values in repository secrets.
  4) Verify no leaked artifacts remain in tracked files or release bundles.
- Enable Firebase App Check for supported products.
- Firebase console hardening runbook:
  1) Android key: restrict by Android app package + SHA-256 fingerprint.
  2) iOS key: restrict by iOS bundle identifier.
  3) Web key: restrict by allowed HTTPS referrers only.
  4) API restrictions: allow only required Firebase/Google APIs.
  5) Enable usage alerts and quota anomaly monitoring for all keys.
- Apply all Supabase migrations before deploying functions.
- Deploy Edge Functions with JWT verification enabled.
- Configure `ALLOWED_ORIGINS`, `ANDROID_PACKAGE_NAME`, `ANTHROPIC_API_KEY`, and
  `GOOGLE_SERVICE_ACCOUNT_JSON` as server-side secrets or environment values.
- Keep `SUPABASE_SERVICE_ROLE_KEY` server-side only.
- Configure the OAuth redirect allow-list with
  `https://chronospark.app/app/auth/callback`.
- Verify `assetlinks.json` and Apple associated-domain files against the
  production signing identities.
- Rotate any credential discovered in historical diagnostic archives and
  purge those archives from published Git history.
