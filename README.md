# kklee

A [bonk.io](https://bonk.io) mod that extends the functionality of the map
editor.

[Guide](./guide.md)

[Bonk.io Modding Discord server](https://discord.gg/PHtG6qN3qj)

## Installing as a userscript

Userscripts require a userscript manager such as Violentmonkey or Tampermonkey,
and [Excigma's code injector userscript](https://greasyfork.org/en/scripts/433861-code-injector-bonk-io).

The userscript is available at
<https://github.com/BonkModdingCommunity/kklee/releases/latest/download/kklee.user.js>

## Installing as an extension

Download <https://github.com/BonkModdingCommunity/kklee/releases/latest/download/kklee.zip>

<details>
<summary>In Firefox</summary>

**Note:** You will have to do this after every time you restart the browser.

1. Go to `about:debugging#/runtime/this-firefox`
2. Click `Load temporary addon` and open the zip file.

</details>

<details>
<summary>In Chrome (and other Chromium-based browsers, hopefully)</summary>

1. Go to `chrome://extensions/`
2. Enable `Developer mode` in the top-right corner of the page.
3. Drag and drop the zip file into the page.

</details>

## "It doesn't work"

Did you:

- Disable any mods that are incompatible with kklee, such as
  Bonk Leagues Client
- Refresh Bonk.io after installing
- Download the correct file from Releases?

It is also possible that a recent bonk.io update broke the mod and it needs to
be fixed.

---

## Building

<details>
<summary>Ignore this if you just want to install the mod</summary>

1. Install the following:
   - [Node.js](https://nodejs.org/) (v16.3.0)
   - [Nim](https://nim-lang.org/) (v1.6.4)
2. Run `npm ci` to install npm dependecies.
3. Run `nimble install -d` to install nimble dependencies.
4. Run either:

   - `npm run buildDev` (no minfication so build is quicker)
   - `npm run buildRelease` (minified)

   The files will be saved in the `build` directory.

</details>
