<h1 align="center">Stella Dei</h1>

![Stella Dei](https://img.itch.zone/aW1nLzkxNjc2MTEucG5n/original/NH55dr.png)

Stella Dei is a sandbox game about creating planet and influencing it with your unlockable divine abilities in order to create and maintain life, civilizations, and maybe help them expand beyond.

> Careful. At some point you’re just playing god.

It's also carefully inspired by SimEarth.

---

## Compiling

### Dependencies

The game requires:
- Zig master (at least `0.11.0-dev.1638+7199d7c77`)
- [Zigmod](https://github.com/nektro/zigmod)

### Building from source

```
$ git clone https://github.com/PixelGuys/Stella-Dei && Stella-Dei
$ zigmod fetch
$ zig build
```

*Note: you need the `ocl-icd-opencl-dev` package (only for building the game)*

Windows require one more step, you need to paste https://raw.githubusercontent.com/PixelGuys/Stella-Dei/master/deps/OpenCL.def into `YOUR_ZIG_FOLDER/lib/libc/mingw/lib-common/OpenCL.def` for 32-bit cross-compilation to work
If you want 64-bit to work, paste X to Y

And now you've got an executable located inside `zig-out/bin/`. If you want to directly run the game, just do:
```
$ zig build run
```

To distribute an executable, use:
```
$ zig build -Dtarget=native-windows -Dcpu=x86_64_v2 -Doptimize=ReleaseSafe
```
