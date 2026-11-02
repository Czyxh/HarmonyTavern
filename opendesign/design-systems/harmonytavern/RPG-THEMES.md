# RPG visual themes

The four optional themes extend the existing HarmonyTavern product system. They use the current appearance selection, persistence and display-mode settings. No backend, model routing, generation behavior or navigation changes are involved.

| Theme | Visual language | Light | Dark |
| --- | --- | --- | --- |
| 冒险者手札 | Parchment, paired corner rules, bronze ornament, rounded journal panels | Warm cream and forest ink | Moss charcoal and pale sage |
| 绯樱物语 | Washi grain, restrained vermilion, fine single corner rules | Rice paper and red seal | Indigo charcoal and muted blossom |
| 像素旅人 | Pixel town, square panels, stepped grid and corner blocks | Handheld green and ivory | Deep forest and light green |
| 烬火地牢 | Abbey ruins, stone grain, iron panels and angular corners | Weathered limestone and oxblood | Coal and candle amber |

`tokens/rpg-themes.json` freezes the palette, shape and image mapping shared by the preview and `RpgThemes.ets`. The runtime derives accessible semantic colors through the existing `CustomPalette` utilities and applies 7:1 primary-text / 4.5:1 secondary-text contrast against content surfaces. Both display modes are supported.

The original page layouts, copy, reading typography, gestures, touch targets and reduced-motion behavior remain intact. Shared content surfaces and buttons take theme-specific corners and borders. Full-screen decorative overlays ignore hit testing and are hidden from accessibility. Grain and artwork are deliberately faint over reading content; theme thumbnails show the full artwork. Functional and provider icons continue to use their existing semantic tint and brand policies.

Preview: `opendesign/mockups/rpg-themes/index.html`. Preview conversations are labeled demonstration content. They are never written into the app.

Asset credits and original license declarations are bundled at `entry/src/main/resources/rawfile/rpg-theme-assets.txt`. Downloaded originals remain under `build/rpg-theme-sources/`; only the twelve used, optimized artwork/texture/frame files are shipped in media resources. No remote URLs are needed at runtime.

Validation: `node build/rpg-themes-client-tests.cjs` checks palette parity, eight mode combinations, contrast, persisted selection, resource parity and existing-theme fallback. HAP build output is recorded separately in `build/rpg-themes-build.log`.
