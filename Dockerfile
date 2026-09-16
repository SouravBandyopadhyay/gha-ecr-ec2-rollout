FROM node:20-alpine AS frontend
WORKDIR /app/client
COPY client/package.json client/package-lock.json ./
RUN npm ci
COPY client/ ./
RUN npm run build

FROM node:20-alpine AS runtime
WORKDIR /app
COPY server/package.json server/package-lock.json ./
RUN npm ci --omit=dev
COPY server/ ./
COPY --from=frontend /app/client/dist ./public
ENV PORT=3000
EXPOSE 3000
CMD ["node", "index.js"]
