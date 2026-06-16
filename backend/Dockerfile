# syntax=docker/dockerfile:1.7
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
COPY backend/package.json ./backend/package.json
RUN npm ci --workspace=@housing-notes/backend --include-workspace-root
COPY backend ./backend
RUN npm run build --workspace=@housing-notes/backend

FROM node:20-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY package.json package-lock.json ./
COPY backend/package.json ./backend/package.json
RUN npm ci --workspace=@housing-notes/backend --include-workspace-root --omit=dev
COPY --from=build /app/backend/dist ./backend/dist
USER node
EXPOSE 3000
CMD ["node", "backend/dist/server.js"]
