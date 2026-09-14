# Apple Say

Apple Say is a native macOS application for working with text that will be spoken by the system `say` capability. This context defines the product language used when describing text, voices, timing, preview, and export.

## Language

**Apple Say**:
The macOS application described by this project.
_Avoid_: SayNative, AppleSay

**Document**:
The text currently being edited, spoken, imported, or exported by Apple Say. A Document may contain plain text, LRC, or Enhanced LRC content.
_Avoid_: Project, Note, Board

**Plain Text**:
Document content with no fully valid timed-text structure. Content that only partially resembles LRC is treated as Plain Text rather than guessed into a timed format.
_Avoid_: Raw Text, Normal Text

**LRC**:
Timed text in which the content lines form a valid LRC structure using line timestamps. A document is treated as LRC only when its timed structure is valid rather than merely containing timestamp-like text.
_Avoid_: Lyrics Mode, Timestamp Mode

**Enhanced LRC**:
LRC that also contains valid inline timing for words or text fragments.
_Avoid_: ELRC Mode, Word Mode

**Timed Text**:
The shared category for valid LRC and Enhanced LRC content.
_Avoid_: Subtitle File

**Segment**:
A unit of Timed Text associated with a start time and spoken content.
_Avoid_: Clip, Cue, Row

**Timed Fragment**:
A word or text fragment inside Enhanced LRC that carries its own inline timestamp within a Segment.
_Avoid_: Word Cue, Token, Subsegment

**Timestamp**:
A time value contained in Timed Text that constrains when a Segment or timed fragment begins.
_Avoid_: Marker, Timecode Marker

**Timing Error**:
A state where the requested speech cannot satisfy the timing constraints represented by the document. Apple Say reports the conflict instead of silently changing the text or moving timestamps.
_Avoid_: Overflow Fix, Auto Recovery

**Voice**:
A speech voice that macOS makes available for use by `say`.
_Avoid_: Speaker, Character

**System Voice**:
The default voice configured in macOS Accessibility Spoken Content settings. System Voice is a first-class voice selection in Apple Say. When selected, Apple Say invokes `/usr/bin/say` without an explicit `-v`, preserving the macOS Spoken Content system voice. This may enable Siri Natural voices on macOS versions where the system speech pipeline exposes them through the default voice path. Apple Say does not attempt to address Siri Natural voices explicitly through private identifiers or private frameworks.
_Avoid_: System Default, Default Voice

**Voice Language**:
The locale associated with a Voice and used to filter the Voice list. It does not independently change the language of the Document.
_Avoid_: Document Language, Translation Language

**Personal Voice**:
A user-created macOS Personal Voice that is available to Apple Say with the user's authorization.
_Avoid_: Custom Voice, Cloned Voice

**Speech Speed**:
The requested speaking rate for synthesis.
_Avoid_: Tempo

**Pitch**:
The requested baseline voice pitch adjustment.
_Avoid_: Tone

**Preview**:
Temporary speech playback used to hear the current Document and speech settings without creating an exported audio file.
_Avoid_: Render Preview

**Export**:
Creation of an audio file from the current Document using the selected speech and output settings.
_Avoid_: Save Audio, Render

**Add Voices**:
The user action that opens the macOS system interface for installing additional system voices.
_Avoid_: Download Voice

**Personal Voice Settings**:
The user action that opens the macOS system interface for managing Personal Voices and their permissions.
_Avoid_: Personal Voice Manager
