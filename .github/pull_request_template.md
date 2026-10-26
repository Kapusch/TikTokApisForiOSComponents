## Summary

- What does this change do?
- Which package does it affect: `Kapusch.TikTok.iOS` (Share), `Kapusch.TikTok.Business.iOS` (Business), or both?

## Checklist

- [ ] No client keys, redirect URIs, App IDs, App Secrets, signing material, or secrets committed
- [ ] Built native assets (`src/<project>/Native/iOS/build.sh`) for every affected package
- [ ] Packed and validated every affected package (`scripts/validate-package.sh`, `scripts/validate-business-package.sh`)
- [ ] `scripts/check-native-symbol-collisions.sh` and `python3 -I scripts/verify-public.py` pass
- [ ] Updated dependency lock and notices if upstream inputs changed
- [ ] Updated docs if behavior or integration changed
