# Analytics (standalone build)

The game is exported twice from the same project:

| Preset | For | Extra in the page |
|---|---|---|
| `Web` | CrazyGames | CrazyGames SDK v3: loading and gameplay events, happytime, save on the player's account. No analytics. |
| `Web Standalone` | Your own hosting | No CrazyGames SDK. Sends gameplay events to your endpoint. |

Both use `custom_html/custom_shell.html`; the difference is the preset's `html/head_include`
in `export_presets.cfg`.

## Setting the endpoint

In `export_presets.cfg`, preset `Web Standalone`, `html/head_include`:

```
window.FF_ANALYTICS_URL = "https://your.endpoint/collect";
window.FF_BUILD = "1.0.0";
```

With an empty URL the events are printed to the browser console instead, which is how to
check them before the endpoint exists.

## What is sent

One `POST` with a JSON body (sent as `text/plain`, so the endpoint needs no CORS preflight),
every 5 seconds while there are events, and when the page is hidden or closed:

```json
{
  "game": "flick-freight", "build": "1.0.0",
  "player": "k3j9x0aqlmn4z1", "session": "p0d8s7fhlmn4z9",
  "screen": "1280x720", "lang": "en-US",
  "events": [
    {"name": "level_end", "t": 1760000000000, "seq": 4,
     "props": {"level": 12, "id": 8, "world": "WOODS", "stars": 2, "loaded": 6, "total": 7, "thrown": 7, "seconds": 41.5}}
  ]
}
```

`player` is a random id kept in the browser's local storage; `session` is new on every page
load. No name, e-mail, IP-based lookup or device fingerprint is collected by the game.

| Event | When | Props |
|---|---|---|
| `session_start` | The game has loaded | `stars`, `next_level`, `new_player` |
| `tutorial_done` | First throw of the tutorial level | none |
| `level_start` | A level starts (also after a restart) | `level`, `id`, `world`, `best_stars` |
| `level_end` | The results screen | `level`, `id`, `world`, `stars`, `loaded`, `total`, `thrown`, `seconds`, and `reason` when failed (`too_few`, `missing_type`, `time`) |
| `level_restart` | Restart before the level ended | `level`, `id`, `world`, `thrown`, `loaded`, `seconds` |
| `level_quit` | Back to the menu before the level ended | same as `level_restart` |

`level` is the number the player sees; `id` never changes when levels are reordered.

## The endpoint

Anything that accepts a POST and stores the body works. Reply with any 2xx status; the game
ignores the response. It must allow cross-origin requests from the page's origin if it is on
another domain (`Access-Control-Allow-Origin`), although a beacon is delivered either way.

## Privacy

The events are anonymous, but an id stored in the browser is still personal data under GDPR.
Before sending real traffic, add a short privacy notice to the page that hosts the game.
The CrazyGames build sends nothing of its own.
