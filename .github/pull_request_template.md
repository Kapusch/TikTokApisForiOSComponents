## Summary

- What does this change do?

## Checklist

- [ ] No client keys, redirect URIs, signing material, or secrets committed
- [ ] Built native assets: `bash src/Kapusch.TikTokApisForiOSComponents/Native/iOS/build.sh`
- [ ] Packed NuGet: `dotnet pack src/Kapusch.TikTokApisForiOSComponents/Kapusch.TikTokApisForiOSComponents.csproj -c Release -o artifacts/nuget`
- [ ] Validated package: `scripts/validate-package.sh`
- [ ] Updated dependency lock and notices if upstream inputs changed
- [ ] Updated docs if behavior or integration changed
