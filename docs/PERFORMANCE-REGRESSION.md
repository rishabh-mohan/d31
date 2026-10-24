# Whole-game FPS regression — 2026-10-24

## Evidence and correction

Claude's earlier Nord profile measurements were roughly 7–10ms build and 8ms
raster. The stationery auto-fit cache addresses that known widget-build cost;
it remains unchanged. See CLAUDE.md section 5e for the measurement method.

The later APK deployments were launched with both Impeller disabled and
software rendering enabled to obtain screenshots. Leaving the software flag
active for normal use was a deployment mistake. The user reported low FPS
throughout the game after each push. The running process's log showed repeated
raster durations of about 498–594ms, often with build durations of only 7–56ms.
That is a different bottleneck from the earlier widget-build measurements.

The same installed debug APK was cold-started without software rendering for
an initial A/B check. Startup logs then showed mostly 2–13ms raster durations,
with a 140ms cold-start outlier. These are startup samples, not a claim of
verified sustained gameplay FPS. The raw post-restart samples are local-only
in build/hardware-debug-jank.log. The user subsequently confirmed the game is much smoother.

A profile APK is now installed and verified for normal hardware-rendered play. Keep
FrameTiming's build/raster split; do not remove evidence by disabling the
animations or guessing at image optimizations. Do not remove the existing
image-provider and stationery-fit caches.

## Deployment rule

Use a hardware-rendered profile build for phone performance checks. A normal
cold launch may disable Impeller to use hardware Skia, but must not enable
software rendering. Restart the app after any temporary screenshot workaround
so the new engine uses the correct backend. Never leave the screenshot engine
as the user's playing session.

## Separate book-gain regression

Retry Year's study multiplier had been raised from 3 to 9 to fit recovered
exam thresholds. That unverified adjustment made an unbuffed power-5 starter
book give +45 instead of the previous +15. The multiplier is restored to 3 in
the generated pack and builder. A regression checks both the preview and actual
grant in both campaigns, without traits, badges or stationery.

Recovered exam thresholds are unchanged. Progression tuning and exact original
scoring remain separate tasks; ordinary book gains must not hide those gaps.

## Profile deployment result

The profile APK installed successfully, its installed SHA-256 matches the local
artifact, and the phone's corrected rules.json checksum also matches. A normal
hardware Skia cold start took about 0.95 seconds. Logged over-budget startup
frames mostly had 0.4-7.9ms build and 3.3-9.0ms raster, with cold raster outliers
of 21.7ms and 52.8ms. These logs include only frames over the total budget;
they cannot establish average FPS or sustained gameplay performance.

Raw samples: build/hardware-profile-jank.log. Installed artifact:
build/nord-profile-deployment-verification.json. The user confirmed the whole game is much smoother after the hardware restart.
TODO 19's global regression is resolved. This does not claim every frame is
within budget or erase Claude's earlier notes about remaining widget-build cost.

The book fix changes future gains; previously accumulated save stats are kept.
