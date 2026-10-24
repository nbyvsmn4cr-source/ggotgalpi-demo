import { test } from 'node:test';
import assert from 'node:assert/strict';
import { handleRequest } from './worker.mjs';

const env = { KAKAO_REST_API_KEY: 'test-only', SEARCH_LIMITER: { limit: async () => ({ success: true }) } };
const request = (path = '/books?query=test', method = 'GET') => new Request(`https://example.com${path}`, { method, headers: { 'CF-Connecting-IP': '192.0.2.1' } });
const neverFetch = () => { throw new Error('Must not call upstream'); };

test('rejects bad routes, methods and query parameters before upstream', async () => {
  for (const [path, method, status] of [['/', 'GET', 404], ['/books', 'POST', 405], ['/books', 'GET', 400],
    ['/books?query=test&page=51', 'GET', 400], ['/books?query=test&url=https://example.org', 'GET', 400]]) {
    assert.equal((await handleRequest(request(path, method), env, neverFetch)).status, status);
  }
});
test('missing secret or limiter fails closed', async () => {
  assert.equal((await handleRequest(request(), {}, neverFetch)).status, 503);
  assert.equal((await handleRequest(request(), { KAKAO_REST_API_KEY: 'test' }, neverFetch)).status, 503);
});
test('rate limited requests do not reach Kakao', async () => {
  const response = await handleRequest(request(), { ...env, SEARCH_LIMITER: { limit: async () => ({ success: false }) } }, neverFetch);
  assert.equal(response.status, 429);
  assert.equal(response.headers.get('Retry-After'), '60');
});
test('searches ISBN and only returns allowed fields', async () => {
  const response = await handleRequest(request('/books?query=978-8996991342'), env, async (url, options) => {
    assert.equal(url.origin, 'https://dapi.kakao.com');
    assert.equal(url.searchParams.get('target'), 'isbn');
    assert.equal(url.searchParams.get('query'), '9788996991342');
    assert.equal(options.headers.Authorization, 'KakaoAK test-only');
    return Response.json({ documents: [{ title: '테스트', authors: ['작가'], publisher: '출판사', isbn: '9788996991342', thumbnail: 'http://unsafe.example/image', url: 'https://search.daum.net/', unexpected: 'secret' }], meta: { is_end: true } });
  });
  assert.equal(response.status, 200);
  const data = await response.json();
  assert.equal(data.books[0].thumbnail, '');
  assert.equal(data.books[0].title, '테스트');
  assert.equal(data.books[0].unexpected, undefined);
  assert.equal(data.isEnd, true);
});
test('upstream failures never expose their body or exception', async () => {
  for (const upstream of [async () => new Response('secret', { status: 401 }), async () => { throw new Error('secret'); }, async () => Response.json({ wrong: true })]) {
    const response = await handleRequest(request(), env, upstream);
    assert.ok(response.status >= 500);
    assert.ok(!(await response.text()).includes('secret'));
  }
});
