FROM ubuntu:20.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    # git pull script dependencies
    ca-certificates \
    git \
    # lighttpd dependencies
    build-essential \
    libpcre3-dev \
    scons \
 && rm -rf /var/lib/apt/lists/*
