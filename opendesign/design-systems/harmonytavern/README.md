# HarmonyTavern existing product design

Extracted 2026-11-02 for the usage statistics feature. The existing application and the user's selected Codex visual baseline are the design anchor. The supplied screenshot contributes section order, filtering and chart types; its colors, figures and product identity are not copied.

## Index

- `SKILL.md`: reusable product rules and statistics-page guidance.
- `tokens/colors_and_type.css`: source-derived default paper light/dark colors, spacing and typography for web previews.
- `assets/icons/`: copies of existing application icons; no redrawing or external image paths.

## Sources consulted

- `entry/src/main/ets/theme/Tokens.ets`: semantic colors, typography, spacing, radius and touch sizes.
- `entry/src/main/ets/theme/Appearance.ets`: supported palettes and generated rose/custom theme behavior.
- `entry/src/main/resources/base/element/appearance.json` and `dark/element/appearance.json`: exact default paper color values.
- `entry/src/main/ets/components/SettingsEntryRow.ets`: compact grouped settings rows, icons, press opacity and accessible labels.
- `entry/src/main/ets/theme/Motion.ets`: app motion conventions and distinction between platform references and house style.
- User's attached statistics reference: heatmap, overview, call ranking, token totals/cache coverage and source rankings.

## Content and interaction fundamentals

Use short Chinese task labels and specific state messages. Avoid promotional copy in analytics. Counts and units must agree; K/M abbreviations need full accessible values. Missing measurements stay missing. Confirmed zero remains distinct. Use theme accent to encode activity intensity and chart fill, but supply text values so color is never the only signal. Preserve list scroll positions where practical and avoid scroll jumps when only the filter changes. Time-range requests need stale-result protection.

## Scope and confidence

The default paper color extraction and source component conventions are directly grounded in the app. Other palettes are selected at runtime and must flow through `uiColors`; the preview CSS does not replicate every custom theme. Exact heatmap geometry and responsive chart layout remain implementation decisions to verify in ArkUI on the target device. No new app functionality or sample usage data was created by this setup.
