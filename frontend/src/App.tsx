import { useCallback, useEffect, useState, type FormEvent } from 'react';
import { createNote, fetchNotes, type Note } from './api.js';

export const App = (): JSX.Element => {
  const [notes, setNotes] = useState<Note[]>([]);
  const [draft, setDraft] = useState('');
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async (): Promise<void> => {
    setLoading(true);
    setError(null);
    try {
      const data = await fetchNotes();
      setNotes(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect((): void => {
    void load();
  }, [load]);

  const onSubmit = async (event: FormEvent<HTMLFormElement>): Promise<void> => {
    event.preventDefault();
    const text = draft.trim();
    if (!text) return;
    setSubmitting(true);
    setError(null);
    try {
      const note = await createNote(text);
      setNotes((prev) => [...prev, note]);
      setDraft('');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <main>
      <h1>Housing Notes</h1>

      <form onSubmit={onSubmit}>
        <input
          type="text"
          value={draft}
          onChange={(e): void => setDraft(e.target.value)}
          placeholder="Leave a note for your neighbours"
          disabled={submitting}
        />
        <button type="submit" disabled={submitting || draft.trim().length === 0}>
          {submitting ? 'Posting…' : 'Post'}
        </button>
      </form>

      {error && <div className="error">{error}</div>}

      {loading ? (
        <p>Loading notes…</p>
      ) : notes.length === 0 ? (
        <p>No notes yet. Be the first.</p>
      ) : (
        <ul>
          {notes.map((note) => (
            <li key={note.id}>
              <div>{note.text}</div>
              <div className="meta">{new Date(note.createdAt).toLocaleString()}</div>
            </li>
          ))}
        </ul>
      )}
    </main>
  );
};
