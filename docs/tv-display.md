# Game window and TV display

## Screen size

Little World opens maximized. Its 1600×900 reference layout scales to the window while keeping a 16:9 aspect ratio; differently shaped displays can have unused space around the game. The ordinary window can be resized down to 960×540.

Toggle fullscreen using **F11**, the Xbox **Menu (☰)** button, PlayStation **Options**, or the on-screen **Fullscreen** button. Toggle again to restore the previous maximized/windowed mode. Menu/Options does not join an extra player. macOS can take a moment to animate the fullscreen transition.

## Mac → Roku TV: share just Little World

Use the operating system's AirPlay window-sharing flow for the initial prototype. The app does not start broadcasting automatically, select a receiver, or implement a separate casting protocol.

1. On Roku, open **Settings → Apple AirPlay and HomeKit** and turn AirPlay on. If this setting is absent, check **Settings → System → About** for the model and Roku OS version. Compatibility depends on the model/software. [Roku compatibility and setup](https://support.roku.com/article/screen-mirror-your-apple-device-with-airplay)
2. Put the Mac and TV on the same network.
3. Open Little World. On the Mac, select **Control Center → Screen Mirroring → your Roku TV** and enter the TV's code if prompted.
4. Choose the option to **share a window**, then select **Little World**. When already sharing, use Screen Mirroring's **Change** control to change the selection. [Apple's AirPlay window-sharing instructions](https://support.apple.com/guide/mac-help/stream-video-and-audio-with-airplay-mchld7e543a0/mac)
5. Confirm the TV shows only the selected game window. Return focus to the game and press A / Cross on the controllers, which remain paired to the Mac.
6. Stop sharing through the Mac's Screen Mirroring controls when finished.

The development Mac runs macOS 27. Older versions and receiver combinations may present different choices. If window sharing is unavailable, an extended AirPlay display with the game moved onto it is another OS-managed path to evaluate. Direct HDMI is also supported as an ordinary external display.

## Verification and future platform integration

Verified locally: 16:9 rendering, native maximized startup, and controller-event fullscreen entry/exit on macOS ARM64. The existing SDK/scene test suite passes. TV hardware, window-only output, picture scaling, controller latency, and audio routing are **not yet verified** on the user's Roku.

For TV testing, record the Roku model/OS, network connection, Mac display mode, whether single-window sharing is offered, and noticeable delay while moving/jumping. Little World currently has no game audio, so it cannot validate audio routing yet.

A future platform “Play on TV” flow can guide receiver selection and keep display preferences with the host. Custom capture/encoding/transport is a separate project if OS sharing fails the latency or compatibility requirements; capturing a window alone does not provide a Roku receiver or prove playable latency.
