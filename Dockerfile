# --- Stage 1: Build the frontend ---
FROM node:20-alpine as builder
WORKDIR /app
COPY ./package.json .
COPY ./yarn.lock .
RUN yarn install
COPY . .

# Pass the secret ONLY as a build argument if required by Vite, 
# but DO NOT save it to a global image ENV statement.
ARG TMDB_V3_API_KEY
RUN VITE_API_ENDPOINT_URL="https://api.themoviedb.org/3" VITE_APP_TMDB_V3_API_KEY=$TMDB_V3_API_KEY yarn build

# --- Stage 2: Serve with Nginx ---
FROM nginx:stable-alpine
WORKDIR /usr/share/nginx/html
RUN rm -rf ./*
# Only copy the compiled static HTML/JS/CSS assets
COPY --from=builder /app/dist . 
EXPOSE 80
ENTRYPOINT ["nginx", "-g", "daemon off;"]
