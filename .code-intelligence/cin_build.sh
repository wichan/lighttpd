#sudo apt-get install -y build-essential libpcre3-dev libc6-dev-i386 zlib1g-dev scons libbz2-dev libtool autoconf autogen pkg-config autoconf-archive
scons -j$(nproc) build_static=1 build_dynamic=0

