# Character art direction

The heroine is an original golden maze-chaser designed for this project. Her
production silhouette uses a round golden body, burgundy gloves and boots, and
an asymmetrical teal comet ornament. These choices should remain consistent in
future expressions, animations, promotional art, and the eventual glTF model.

## Generated assets

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
