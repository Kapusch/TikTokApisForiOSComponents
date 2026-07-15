# Source mode

Source mode lets an application consume the managed project and already-built native assets from a sibling checkout. It does not download dependencies from the consuming app.

## Steps

1. Build native assets:

   ```sh
   bash src/Kapusch.TikTokApisForiOSComponents/Native/iOS/build.sh
   ```

2. Add a `ProjectReference` to `src/Kapusch.TikTokApisForiOSComponents/Kapusch.TikTokApisForiOSComponents.csproj`.
3. Import both `buildTransitive/Kapusch.TikTok.iOS.props` and `buildTransitive/Kapusch.TikTok.iOS.targets` from the checkout.
4. Set `UseKapuschTikTokIosInteropFromSource=true` in the consuming iOS project.

The source checkout must remain adjacent or be provided through an explicit MSBuild root property chosen by the consuming application.
