import express, { Express, Request, Response } from 'express';
import { NotesStore } from './notesStore';

export const createApp = (store: NotesStore = new NotesStore()): Express => {
  const app = express();
  app.use(express.json());

  app.get('/api/health', (_req: Request, res: Response): void => {
    res.json({ status: 'ok' });
  });

  app.get('/api/notes', (_req: Request, res: Response): void => {
    res.json(store.list());
  });

  app.post('/api/notes', (req: Request, res: Response): void => {
    const body = req.body as { text?: unknown };
    const text = body?.text;
    if (typeof text !== 'string' || text.trim().length === 0) {
      res.status(400).json({ error: 'Note text is required' });
      return;
    }
    const note = store.add(text.trim());
    res.status(201).json(note);
  });

  return app;
};
