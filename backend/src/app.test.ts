import request from 'supertest';
import { createApp } from './app.js';

describe('housing-notes backend', (): void => {
  it('responds to /api/health', async (): Promise<void> => {
    const res = await request(createApp()).get('/api/health');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ok' });
  });

  it('returns an empty list initially', async (): Promise<void> => {
    const res = await request(createApp()).get('/api/notes');
    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });

  it('adds a note and lists it', async (): Promise<void> => {
    const app = createApp();
    const add = await request(app).post('/api/notes').send({ text: 'Broken gate at side entry' });
    expect(add.status).toBe(201);
    expect(add.body).toMatchObject({ text: 'Broken gate at side entry' });

    const list = await request(app).get('/api/notes');
    expect(list.status).toBe(200);
    expect(list.body).toHaveLength(1);
    expect(list.body[0]).toMatchObject({ text: 'Broken gate at side entry' });
  });

  it('rejects an empty note', async (): Promise<void> => {
    const res = await request(createApp()).post('/api/notes').send({ text: '' });
    expect(res.status).toBe(400);
  });

  it('rejects a whitespace-only note', async (): Promise<void> => {
    const res = await request(createApp()).post('/api/notes').send({ text: '   ' });
    expect(res.status).toBe(400);
  });

  it('rejects a missing text field', async (): Promise<void> => {
    const res = await request(createApp()).post('/api/notes').send({});
    expect(res.status).toBe(400);
  });

  it('trims surrounding whitespace before storing', async (): Promise<void> => {
    const app = createApp();
    const add = await request(app).post('/api/notes').send({ text: '  hello  ' });
    expect(add.body.text).toBe('hello');
  });
});
