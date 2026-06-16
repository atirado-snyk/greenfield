FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
COPY backend/package.json backend/package.json
RUN npm ci --workspace @housing-notes/backend --include-workspace-root

FROM node:20-alpine AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/backend/node_modules ./backend/node_modules
COPY tsconfig.base.json ./
COPY backend ./backend
RUN npm run build --workspace @housing-notes/backend

FROM node:20-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3001
COPY package.json package-lock.json ./
COPY backend/package.json backend/package.json
RUN npm ci --workspace @housing-notes/backend --omit=dev --include-workspace-root
COPY --from=build /app/backend/dist ./backend/dist
EXPOSE 3001
USER node
CMD ["node", "backend/dist/server.js"]
