import json, strformat

let
  manifest = parseJson(readFile("./dist/manifest.json"))
  userScriptSrc = &"""
// ==UserScript==
// @name         {manifest["name"].getStr()}
// @version      {manifest["version"].getStr()}
// @author       {manifest["author"].getStr()}
// @namespace    https://github.com/kklkkj/
// @description  {manifest["description"].getStr()}
// @homepage     {manifest["homepage_url"].getStr()}
// @match        https://*.bonk.io/gameframe-release.html
// @match        https://*.bonkisback.io/gameframe-release.html
// @match        https://*.multiplayer.gg/physics/gameframe-release.html
// @run-at       document-start
// @grant        none
// ==/UserScript==

/*
  This userscript requires:
  https://greasyfork.org/en/scripts/433861-code-injector-bonk-io
  (or another browser extension mod)
*/
{readFile("./dist/injector.js")}
"""

let version = manifest["version"].getStr()
writeFile(&"./build/kklee.user.js",
  userScriptSrc)
