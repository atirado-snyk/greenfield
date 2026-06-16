export interface Note {
  id: string;
  text: string;
  createdAt: string;
}

const headers = { 'Content-Type': 'application/json' };

export const fetchNotes = async (): Promise<Note[]> => {
  const res = await fetch('/api/notes');
  if (!res.ok) {
    throw new Error(`Failed to load notes (${res.status})`);
  }
  return res.json() as Promise<Note[]>;
};

export const createNote = async (text: string): Promise<Note> => {
  const res = await fetch('/api/notes', {
    method: 'POST',
    headers,
    body: JSON.stringify({ text }),
  });
  if (!res.ok) {
    throw new Error(`Failed to create note (${res.status})`);
  }
  return res.json() as Promise<Note>;
};
