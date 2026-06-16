import { randomUUID } from 'crypto';

export interface Note {
  id: string;
  text: string;
  createdAt: string;
}

export class NotesStore {
  private notes: Note[] = [];

  list(): Note[] {
    return [...this.notes];
  }

  add(text: string): Note {
    const note: Note = {
      id: randomUUID(),
      text,
      createdAt: new Date().toISOString(),
    };
    this.notes.push(note);
    return note;
  }
}
