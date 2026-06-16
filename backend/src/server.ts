import { createApp } from './app';

const port = Number(process.env.PORT ?? 3000);
const app = createApp();

app.listen(port, (): void => {
  // eslint-disable-next-line no-console
  console.log(`Backend listening on port ${port}`);
});
