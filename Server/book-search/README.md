# Book search proxy

Status (2026-10-24): deployed to production. Live title search (미움받을 용기)
and ISBN search (9788996991342) returned HTTP 200. iOS Add Book now includes catalog
search, pagination, selection, metadata autofill and manual-entry fallback. The iOS
bundle contains only the public proxy URL, not the Kakao secret.
Production endpoint: https://ggotgalpi-book-search.rinarocketpunch.workers.dev/books

Cloudflare Worker `ggotgalpi-book-search` serves `GET /books?query=...&page=1`.
Returns `{ books: [{title, authors, publisher, isbn, thumbnail, url}], isEnd }`.
Set `KAKAO_REST_API_KEY` as an encrypted Worker secret in the dashboard, never in source.
Deploy this directory with Wrangler after account authorization. `keep_vars` preserves
dashboard variables; existing secrets are retained by Wrangler. Confirm the production
secret exists and rate limiter binding is deployed before testing.

Tests: `node --test worker.test.mjs` (Node 22+). Tests use mock responses, not the live key.

The rate limit is 60 requests/minute/IP/location, a coarse safeguard, not app authentication
or a globally accurate daily quota. Shared mobile networks can share this limit.
Kakao's free quota can still be exhausted by distributed abuse. Do not enable paid API
overages. Consider App Attest and a global quota gate before substantial public traffic.
Missing rate-limit configuration fails closed (503), rather than exposing an unlimited proxy.

No search result persistence, query logging, review upload, or key logging is implemented.
Observability is disabled in deployment config to avoid storing search URLs in invocation logs.
Cloudflare and Kakao still process requests; update the app privacy policy before release.
Only HTTPS cover/detail URLs are returned. Metadata storage/cover reuse rights and source
attribution must be checked before release; API availability alone does not grant all reuse rights.
