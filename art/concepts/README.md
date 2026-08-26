# Character art direction

The heroine is an original golden maze-chaser designed for this project. Her
production silhouette uses a round golden body, burgundy gloves and boots, and
an asymmetrical teal comet ornament. These choices should remain consistent in
future expressions, animations, promotional art, and the eventual glTF model.

## Generated assets

- `nix-turnaround-v1.png`: four-view modeling sheet for Nix, the moon-courier
  protagonist of the Game Center's fantasy side-scroller.
- `moonfall-causeway-environment-v1.png`: side-view environment and parallax
  direction for the first Moonfall Courier region.
- `heroine-turnaround-v1.png`: the approved front/three-quarter/side/back
  modeling reference and expression study.
- `heroine-portrait-checkerboard-v1.png`: an early portrait whose checkerboard
  was baked into RGB; retained as iteration history and not shipped.
- `../../assets/images/heroine-portrait-v2.png`: the alpha-bearing HUD portrait
  shipped with the Flutter app.

## ImageGen prompts

Built-in ImageGen was used. The turnaround prompt requested an original,
modelable stylized 3D heroine with consistent orthographic views, golden satin
body, burgundy gear, teal comet ornament, and explicit avoidance of licensed
arcade-character details. The portrait used the turnaround as its identity
anchor; the second edit requested background extraction with genuine alpha
while preserving the character design.

Nix's prompt requested a consistent front/profile/back/three-quarter model
sheet in a neutral A-pose, with reconstruction-friendly separated limbs and
simple material regions. Her locked identity includes silver-blue hair, amber
eyes, a teal travel cloak, plum tunic, burgundy boots, crescent satchel, and a
glowing cyan moon charm.

The Moonfall Causeway prompt requested a gameplay-readable side view with five
separable depth layers: dark foreground platforms, ruined observatories,
floating middle-distance causeways, a fractured cyan moon, and an indigo star
field. Violet fog defines the death plane while sparse amber lanterns mark safe
routes. The image is concept direction; the shipped level should rebuild these
layers as real Flutter Scene geometry, fog, particles, lights, and shaders.
