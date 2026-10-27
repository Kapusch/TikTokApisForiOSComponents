# Samples

- `Kapusch.TikTok.iOS.Sample` documents the smallest UIKit integration surface of the Share
  package without committing credentials. Copy its template values locally, register a TikTok
  development application, and provide real Photos local identifiers before runtime testing.
  TikTok editor handoff requires an approved app and a physical device.
- `Kapusch.TikTok.Business.iOS.Sample` is a buildable UIKit app for the Business package in
  source mode. It initializes the SDK only after a consent tap. Its credentials live in an
  untracked `Info.plist` created from `Info.template.plist`. CI links it for the simulator and
  for an unsigned device build.
