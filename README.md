# RIFT//RIOT — Web Edition

An original browser-based 3D arcade fighting game. Choose one of 12 fighters, take on the CPU, a local opponent, or an arcade circuit, and fight across eight animated arenas.

## Play

The production build is published with GitHub Pages. The game needs a modern browser with WebGL 2 and works best with a hardware keyboard.

Player 1: `A/D` move, `W` jump, `S` crouch, `J/K/L` attacks, `I` guard, `Shift` dash, `U` overdrive, `O` finisher.

Player 2: arrow keys to move, `1/2/3` attacks, `0` guard, `4` dash, `5` overdrive, `6` finisher.

## Local development

Requires Node 22 or newer.

```bash
npm install
npm run dev
```

Run `npm run build` to create the deployable static site in `dist/`. Pushing `main` publishes that build through the included GitHub Actions Pages workflow.
