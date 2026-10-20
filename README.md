# Wanbo Dali 1 debloat

[Español](README.es.md)

Make the Wanbo Dali 1 projector usable for streaming: strip the factory bloat, replace the
ad-filled launcher, and get YouTube working again. Everything goes through network ADB, with no
flashing, no custom firmware and no writes to `/system`. Every change is reversible.

Tested on one unit in October 2026. If your firmware differs, check the inventory step before
running anything.

## The device

| | |
|---|---|
| Model | Wanbo Dali 1 (350 ANSI lumens, 720p native). Internal model `WPD11` |
| Firmware | `wanbo-WPD11-KCHE-V1.0.7-20241021`, Android 9, `ro.build.type=user` |
| SoC | HiSilicon Hi3751V350 (`bigfish`), 32-bit ARM (`armeabi-v7a`) |
| RAM / storage | 1 GB (plus ~310 MB zram) / 8 GB, of which ~2.8 GB is `/data` |
| Launcher | `com.zeasn.launcher` (Zeasn, built by Kystar), with an ad row |
| Google | Play Store and Play Services are included |

## Findings

- **`adb shell` runs as root** (`uid=0`, SELinux context `u:r:su:s0`) on the stock firmware, and
  `/system/xbin/su` is present. You get full access over ADB with no rooting needed.
  `ro.adb.secure=1`, so new hosts *should* need authorization. Whether that holds was not
  verified: the authorization dialog never showed up on screen during testing, yet the connection
  went through after an `adb kill-server`.
