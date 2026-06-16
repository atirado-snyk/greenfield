export interface Note {
  id: string;
  text: string;
  createdAt: string;
}

export interface NotesStore {
  list(): Note[];
  add(text: string): Note;
}

export const createNotesStore = (): NotesStore => {
  const notes: Note[] = [];
  let counter = 0;

  return {
    list(): Note[] {
      return [...notes];
    },
    add(text: string): Note {
      counter += 1;
      const note: Note = {
        id: String(counter),
        text,
        createdAt: new Date().toISOString(),
      };
      notes.push(note);
      return note;
    },
  };
};
