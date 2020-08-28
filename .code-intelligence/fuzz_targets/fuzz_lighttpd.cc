#include <flibc.h>

FUZZ_SERVER(original_main, 1337, int client_fd, const uint8_t* data,
            size_t size) {
  int written = write(client_fd, data, size);
}

