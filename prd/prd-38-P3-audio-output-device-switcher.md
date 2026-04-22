# PRD-38 (P3): Audio output device switcher

## Problem
When headphones or a Bluetooth speaker are connected, audio routes to that device automatically. There is no in-app way to redirect playback to the device speaker without physically disconnecting the headphones — a common need when a user wants to share audio or switch mid-listen. WhatsApp and Spotify both solve this with a small speaker icon that toggles or presents a device picker.

## Evidence
- `AudioVaultHandler` does not interact with platform audio routing APIs
- `PlayerScreen` AppBar has no output-device control
- No `just_audio` or `audio_service` API currently used for device routing

## Proposed Solution
Add a speaker/headphone icon button to the `PlayerScreen` AppBar that is visible only when a non-default audio output is active (headphones or Bluetooth connected). Tapping it opens a bottom sheet listing available output devices; tapping a device routes audio to it immediately.

Platform implementation:
- **Android** — use `AudioManager` via a thin `MethodChannel` to enumerate and select audio output devices (`getDevices(GET_DEVICES_OUTPUTS)` / `setCommunicationDevice` or `AudioFocusRequest` routing). On Android 12+ use `AudioManager.setPreferredDevice` on the `AudioTrack`.
- **iOS** — use `AVAudioSession.currentRoute` and `AVAudioSession.overrideOutputAudioPort(.speaker)` / `.none` via a `MethodChannel`.

The feature degrades gracefully: if the platform channel is unavailable or returns an error, the button is hidden.

## Acceptance Criteria
- [ ] Speaker icon appears in `PlayerScreen` AppBar when headphones or Bluetooth audio output is connected
- [ ] Icon reflects current output (headphone icon when routed to headphones, speaker icon when routed to speaker)
- [ ] Tapping the icon opens a bottom sheet listing available output devices by name
- [ ] Selecting a device routes audio to it without interrupting playback
- [ ] Button is hidden when only the built-in speaker is available (no external device connected)
- [ ] Works on Android 8+ and iOS 14+
- [ ] Graceful no-op if platform channel call fails

## Out of Scope
- Chromecast / Cast routing (handled by `CastController`)
- Bluetooth device pairing or system settings navigation
- Volume control per device

## Implementation Plan
1. Create `lib/services/audio_output_service.dart` — a service that wraps a `MethodChannel('com.mattsteed.audiovault/audio_output')` with:
   - `Future<List<AudioOutputDevice>> getDevices()` — returns name + id + type (speaker / wired / bluetooth)
   - `Future<void> selectDevice(String deviceId)`
   - `Stream<List<AudioOutputDevice>> get devicesStream` — emits when connected devices change
2. Create `lib/models/audio_output_device.dart` — simple value class: `id`, `name`, `type` (enum: speaker, wiredHeadphones, bluetooth).
3. Android (`android/app/src/main/kotlin/.../MainActivity.kt`): implement the channel using `AudioManager`. Register a `BroadcastReceiver` for `ACTION_HEADSET_PLUG` and `ACTION_ACL_CONNECTED`/`DISCONNECTED` to push device-list updates via an `EventChannel`.
4. iOS (`ios/Runner/AppDelegate.swift`): implement the channel using `AVAudioSession`. Observe `AVAudioSession.routeChangeNotification` to push updates.
5. In `PlayerScreen`, listen to `AudioOutputService.devicesStream`. Show the AppBar icon only when `devices.length > 1` (i.e. a non-speaker option exists). Icon: `Icons.headphones` when routed to headphones/BT, `Icons.volume_up` when routed to speaker.
6. Create `lib/widgets/audio_output_sheet.dart` — a `DraggableScrollableSheet` listing devices with a leading icon per type and a checkmark on the active device. Tapping calls `AudioOutputService.selectDevice()` and pops the sheet.
7. Register `AudioOutputService` in `locator.dart`.
8. Unit tests for `AudioOutputDevice` model and `AudioOutputService` mock responses.
9. Manual test matrix: wired headphones connect/disconnect, Bluetooth connect/disconnect, select speaker while BT connected, kill app and reopen with BT connected.

## Files Impacted
- `lib/models/audio_output_device.dart` (new)
- `lib/services/audio_output_service.dart` (new)
- `lib/widgets/audio_output_sheet.dart` (new)
- `lib/screens/player_screen.dart` (AppBar icon + sheet launcher)
- `lib/locator.dart` (register service)
- `android/app/src/main/kotlin/com/mattsteed/audiovault/MainActivity.kt` (MethodChannel + EventChannel)
- `ios/Runner/AppDelegate.swift` (MethodChannel + NotificationCenter observer)
- `test/services/audio_output_service_test.dart` (new)
- `CHANGELOG.md`
