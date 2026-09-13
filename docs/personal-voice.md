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

## Real-device verification

Automated orchestration tests exercise native success, native unavailability,
capture success, capture unavailability, capture failure, authorization states,
and composition with Timed Text using the same substitutable speech boundary.
The macOS development machine also verified that a real `say` child registers a
Core Audio process before standard input is released. This probe produced no
speech and requested no capture permission.

A signed Apple Say build on macOS 26.6.2 was authorized for the local `David 中文`
Personal Voice. Preview completed through the selected Voice. Native Export
produced a non-silent 2.425-second AIFF with 53,480 frames and a 0.6866 peak.

To exercise the compatibility route on a system where native output now works,
a temporary uncommitted verification build forced native output to report
unavailable. The process tap then produced a non-silent 2.656-second AIFF with
117,130 frames, 106,084 samples above 0.0001, and a 0.6938 peak. The forcing code was
removed before the release build. This verifies real Personal Voice capture and
conversion without shipping a test switch or alternate product path.

The final signed build also completed Timed Text acceptance using the same local
Personal Voice. LRC Preview completed, and Export produced a 4.4695-second AIFF;
signal began at 1.0003 seconds and again at 3.5017 seconds for requested Timestamps
of 1.00 and 3.50 seconds. Enhanced LRC Preview completed, and Export produced a
4.4569-second AIFF whose three speech units began at 1.0056, 2.2000, and 4.0272
seconds for requested Timed Fragment and Segment positions of 1.00, 2.20, and 4.00
seconds.

Real rate fitting used a sentence whose natural 175-words-per-minute Personal Voice
render lasted 2.2273 seconds. A 1.70-second LRC window caused the orchestration to
retry at 234 words per minute; the fitted signal lasted 1.6585 seconds and the next
Segment remained at 2.70 seconds. An impossible 10-millisecond LRC window reported a
Timing Error for line 1. The equivalent Enhanced LRC case identified line 1, Timed
Fragment 1. Neither case published audio or moved a Timestamp.

Before release across additional machines, repeat these environmental checks:

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
