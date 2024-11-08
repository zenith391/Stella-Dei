<h1 align="center">Stella Dei</h1>

![Stella Dei](https://img.itch.zone/aW1nLzkxNjc2MTEucG5n/original/NH55dr.png)

Stella Dei is a sandbox game about creating planet and influencing it with your unlockable divine abilities in order to create and maintain life, civilizations, and maybe help them expand beyond.

> Careful. At some point you’re just playing god.

It's also inspired by SimEarth.

---

## Compiling

### Dependencies

The game requires:
- Zig [`2024.5.0-mach`](https://machengine.org/about/nominated-zig/) (`0.13.0-dev.351+64ef45eb0`)

### Building from source

```sh
$ git clone https://github.com/PixelGuys/Stella-Dei && Stella-Dei
$ zig build
```

And now you've got an executable located inside `zig-out/bin/`. If you want to directly run the game, just do:
```sh
$ zig build run
```

To distribute an executable for Windows, use:
```sh
$ zig build -Dtarget=native-windows -Dcpu=x86_64_v2 -Doptimize=ReleaseSafe
```
