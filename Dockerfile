FROM rust:1-bookworm AS build
WORKDIR /src
COPY Cargo.toml Cargo.lock ./
COPY crates crates
COPY apps apps
COPY brand brand
RUN cargo build --locked --release -p couch-platform --bin couch-platform

FROM debian:bookworm-slim
WORKDIR /app
COPY --from=build /src/target/release/couch-platform /usr/local/bin/couch-platform
COPY runtimes/web/examples/blob-island /app/blob-island
ENV PORT=8080
ENV DATA_DIR=/data
ENV PACKAGES_DIR=/data/packages
ENV BLOB_ISLAND=/app/blob-island
EXPOSE 8080
CMD ["couch-platform"]
