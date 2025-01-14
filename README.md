# WebRTC based voice activity detection

[![CI Status](https://img.shields.io/travis/reedom/VoiceActivityDetector.svg?style=flat)](https://travis-ci.org/reedom/VoiceActivityDetector)
[![Version](https://img.shields.io/cocoapods/v/VoiceActivityDetector.svg?style=flat)](https://cocoapods.org/pods/VoiceActivityDetector)
[![License](https://img.shields.io/cocoapods/l/VoiceActivityDetector.svg?style=flat)](https://cocoapods.org/pods/VoiceActivityDetector)
[![Platform](https://img.shields.io/cocoapods/p/VoiceActivityDetector.svg?style=flat)](https://cocoapods.org/pods/VoiceActivityDetector)

This is a Swift/Objective-C interface to the WebRTC Voice Activity Detector (VAD).

A VAD classifies a piece of audio data as being voiced or unvoiced. It can be useful for telephony and speech recognition.

The VAD that Google developed for the WebRTC project is reportedly one of the best available, being fast, modern and free.

## Sample data format

The VAD engine simply work only with singed 16 bit, single channel PCM.

Supported bitrates are:
- 8000Hz
- 16000Hz
- 32000Hz
- 48000Hz

Note that internally all processing will be done 8000Hz.
input data in higher sample rates will just be downsampled first.

## Usage

```swift
import VoiceActivityDetector

let voiceActivityDetector = VoiceActivityDetector(sampleRate: 8000,
                                                  aggressiveness: .veryAggressive)

func didReceiveSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
  // activities: [VoiceActivityDetector.VoiceActivityInfo]?
  let activities = voiceActivityDetector(sampleBuffer: sampleBuffer, byEachMilliSec: 10)!

  // ...
}
```

For usage with a microphone, see [Example](Example/VoiceActivityDetector/ViewController.swift).
And against an audio file, see [Test code](Example/Tests/Tests.swift).

## API

### Constructors

```swift
init?()
convenience init?(sampleRate: Int = 8000, aggressiveness: Detectionaggressiveness = .quality)
convenience init?(aggressiveness: Detectionaggressiveness = .quality) {
```

Instanciate VoiceActivityDetector.

### Properties

```swift
var aggressiveness: Detectionaggressiveness
```

VAD operating "aggressiveness" mode.

- `.quality`
  The default value; normal voice detection mode. Suitable for high bitrate, low-noise data.
  May classify noise as voice, too.
- `.lowBitRate`
  Detection mode optimised for low-bitrate audio.
- `.aggressive`
  Detection mode best suited for somewhat noisy, lower quality audio.
- `.veryAggressive`
  Detection mode with lowest miss-rate. Works well for most inputs.

```swift
var sampleRate: Int
```

Sample rate in Hz for VAD operations.  
Valid values are 8000, 16000, 32000 and 48000. The default is 8000.

Note that internally all processing will be done 8000Hz.
input data in higher sample rates will just be downsampled first.

### Functions

```swift
func reset()
```

Reinitializes a VAD instance, clearing all state and resetting mode and
sample rate to defaults.

```swift
func detect(frames: UnsafePointer<Int16>, count: Int) -> VoiceActivity
```

Calculates a VAD decision for an audio duration.

`frames` is an array of signed 16-bit samples.  
`count` specifies count of frames.
Since internal processor supports only counts of 10, 20 or 30 ms,
so for example at 8 kHz, `count` must be either 80, 160 or 240.

Returns a VAD decision.

Under the hood, the VAD engine calculates energy powers in six frequency bands between 80-4KHz from signal data flow and guesses chance of voice activity state in a input duration. So, its decision should be more accurate by sequencial detection than one-shot or periodic ones.

```swift
func detect(frames: UnsafePointer<Int16>, lengthInMilliSec ms: Int) -> VoiceActivity
```

`ms` specifies processing duration in milliseconds.  
The should be either 10, 20 or 30 (ms).

```swift
  public func detect(sampleBuffer: CMSampleBuffer,
                     byEachMilliSec ms: Int,
                     offset: Int = 0,
                     duration: Int? = nil) -> [VoiceActivityInfo]? {
```
Calculates VAD decisions among a sample buffer.

`sampleBuffer` is an audio buffer to be inspected.  
`ms` specifies processing duration in milliseconds.  
`offset` controlls offset time in milliseconds from where to start VAD.  
`duration` controlls total VAD duration in milliseconds.  

Returns an array of VAD decision information.

- `timestamp: Int`
  Elapse time from the beginning of the sample buffer, in milliseconds.
- `presentationTimestamp: CMTime`
  This is `CMSampleBuffer.presentationTime` + `timestamp`, which may represent
  a timestamp in entire of a recording session.
- `voiceActivity: VoiceActivity`
  a VAD decision.


## Optional Utilities

The `VoiceActivityDetector` now includes a set of optional static utility functions that can be used independently for various tasks related to voice activity detection. These utilities make it easier to read audio files, convert audio data, chunk audio samples, and detect voice activity within those chunks and are designed to be convenient and optional for developers who may only need specific functionalities.

### Audio File Reading

```swift
public static func readAudioFileIntoBuffer(audioURL: URL) throws -> AVAudioPCMBuffer
```
Reads an audio file and creates an `AVAudioPCMBuffer`. It throws an error if the file cannot be read or the buffer cannot be created.

### Audio Data Conversion

```swift
public static func convertFloatDataToInt16(floatData: UnsafePointer<Float>, frameCount: Int) -> [Int16]
```
Converts floating-point audio samples to 16-bit signed integer samples, suitable for voice activity detection. Values outside the range of -1.0 to 1.0 will be clipped to avoid distortion.

### Audio Data Chunking

```swift
public static func chunkAudioData(int16Data: [Int16], frameSize: Int) throws -> [[Int16]]
```
Divides an array of 16-bit integer audio samples into chunks of a specified frame size, throwing an error if the `frameSize` is not a positive integer.

### Voice Activity Detection in Chunk

```swift
public static func detectVoiceActivityInChunk(vad: VoiceActivityDetector, chunk: [Int16]) throws -> Bool
```
Detects voice activity within a chunk of audio data, throwing an error if the chunk size does not match the expected frame size for the current sample rate.

### Process Audio Data

```swift
public static func processAudioData(pcmBuffer: AVAudioPCMBuffer, vad: VoiceActivityDetector, msChunkSize: Int = 10, sampleRate: Int = 8000) throws -> Bool
```
Processes an entire `AVAudioPCMBuffer` to detect voice activity, returning a boolean indicating detection. It throws an error if the audio data cannot be processed or the chunk size does not match the expected frame size.



## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Installation

VoiceActivityDetector is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'VoiceActivityDetector'
```

## Testing
All tests passing.

## To Do

### VoiceActivityDetector Enhancements

- [X] **Integrate Conversion Utility Functions**: Update the `VoiceActivityDetector` to include the conversion utility functions currently showcased in the `testVoiceActivityWithSampleAudio` test. These are for ease of use and not necessary for every workflow.


### Example Application Development

- [ ] **Create SwiftUI Example Application**: Develop a new example application using SwiftUI that demonstrates how to implement the `VoiceActivityDetector` in a modern iOS/macOS app.

- [ ] **Document SwiftUI Integration**: Provide detailed documentation within the example application on integrating the `VoiceActivityDetector` with SwiftUI, including setup instructions and best practices.


### Testing and Documentation

- [X] **Update Unit Tests**: Revise existing unit tests to cover the newly integrated conversion utilities within the `VoiceActivityDetector`, ensuring that all components work seamlessly together.

- [ ] **Add SwiftUI Example Tests**: Implement unit and UI tests for the SwiftUI example application to ensure reliability and demonstrate testing strategies for apps using the `VoiceActivityDetector`.



## Fork

This repository is a fork of [VoiceActivityDetector](https://github.com/JioMeet/VoiceActivityDetector) by JioMeet and includes C files and tests.
Original fork by JioMeet added SPM support and was forked from reedom's [reedom/VoiceActivityDetector](https://github.com/reedom/VoiceActivityDetector).


## Author/Contributors

[reedom](https://github.com/reedom)
[JioMeet](https://github.com/JioMeet)
[JMFigueroa](https://github.com/jmfigueroa)

## License

VoiceActivityDetector is available under the MIT license. See the LICENSE file for more info.