- **YouTube is blocked server-side.** The official app (even updated from 3.04 to 5.30) says
  "YouTube is not compatible with this device". The firmware reports the build fingerprint of a
  different board (`Mstar/CVTE_MSD338_512M/...:4.4.4`), so YouTube doesn't treat it as a certified
  device. [SmartTube](https://github.com/yuliskov/SmartTube) works fine and is what `apply.sh`
  installs. It also skips ads, which is against YouTube's terms. Your call.
- **Some factory apps restart even when disabled.** `com.sdt.factorytest`,
  `com.kystar.middleware.track` and `com.zeasn.deviceportal.asdprovider.kystar_hisi352` are flagged
  `PERSISTENT`, and this firmware starts them even with `enabled=3` (disabled-user).
  `pm uninstall -k --user 0` stops them for good while leaving the APK in `/system`.
- **`com.kystar.middleware.track` is an accessibility service** (`TopAppTrackingService`) that
  records which app is in the foreground. It is enabled out of the box.
- **Play Store re-enables a disabled YouTube on reboot.** `pm hide` makes it stick.
- **No hardware video encoder**, only `OMX.google.h264.encoder`, which runs in software. Screen
  mirroring with scrcpy works, but only at low resolution and fps (see below).
- Netflix, Disney+, Prime Video and Max work (Widevine L1). Netflix ships as the phone app
  (`com.netflix.mediaclient`), not the TV one.

Even after debloating, 1 GB of RAM is the real limit. If it's still too slow for you, a cheap
HDMI streaming stick will do more than any tweak.

## Quick start

You need `adb`, `curl` and `python3` on a computer on the same network.

1. On the projector: **Settings → About** → press **Build number** 7 times. Then in
   **Developer options** enable **USB debugging** and **Network debugging**. Note the IP shown in
   **Settings → Network**.
2. Connect and look around before changing anything:
   ```bash
   adb connect <ip>:5555
   adb devices                                   # should say "device", not "unauthorized"
   adb shell getprop ro.build.display.id         # compare with the firmware above
   adb shell pm list packages -s | sort          # compare with packages/stock-system.txt
   ```
   If it stays `unauthorized` and no dialog appears, run `adb kill-server` and connect again.
3. Run the script:
   ```bash
   ./apply.sh <ip>
   ```
   On the first run it opens Projectivy Launcher in Play Store. Install it, finish its welcome
   wizard with the remote, then run `./apply.sh <ip>` again. The second run makes Projectivy the
   Home app and disables the Wanbo launcher.
4. `adb reboot`.

## What gets changed

**Disabled** (`pm disable-user --user 0`, list in [packages/disabled.txt](packages/disabled.txt)):

| Group | Packages |
|---|---|
| Screen mirroring (AirPlay, EShare, Miracast) | `com.ecloud.eairplay`, `com.ecloud.emedia`, `com.ecloud.eshare.server`, `com.hisilicon.miracast` |
| Local media players and file browsers | `com.hisilicon.android.music`, `.videoplayer`, `com.hisilicon.higallery`, `com.hisilicon.explorer`, `com.kystar.projector.explorer` |
| Bluetooth speaker mode | `net.kystar.btspeaker` |
| Browsers | `com.android.chrome`, `com.android.browser`, `com.android.bookmarkprovider` |
| Factory test apps | `com.sdt.factorytest`, `com.kystar.projector.test.facteory` |
| Telemetry | `com.kystar.middleware.track` |
| Zeasn store, launcher and its content provider | `zeasn.open.technical.tv.store`, `com.zeasn.launcher`, `com.zeasn.deviceportal.asdprovider.kystar_hisi352` |
| Screensaver | `com.kystar.dream` |
| Wi-Fi hotspot | `com.kystar.wifiap` |
| First-run setup wizard | `com.kystar.projector.zeasn.setupwizard` |
| Unused AOSP leftovers | `com.android.soundrecorder`, `.bips`, `.emergency`, `.simappdialog`, `.mtp`, `.bluetoothmidiservice`, `.companiondevicemanager`, `.wallpaperbackup`, `.sharedstoragebackup`, `.onetimeinitializer`, `.statementservice`, `.providers.downloads.ui`, 3× `com.android.internal.display.cutout.emulation.*` |
| Official YouTube (blocked anyway, also hidden) | `com.google.android.youtube.tv` |

**Removed for user 0** (`pm uninstall -k --user 0`, [packages/removed-user0.txt](packages/removed-user0.txt)):
the three `PERSISTENT` apps listed under Findings.

**Settings:** animation scales from 0.5 to 0. `enabled_accessibility_services` cleared (the only
entry was the tracking service).

**Installed:** Projectivy Launcher (Play Store) and SmartTube (GitHub, sha256 checked).

If you use mirroring, USB playback or the speaker mode, remove those lines from
`packages/disabled.txt` before running the script.

**Left alone on purpose:** autofocus and keystone (`com.kystar.projector.focus`,
`com.kystar.focus.movecheck`), the remote (`com.kystar.bleconnect`, `com.hisilicon.rmservice`),
the HiSilicon TV/picture stack (`com.hisilicon.tv.*`, `com.hisilicon.tvui`,
`com.hisilicon.tvsetting`), projector settings (`com.kystar.projector.zeasn.settings`),
`com.ksd.framework` (unknown vendor service, not worth the risk), the keyboard, and Google Play
Services (Play Store and some streaming apps need it).

## Revert

```bash
adb connect <ip>:5555
for p in $(cat packages/removed-user0.txt); do adb shell cmd package install-existing $p; done
for p in $(cat packages/disabled.txt); do adb shell pm enable $p; done
adb shell pm unhide com.google.android.youtube.tv
adb shell cmd package set-home-activity com.zeasn.launcher/.ui.MainActivity
for k in window_animation_scale transition_animation_scale animator_duration_scale; do adb shell settings put global $k 0.5; done
adb reboot
```

`install-existing` goes first because those three packages are also in the disabled list. A
factory reset also undoes everything, since all changes live in `/data`.

## Watching the screen (scrcpy)

[scrcpy](https://github.com/Genymobile/scrcpy) works, but it has to use the software encoder:

```bash
scrcpy -s <ip>:5555 --video-encoder=OMX.google.h264.encoder --max-size=960 --max-fps=15 \
  --video-bit-rate=2M --no-audio
```

- No audio: scrcpy captures audio only on Android 11+.
- DRM apps (Netflix, Disney+, Prime) show black in the mirror and play normally on the projector.
- The projector slows down while mirroring. Close scrcpy when you're done.
- If you test `scrcpy-server` by hand: it deletes itself from `/data/local/tmp` on start, so you
  have to push it again each time. The scrcpy client does that for you.

## Troubleshooting

| Problem | Fix |
|---|---|
| Home button does nothing | `adb shell pm enable com.zeasn.launcher && adb shell cmd package set-home-activity com.zeasn.launcher/.ui.MainActivity` |
| A factory feature stopped working | Find its package above and run `pm enable <package>` |
| `adb connect` fails | Check that Network debugging is still on and that the IP hasn't changed. Reserve the IP in your router. Network ADB survives reboots |
| `unauthorized`, no dialog | `adb kill-server`, connect again |
| Turn off as if from the remote | `adb shell input keyevent KEYCODE_POWER` (the network drops after ~10 s) |

## Security note

With network debugging on, ADB gives root access to anyone who is authorized on the projector,
and authorization could not be confirmed to work on this firmware (see Findings). Turn
**Network debugging** off when you're done, or keep the projector on a network you trust.

## Disclaimer

Not affiliated with Wanbo. It worked on one unit with the firmware above. Use it at your own risk.

## License

[MIT](LICENSE)
