# LLVM IR TCP Echo Server

Whenever I learn a programming language, a TCP echo server is always one of my first exercises, and with LLVM IR this was no exception.

My code here may not be that good, but I hope it serves as a small example for those looking for one.

The target for this project is `"x86_64-pc-linux-gnu"`. I don't know if it will work on other architectures or with a different libc

## Run

`lli server.ll [port?]`

## Compile (and run)

```
clang server.ll -o server
./server [port?]
```