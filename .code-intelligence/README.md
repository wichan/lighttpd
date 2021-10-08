# Fuzzing the lighttpd server

## What is fuzzing (in a nutshell)?

Fuzzing is a dynamic code analysis technique that supplies pseudo-random inputs
to a software-under-test (SUT), derives new inputs from the behaviour of the
program (i.e. how inputs are processed), and monitors the SUT for bugs.

## What is lighttpd?

lighttpd is a *light*weight open-source web server that is described by its
developers as being secure, fast, standard compliant and flexible. It can be
used for efficiently serving static content, but also supports advanced
features, such as FastCGI, SCGI, Auth, Output-Compression, URL-Rewriting and
many more.

In many web applications the web server (such as lighttpd) is the only component
facing the public internet, which makes it crucially important that it is well
tested and secured against all kinds of attacks. Should an attacker gain remote
code execution on a system through a vulnerable web server, other backend
services (such as the database) can be easily compromised as well.

## How can fuzzing help make it more secure?

A common source of security vulnerabilities are memory corruptions, which can
originate from programmer mistakes in code that employs pointer arithmetics or
low level memory operations (such as `memcpy`, `strcpy`, ...). Albeit dangerous
when used improperly, such operations are common when decoding data, that is
serialized into a standardized format for storage or transmission, such as
network packets. For a web server that could be an http request sent by a
client. By decoding the request the server obtains the information it needs to
process it:

- Which http method is used: `GET`, `POST`, ...
- Which resource is being asked for: `/imgs/cats/kitty.jpg`
- Any http headers that influence how the request should be processed:
  `Accept-Encoding: gzip`
- Any additional data provided in the body of the request:
  `username=fuzzy&password=fuzzbuzz`

All in all this is not an easy task. To verify that our request parser works as
expected we could (and should!) write unit tests, testing the parser with
various different request messages. However even though the unit tests may give
us confidence that the parser can decode valid http requests correctly, we
cannot be sure that a particular ill-formed request, the developer didn't think
about, won't cause a memory corruption somewhere, opening a door for an
attacker.

Luckily with fuzz testing there is an effective way to find memory corruption
bugs and unforseen edge cases. Instead of testing the program with individual
specific inputs, the fuzzer generates thousands of them per second while trying
to explore different execution paths and maximizing the code coverage in the
program under test. Simultaneously sanitizers, such as the AddressSanitizer,
check the program for erroneous behavior like heap or buffer overflows. With
this technique, we can be reasonably sure, that our http request parser is also
resilient against maliciously ill-formed requests.

## Using the CI Fuzz socket fuzzer

Creating a good fuzz test manually can be tricky, since a couple of things need
to be considered:

- We need to write a fuzz test that passes fuzzer data to the request parser
- The web server needs to be built as a library, so that we can use it in our
  fuzz test
- Specific instrumentation and sanitizer flags need to be added during the build

With the CI Fuzz socket fuzzer we don't need to worry about any of this. When
building the project inside CI Fuzz, it takes care of the build process for us,
linking the fuzz tests and injecting instrumentation flags where needed. We
don't even need to write a fuzz test ourselves. All CI Fuzz needs to know is how
to start the web server and which port to target. Take a look at the config of
the `fuzz_lighttpd` fuzz test. As you can see, we tell the web server to read
its settings from `lighttpd.conf` which contains the line `server.port = 1337`.

The fuzz test for port 1337, that CI Fuzz generated for us, looks like this:

```C
#include <flibc.h>

FUZZ_SERVER(original_main, 1337, int client_fd, const uint8_t* data, size_t size) {
    int written = write(client_fd, data, size);
}
```

The first two arguments for the `FUZZ_SERVER` macro will tell CI Fuzz to start
the lighttpd server (`original_main` refers to lighttpd's `main` method) in a
new thread and establish a connection to port 1337. The rest behaves similar to
a fuzz test you may know from libfuzzer where `data` and `size` refer to a
fuzzer generated input. However the socket fuzz macro provides us with an
additional parameter `client_fd` which is a file descriptor pointing to an
opened connection to port 1337 of the web server. All is left to do is to write
the fuzzer data to the file descriptor.

Being able to modify this fuzz test gives us flexibility when working with more
complex server applications. A scenario might be that we first want to send some
fixed data for authentication before following up with fuzzer generated data
that can then reach the actual application logic.

## Findings

When clicking on "All Findings" in the left sidebar of CI Fuzz, we can see that
our simple fuzz test was actually able to find something. A heap buffer overflow
is a memory corruption that happens when data is read or written beyond the
actual size of a buffer allocated on the heap. The information in the summary
and the log show us that this bug indeed occured in the http request parser
while trying to decode a malformed request generated by the fuzzer. The request
leading to this bug consists of just the four bytes `20 C4 B9 20`, nothing we
would have found with a unit test.

## Where you can go from here

### A note regarding corpus data

For each fuzz test, a corpus of interesting inputs is built up over time by
the fuzzer. Each corpus entry represents an input that managed to increase
coverage metrics (such as newly-covered lines, statements or even values in an
expression). With help of a genetic algorithm new inputs can be generated based
on the collected ones in the corpus. When writing a new fuzz test, you can give
the fuzzer a head start and increase the code coverage from the beginning by
providing a couple of valid example inputs ("seed inputs"). For this fuzz test
we could provide some example HTTP requests.

### Fuzzing in CI/CD

If integrated in the CI/CD, fuzzing can help to find regressions or bugs in
new code early in the process. This reduces costs and effort fixing them and
supports you delivering reliable and secure software. Once setup, the CI/CD
integration can be used to fuzz every new commit made to selected branches or
to fuzz pull requests before they are merged. The corpus data from previous
fuzzing runs is used, enabling the fuzzer to use its prior knowledge of the
application.

### Increasing code coverage

CI Fuzz allows you to easily identify which lines of the code base are
covered by the fuzzer and highlights the ones it couldn't reach yet. Based on
that information you can create new fuzz tests or adapt your existing ones to
allow them to reach additional code paths.
