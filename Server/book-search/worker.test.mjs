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

test('blank, oversized and control-character searches never reach Kakao', async () => {
  for (const query of ['   ', 'a'.repeat(201), 'book\u0000title']) {
    assert.equal((await handleRequest(request(`/books?query=${encodeURIComponent(query)}`), env, neverFetch)).status, 400);
  }
  for (const page of ['0', '-1', '1.5', '01', 'abc']) {
    assert.equal((await handleRequest(request(`/books?query=test&page=${page}`), env, neverFetch)).status, 400);
  }
});

test('missing IP and failed limiter fail closed without contacting Kakao', async () => {
  const noIP = new Request('https://example.com/books?query=test');
  assert.equal((await handleRequest(noIP, env, neverFetch)).status, 503);
  const brokenLimiter = { ...env, SEARCH_LIMITER: { limit: async () => { throw new Error('private diagnostic'); } } };
  const response = await handleRequest(request(), brokenLimiter, neverFetch);
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { error: 'rate_limit_failed' });
});

test('provider quota exhaustion returns a safe retry response', async () => {
  const response = await handleRequest(request(), env, async () => new Response('private provider response', { status: 429 }));
  assert.equal(response.status, 429);
  assert.equal(response.headers.get('Retry-After'), '60');
  assert.equal(response.headers.get('Cache-Control'), 'no-store');
  assert.deepEqual(await response.json(), { error: 'rate_limited' });
});

test('title search preserves Unicode, pagination and safe redirect behavior', async () => {
  const response = await handleRequest(request(`/books?query=${encodeURIComponent('  어린 왕자  ')}&page=2`), env, async (url, options) => {
    assert.equal(url.searchParams.get('query'), '어린 왕자');
    assert.equal(url.searchParams.has('target'), false);
    assert.equal(url.searchParams.get('page'), '2');
    assert.equal(url.searchParams.get('size'), '20');
    assert.equal(options.redirect, 'manual');
    assert.ok(options.signal instanceof AbortSignal);
    return Response.json({ documents: [], meta: { is_end: true } });
  });
  assert.deepEqual(await response.json(), { books: [], isEnd: true });
});

test('redirects and malformed JSON never leak provider responses', async () => {
  for (const upstream of [
    async () => new Response(null, { status: 302, headers: { Location: 'https://other.example/' } }),
    async () => new Response('invalid private JSON'),
    async () => Response.json({ documents: [], meta: { is_end: 'false' } }),
  ]) {
    const response = await handleRequest(request(), env, upstream);
    assert.ok(response.status >= 500);
    const body = await response.text();
    assert.ok(!body.includes('private'));
    assert.ok(!body.includes('other.example'));
  }
});

test('limits response size and strips credentialed or unsafe URLs', async () => {
  const response = await handleRequest(request(), env, async () => Response.json({
    documents: Array.from({ length: 25 }, () => ({
      title: '책', authors: ['작가', null, 42], publisher: null, isbn: 123,
      thumbnail: 'https://user:password@example.com/image', url: 'javascript:alert(1)',
    })), meta: { is_end: false },
  }));
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('Cache-Control'), 'no-store');
  assert.equal(response.headers.get('X-Content-Type-Options'), 'nosniff');
  const body = await response.json();
  assert.equal(body.books.length, 20);
  assert.deepEqual(body.books[0], { title: '책', authors: ['작가'], publisher: '', isbn: '', thumbnail: '', url: '' });
  assert.equal(body.isEnd, false);
});
