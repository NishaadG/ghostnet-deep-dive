# Publishing GHOSTNET: Deep Dive on itch.io

The game is a plain Godot **Web export** (thread support off), so it runs on itch.io without any special headers.

## 1. Build the zip

```
godot --headless --path . --export-release Web build/web/index.html
```
Then zip the **contents** of `build/web` (so `index.html` is at the top of the zip). On Windows PowerShell:
```
Compress-Archive -Path build\web\* -DestinationPath build\ghostnet-deep-dive-web.zip -Force
```
(`build/ghostnet-deep-dive-web.zip` is already built by the last export.)

## 2. Create the itch.io page

1. itch.io > Dashboard > **Create new project**.
2. **Kind of project:** HTML.
3. Upload `ghostnet-deep-dive-web.zip` and tick **This file will be played in the browser**.
4. **Embed options:** viewport **1280 x 720**, tick **Mobile friendly**, orientation **Landscape**, tick **Fullscreen button**. Leave "SharedArrayBuffer support" **off**.
5. Description idea: "A launch-and-glide upgrade game about ghost nets. SDG 14: Life Below Water."
6. Set the page to **Draft**, open the preview and play once, then change visibility to **Public**.

Optional, with the `butler` command line tool: `butler push build/ghostnet-deep-dive-web.zip YOUR_NAME/ghostnet-deep-dive:html5`.

## 3. Phones

- The game is landscape only. Held upright it shows "Please turn your phone sideways" and pauses the dive.
- Touch controls turn on by themselves on a touch device: hold the top half of the screen to tilt up, the bottom half to tilt down, BOOST for thrust, and the round button for pause.
- On itch.io, tap the **fullscreen** button of the embed for the best fit.

## 4. Known limits

- A browser tab saves progress in its own storage: clearing site data or using a private tab loses the save.
- The first load downloads about 12 MB (the game engine plus about 5 MB of music and sound).
