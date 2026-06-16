import express, { type Express, type Request, type Response } from 'express';
import { createNotesStore, type NotesStore } from './notesStore.js';

export const createApp = (store: NotesStore = createNotesStore()): Express => {
  const app = express();
  app.use(express.json());

  app.get('/api/health', (_req: Request, res: Response): void => {
    res.json({ status: 'ok' });
  });

  app.get('/api/notes', (_req: Request, res: Response): void => {
    res.json(store.list());
  });

  app.post('/api/notes', (req: Request, res: Response): void => {
    const { text } = req.body ?? {};
    if (typeof text !== 'string' || text.trim().length === 0) {
      res.status(400).json({ error: 'text is required and must be non-empty' });
      return;
    }
    const note = store.add(text.trim());
    res.status(201).json(note);
  });

  return app;
};
