# BarTrack 10-second ad: source

- `ad.html`: the animation, drawn on a 1080×1920 canvas. `renderAt(t)` draws the frame at time `t` (seconds).
- `render.js`: renders 300 frames (30 fps) with Playwright: `node render.js frames`, or `node render.js stills` for a few preview images.
- `audio.py`: synthesizes the soundtrack (`audio.wav`) with numpy. No third-party music.

Build the video:

```bash
node render.js frames && python3 audio.py
```
```bash
ffmpeg -framerate 30 -i frames/%04d.png -i audio.wav -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart -c:a aac -b:a 192k -shortest BarTrack-ad-10s.mp4
```
