# Personal Voice authorization and audio capture

Apple Say requests its own permission through the public
`AVSpeechSynthesizer.requestPersonalVoiceAuthorization` API. AVFAudio also supplies
the Personal Voice trait and locale metadata. It never synthesizes speech for this
application. The available Personal Voices are intersected with the `say` catalog;
all playback and synthesis continue through `/usr/bin/say`.

Apple's public authorization enum currently distinguishes not determined, denied,
unsupported, and authorized. There is no separate restricted value. The application
boundary also represents restricted access for substituted systems and unknown
future authorization states. Returning from System Settings refreshes authorization
and the available Voice catalog.

Export first tries `say` native file output. When that route explicitly cannot
produce Personal Voice audio, the application can record the exact child process
through a private Core Audio process tap. Capture starts before the child receives
any Document text. The private aggregate device auto-starts with the tapped audio;
its asynchronous writer stores genuine PCM in a temporary CAF for the common audio
timeline/conversion path. Non-finite samples, writer failures, empty output, and
all-zero output are failures. The recorder never expands its target to other
processes or the system mix and does not manufacture a silent success artifact.

The runtime probes audio process identification, tap creation, PCM format, aggregate
device creation, and actual capture output. The API availability guard is necessary
for loading on macOS 14.0; it does not by itself claim capture support. If macOS
does not register the child before input, isolates speech in another process,
denies audio capture, or otherwise prevents this route, Export fails with a clear
error. Ordinary Voice operations continue to work.

`PersonalVoiceCapability` exposes the result without leaking the export mechanism
into the main workflow. Authorization and the Voice catalog establish unavailable,
permission-required, ready, or unsupported states. The first real Personal Voice
Export then records native export, compatibility export, or playback-only capability.
The inspector reports the useful product behavior and does not mention process taps.

`NSPersonalVoiceUsageDescription` and `NSAudioCaptureUsageDescription` must be in
the application bundle. The latter allows macOS to request system audio recording
permission for Apple Say when the compatibility capture route is first used. Run
permission and audio tests from the built app, not a Terminal-hosted executable.

## Why this boundary

The reference project
[limneos/SavePersonalVoiceAudio](https://github.com/limneos/SavePersonalVoiceAudio)
demonstrates capturing audio at the system render boundary, but injects a dylib
into `say` and includes a Terminal authorization helper. Apple Say adopts neither
mechanism. Its independent implementation uses Apple's documented public process
tap API and app authorization. There is no injected library, copied system
executable, installed helper, alternative speech engine, microphone capture, or
security-setting modification.

On macOS 26.6.2 (build 25G83), a constructor-marker dylib supplied through
`DYLD_INSERT_LIBRARIES` was not loaded by the Apple-platform `/usr/bin/say` binary,
while the same command still produced an ordinary Voice AIFF file. The Sonoma-era
interpose path therefore cannot serve as Apple Say's Tahoe compatibility layer.
This is a direct capability result rather than a version-number assumption.

Primary documentation:

- [Apple: Capture system audio using Core Audio taps](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps)
- [Apple: Personal Voice authorization](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer/requestpersonalvoiceauthorization(completionhandler:))
- The active macOS SDK's `CATapDescription.h`, `AudioHardware.h`, and
  `AVSpeechSynthesis.h` specify process scoping, tap auto-start, asynchronous I/O,
  voice traits, and authorization states.

## Validation

Automated orchestration tests exercise native success, native unavailability,
capture success, capture unavailability, capture failure, authorization states,
and composition with Timed Text using the same substitutable speech boundary.
The development machine also confirms that a real `say` child registers a Core
Audio process before standard input is released; this probe produces no speech
and requests no capture permission. A signed build completed real-device
acceptance on macOS 26.6.2, covering Preview, native Export, compatibility
capture, LRC and Enhanced LRC placement, rate fitting, and Timing Error
reporting.

## Pre-release verification on a new machine

1. Listen to the complete native and captured artifacts and verify the first and
   last words. Compare
   the capture against a simultaneous unrelated audio source to confirm that the
   unrelated source is absent.
2. Revoke system audio recording permission and retry a capture-required Export.
   Confirm a clear failure, no output artifact, and unaffected ordinary Preview.
3. Export LRC and Enhanced LRC with leading and inter-unit silence, then inspect
   absolute placement and rate-fitting behavior. Confirm the first and last words
   of every unit are present and the source remains the selected Personal Voice.
4. Stop during process preparation and during recording. Confirm playback stops,
   the partial artifact is removed, and the next Preview works normally.
