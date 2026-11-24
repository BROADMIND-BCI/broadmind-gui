# Site pages

`gui/` is the source of the BROADMIND GUI landing page published at
<https://broadmind.me/gui/>.

It started as a design-tool export (`Main.dc.html` + `support.js` + a vendored React runtime)
provided as a reference mockup: a static `<x-dc>` template rendered client-side. Two changes were
made to the export before publishing:

- the design's video asset was replaced with the 15-second cut of
  [`docs/media/broadmind-gui-demo.mp4`](../../media/broadmind-gui-demo.mp4)
- the hashed asset filenames were replaced with readable ones (`assets/gui-demo.mp4`,
  `assets/hero.jpg`)

The live page is a directory rather than a flat `.html` file because it ships its own assets; Apache
redirects `/gui` to `/gui/` on its own, so no `.htaccess` rule is needed.

Deploying is a plain file copy into the site docroot followed by a Cloudflare cache purge — see
`docs/DISTRIBUTION.md` §6. Note that per-URL purges do not take effect on this zone; a full purge is
required.
