import request from 'supertest';
import { createApp } from './app';

describe('Notes API', () => {
  it('reports ok from the health endpoint', async () => {
    const res = await request(createApp()).get('/api/health');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ok' });
  });

  it('starts with an empty notes list', async () => {
    const res = await request(createApp()).get('/api/notes');
    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });

  it('adds a note and returns it from the list', async () => {
    const app = createApp();
    const created = await request(app).post('/api/notes').send({ text: 'hello' });
    expect(created.status).toBe(201);
    expect(created.body.text).toBe('hello');
    expect(typeof created.body.id).toBe('string');

    const list = await request(app).get('/api/notes');
    expect(list.body).toHaveLength(1);
    expect(list.body[0].text).toBe('hello');
  });

  it('trims surrounding whitespace from a note', async () => {
    const app = createApp();
    const res = await request(app).post('/api/notes').send({ text: '  hello  ' });
    expect(res.status).toBe(201);
    expect(res.body.text).toBe('hello');
  });

  it('rejects a whitespace-only note', async () => {
    const res = await request(createApp()).post('/api/notes').send({ text: '   ' });
    expect(res.status).toBe(400);
  });

  it('rejects a missing text field', async () => {
    const res = await request(createApp()).post('/api/notes').send({});
    expect(res.status).toBe(400);
  });
});
