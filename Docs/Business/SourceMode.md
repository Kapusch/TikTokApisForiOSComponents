# Business package source mode

Source mode lets an application consume `Kapusch.TikTok.Business.iOS` from a sibling
checkout with already-built native assets. The consuming app still downloads nothing.

1. Build the native assets:

   ```sh
   bash src/Kapusch.TikTok.Business.iOS/Native/iOS/build.sh
   ```

2. Add a `ProjectReference` to `src/Kapusch.TikTok.Business.iOS/Kapusch.TikTok.Business.iOS.csproj`.
3. Import `src/Kapusch.TikTok.Business.iOS/buildTransitive/Kapusch.TikTok.Business.iOS.props`
   and `.targets` from the checkout.
4. Set `UseKapuschTikTokBusinessIosInteropFromSource=true` in the consuming iOS project.

[`samples/Kapusch.TikTok.Business.iOS.Sample`](../../samples/Kapusch.TikTok.Business.iOS.Sample)
is wired this way.
