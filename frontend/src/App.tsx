import { FormEvent, useEffect, useState } from 'react';
import { createNote, fetchNotes, Note } from './api';

export const App = (): JSX.Element => {
  const [notes, setNotes] = useState<Note[]>([]);
  const [text, setText] = useState<string>('');
  const [loading, setLoading] = useState<boolean>(true);
  const [submitting, setSubmitting] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchNotes()
      .then((loaded) => setNotes(loaded))
      .catch((err: unknown) => setError(err instanceof Error ? err.message : 'Unknown error'))
      .finally(() => setLoading(false));
  }, []);

  const handleSubmit = async (event: FormEvent<HTMLFormElement>): Promise<void> => {
    event.preventDefault();
    const trimmed = text.trim();
    if (trimmed.length === 0) {
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      const created = await createNote(trimmed);
      setNotes((current) => [...current, created]);
      setText('');
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <main className="app">
      <h1>Housing Notes</h1>

      <form onSubmit={handleSubmit} className="note-form">
        <label htmlFor="note-text" className="sr-only">
          New note
        </label>
        <input
          id="note-text"
          type="text"
          value={text}
          onChange={(event) => setText(event.target.value)}
          placeholder="Leave a note for your neighbours..."
          disabled={submitting}
        />
        <button type="submit" disabled={submitting || text.trim().length === 0}>
          {submitting ? 'Posting...' : 'Post note'}
        </button>
      </form>

      {error && <p role="alert" className="error">{error}</p>}

      {loading ? (
        <p>Loading notes...</p>
      ) : notes.length === 0 ? (
        <p className="empty">No notes yet. Be the first to post one.</p>
      ) : (
        <ul className="note-list">
          {notes.map((note) => (
            <li key={note.id} className="note">
              <p>{note.text}</p>
              <time dateTime={note.createdAt}>{new Date(note.createdAt).toLocaleString()}</time>
            </li>
          ))}
        </ul>
      )}
    </main>
  );
};
