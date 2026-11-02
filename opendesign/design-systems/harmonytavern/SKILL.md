---
name: harmonytavern-product-design
description: Existing HarmonyTavern ArkUI product design baseline, extracted from the current application. Use for in-app features and settings, including usage statistics.
---

# HarmonyTavern product baseline

This records the current app, not a replacement brand or an official Huawei specification. Runtime ArkUI ColorTokens and user preferences remain the source of truth; CSS tokens support preview artifacts only.

- Warm paper, ink text and a restrained green accent are the default. Preserve all existing palette choices and dark mode. Never hard-code this default palette into ArkTS pages.
- Use existing `PageSurface` and `PageHeader` for pages; glass back/refresh actions use `HeaderAction`, whose material matches the chat composer. Preserve the established top gradient and navigation centering.
- Statistics content is on readable, gently rounded theme surfaces; glass belongs to navigation and controls. Do not add liquid distortion behind long text or charts.
- Match existing `JellyTabBar` for segmented choices. Respect reduced motion, immediate press feedback, safe insets and 44vp minimum independent action targets.
- Typography uses the app's chosen/system font. Page title 20–22sp, section title 17sp, body 15sp, caption 12–13sp. Statistics can use 28–32sp semibold numerals with explicit units.
- Spacing follows 4/8/12/20/24/32vp. Card radii 20–28vp. Use thin theme borders, never heavy colored accent strips.
- Copy is plain Chinese, concise and calm. Numbers are factual. No made-up accounts, model usage, activity or costs.

## Usage statistics reference

The user's supplied long screenshot establishes the information architecture: 全部 / 近30天 / 近12个月; activity heatmap; four overview metrics; model call ranking; six token metrics; usage sources; token consumption ranking. Keep this order while using HarmonyTavern theme and components.

- Heatmap intensity uses the active theme accent, with textual day count and longest streak. Provide a selected-day value/details and accessible equivalent; tiny cells need not each become inaccessible tiny buttons.
- Overview: active conversations, message count, models used, active days. Use a two-column grid when space permits, one column when large text or narrow width requires it.
- Rank bars use theme accent and subtle track. Long model names wrap or ellipsize with an accessible full label. Limit the visible ranking to ten entries as requested.
- Token cards: total, input, output, average per reply, cache hits, cache hit rate. “—” means missing/unreported, while confirmed zero is “0”. Cache is a subset of input and must not be added again to total.
- Explain the denominator and coverage of averages and hit rate. Provider-reported actual usage is authoritative; do not infer historical missing usage from message length.
- Include clear empty, loading, refresh and error states. No sample figures in the production screen. A time range affects all summary/ranking/token sections consistently; label the heatmap's own window.
- Dates and day buckets use the same stated time zone. Keep history statistics and request usage distinct enough to avoid counting imports, retries or background tasks twice.

See README.md for source files and tokens/colors_and_type.css for preview values.
