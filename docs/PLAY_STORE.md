# Publishing GHOSTNET: Deep Dive on Google Play

Everything the Play Console asks for, in order. Files referred to here are in `store/` (listing art) and
`build/android/` (the app, made by `tools/build_android.sh`).

## 0. One-time setup

1. **Developer account**: https://play.google.com/console, $25 once, with ID verification.
   New *personal* accounts must run a **closed test with at least 12 testers for 14 days** before the game can go to
   Production. Start that early.
2. **Upload key**: create it once, on this Mac (see the README "Android" section). Back up `~/.config/ghostnet/` somewhere
   safe. Google re-signs the app with its own key (Play App Signing), so a lost upload key can be reset, but it takes time.

## 1. Create the app

- App name: **GHOSTNET: Deep Dive**
- Default language: English (United Kingdom) or (United States)
- App or game: **Game** · Free
- Package name (set by the build, permanent): `com.varadrane.ghostnet`

## 2. Store listing

**Short description** (80 characters max):

> Dive the drowned city, cut ghost nets, free sea life, and save the last whale.

**Full description**:

> Port Halo's fishing fleet cuts its snagged nets loose every day. Down below, those ghost nets keep fishing:
> no boat, no crew, no end.
>
> You are Nova Vale, a 16-year-old reef warden, with Pip, your little drone. Launch off your mother's boat, glide
> through the Drowned City, the Slope, the dark Trench and the Abyss, cut ghost nets, free trapped turtles and fish, and
> tear down the four great net walls between you and the Lumen, the giant whale whose song keeps the last reef alive.
>
> • A launch-and-glide upgrade game: every dive earns fleet tags for better gear
> • 18 gear tiers, from a kickboard to the Leviathan
> • Flips, loops, grinds and net chains for style points and ranks
> • Piranhas, puffer fish and electric rays in your way
> • A fully voiced story told in cutscenes, with a twist at the bottom of the sea
> • Hand-made neon art, drawn entirely in code
>
> Cleanup saves one animal at a time. The problem only ends at its source. Made for SDG 14: Life Below Water.

- App icon: `store/play_icon_512.png`
- Feature graphic: `store/feature_1024x500.png`
- Phone screenshots: `store/screenshot_*.png` (1920 x 1080, landscape)
- Category: **Arcade** · Tags: Casual, Arcade, Single player
- Contact email: required (it is shown publicly on the listing)

## 3. App content (Policy section)

- **Privacy policy**: put `docs/PRIVACY.md` online (for example its GitHub page once merged to `master`) after replacing
  `CONTACT_EMAIL`, and paste the URL.
- **Ads**: No ads.
- **App access**: All functionality available without special access.
- **Content rating** (IARC questionnaire): category *Game*. No violence against people; cartoon fish nibble the diver
  (no blood); no fear, sex, language, drugs, gambling, user interaction or purchases. Expected rating: Everyone / PEGI 3.
- **Target audience**: 13 and over is simplest (choosing under-13 brings in the extra Families policy review).
- **Data safety**: the game collects and shares **no data**; no data is transmitted; no account.
- **Government apps / financial / health**: No.

## 4. Testing, then release

1. Testing → **Closed testing** → create a track, add your 12+ testers' Google accounts (or a Google Group), upload
   `build/android/ghostnet.aab`, roll out. Share the opt-in link with testers; they must stay opted in for 14 days.
2. After 14 days apply for **Production** access in the console, then create a production release with the same AAB
   (or a newer one: raise `version/code` in `export_presets.cfg` for every upload).

## Notes

- **Voices and the ElevenLabs free plan**: the free plan is for non-commercial use and requires credit (the credits
  screen has it). A free game with no ads is the safest fit. If the game will ever earn money, move to a paid ElevenLabs
  plan and re-make the voices (`tools/make_voices.py`), since commercial rights cover clips made on a paid plan.
- Every update needs a higher `version/code` (1, 2, 3...) and usually a new `version/name` (1.0.1...).
