#include "AppleSayAudioBridge.h"

OSStatus AppleSayCommitExtAudioFileConverter(ExtAudioFileRef file, AudioConverterRef converter) {
    CFArrayRef configuration = NULL;
    UInt32 size = sizeof(configuration);
    OSStatus status = AudioConverterGetProperty(converter, kAudioConverterPropertySettings,
                                                &size, &configuration);
    if (status != noErr) return status;
    status = ExtAudioFileSetProperty(file, kExtAudioFileProperty_ConverterConfig,
                                     sizeof(configuration), &configuration);
    if (configuration != NULL) CFRelease(configuration);
    return status;
}
