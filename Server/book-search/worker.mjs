// The Kakao key is a Cloudflare secret, never part of the iOS bundle.
const json = (body, status = 200, extra = {}) => new Response(JSON.stringify(body), {
  status,
  headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff', ...extra },
});
const failure = (code, status) => json({ error: code }, status);
const text = value => typeof value === 'string' ? value : '';
function httpsURL(value) {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && !url.username && !url.password ? url.href : '';
  } catch { return ''; }
}

export async function handleRequest(request, env, upstream = (...args) => globalThis.fetch(...args)) {
  const url = new URL(request.url);
  if (url.pathname !== '/books') return failure('not_found', 404);
  if (request.method !== 'GET') return json({ error: 'method_not_allowed' }, 405, { Allow: 'GET' });
  const query = (url.searchParams.get('query') || '').trim();
  const page = url.searchParams.get('page') || '1';
  if (!query || query.length > 200 || /[\u0000-\u001f]/.test(query)
      || !/^[1-9][0-9]?$/.test(page) || Number(page) > 50
      || [...url.searchParams.keys()].some(key => !['query', 'page'].includes(key))) {
    return failure('invalid_request', 400);
  }
  // Fail closed if deployment is missing its abuse protection or credentials.
  if (!env.KAKAO_REST_API_KEY || !env.SEARCH_LIMITER) return failure('configuration_missing', 503);
  let stage = 'rate_limit';
  try {
    // IP-based throttling is a coarse anonymous abuse safeguard, not authentication.
    // Shared networks can share the limit; counters are per Cloudflare location.
    const ip = request.headers.get('CF-Connecting-IP');
    if (!ip) return failure('unavailable', 503);
    const { success } = await env.SEARCH_LIMITER.limit({ key: ip });
    if (!success) return json({ error: 'rate_limited' }, 429, { 'Retry-After': '60' });
    stage = 'upstream_connection';
    const target = new URL('https://dapi.kakao.com/v3/search/book');
    const isbn = query.replace(/[\s-]/g, '');
    target.searchParams.set('query', /^(\d{13}|\d{9}[\dXx])$/.test(isbn) ? isbn : query);
    if (/^(\d{13}|\d{9}[\dXx])$/.test(isbn)) target.searchParams.set('target', 'isbn');
    target.searchParams.set('page', page);
    target.searchParams.set('size', '20');
    const response = await upstream(target, {
      headers: { Authorization: `KakaoAK ${env.KAKAO_REST_API_KEY}` },
      signal: AbortSignal.timeout(8000), redirect: 'manual',
    });
    if (response.status === 429) return json({ error: 'rate_limited' }, 429, { 'Retry-After': '60' });
    if (response.status === 401 || response.status === 403) return failure('provider_authentication', 503);
    if (!response.ok) return failure('provider_unavailable', 503);
    stage = 'upstream_response';
    const data = await response.json();
    if (!Array.isArray(data.documents) || typeof data.meta?.is_end !== 'boolean') {
      return failure('invalid_response', 502);
    }
    return json({
      books: data.documents.slice(0, 20).map(book => ({
        title: text(book.title), authors: Array.isArray(book.authors) ? book.authors.filter(a => typeof a === 'string') : [],
        publisher: text(book.publisher), isbn: text(book.isbn),
        thumbnail: httpsURL(book.thumbnail), url: httpsURL(book.url),
      })),
      isEnd: data.meta.is_end,
    });
  } catch {
    // Do not log queries, credentials, upstream responses, or exception messages.
    return failure(`${stage}_failed`, 503);
  }
}

export default { fetch: (request, env) => handleRequest(request, env) };
