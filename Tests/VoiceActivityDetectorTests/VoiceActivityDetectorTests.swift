import XCTest
import AVFAudio
import Accelerate

@testable import VoiceActivityDetector

final class VoiceActivityDetectorTests: XCTestCase {
    
    /// Load audio data from a file and convert it to Int16 samples
    func loadAudioDataAsInt16(from url: URL) -> [Int16]? {
        do {
            // Initialize an audio file
            let file = try AVAudioFile(forReading: url)
            
            // Create a buffer to hold audio data in floating-point format
            let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: file.fileFormat.sampleRate, channels: file.fileFormat.channelCount, interleaved: false)!
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length))!
            
            // Read the entire file into the buffer
            try file.read(into: buffer)
            
            // Check if buffer has float channel data
            guard let channelData = buffer.floatChannelData else {
                print("Failed to read audio data")
                return nil
            }
            
            // Prepare for conversion: Allocate memory for Int16 samples
            var audioSamples = [Int16](repeating: 0, count: Int(buffer.frameLength))
            
            // Convert the float samples to Int16 using Accelerate
            let floatBufferPointer = UnsafeBufferPointer(start: channelData[0], count: Int(buffer.frameLength))
            vDSP_vfix16(floatBufferPointer.baseAddress!, 1, &audioSamples, 1, vDSP_Length(buffer.frameLength))
            
            return audioSamples
        } catch {
            print("Error loading audio data: \(error)")
            return nil
        }
    }
    
    func testDetectorInitialization() {
        let vad = VoiceActivityDetector()
        XCTAssertNotNil(vad, "The detector should successfully initialize.")
    }
    
    func testAggressivenessSetting() {
        guard let vad = VoiceActivityDetector() else {
            XCTFail("Failed to initialize the VoiceActivityDetector.")
            return
        }
        
        // Test setting to a valid aggressiveness mode
        vad.agressiveness = .veryAggressive
        XCTAssertEqual(vad.agressiveness, .veryAggressive, "Aggressiveness should be set to .veryAggressive")
    }
    
    func testSampleRateSetting() {
        guard let vad = VoiceActivityDetector() else {
            XCTFail("Failed to initialize the VoiceActivityDetector.")
            return
        }
        
        // Attempt to set a valid sample rate
        vad.sampleRate = 16000
        XCTAssertEqual(vad.sampleRate, 16000, "Sample rate should be set to 16000")
    }
    
    func testListFilesInBundle() {
        let bundle = Bundle.main
        if let path = bundle.resourcePath {
            let enumerator = FileManager.default.enumerator(atPath: path)
            while let filename = enumerator?.nextObject() as? String {
                print(filename)
            }
        }
    }
    
    /*
    /// Test voice activity detection using a sample audio file
    func testVoiceActivityWithSampleAudio() {
        guard let vad = VoiceActivityDetector() 
        else {
            XCTFail("Failed to initialize the VoiceActivityDetector.")
            return
        }
        
        
        let bundle = Bundle.module
        guard let audioURL = bundle.url(
            forResource   : "sample_speech_audio",
            withExtension : "wav"
        )
        else {
            XCTFail("Failed to locate the sample audio file.")
            return
        }
        
        
        guard let audioData = loadAudioDataAsInt16(from: audioURL)
        else {
            XCTFail("Failed to load audio data from the file.")
            return
        }
        
        // Calculate the number of valid frames within the audio data
        let frameSize = VoiceActivityDetector.Duration.msec10.rawValue * vad.sampleRate / 1000
        let numberOfFullFrames = audioData.count / frameSize
        
        // Process each full frame
        var voiceActivityDetected = false
        for i in 0..<numberOfFullFrames {
            let frameStartIndex = i * frameSize
            let frame = Array(audioData[frameStartIndex..<frameStartIndex + frameSize])
            if vad.detect(frames: frame, count: frameSize) == .activeVoice {
                voiceActivityDetected = true
                break
            }
        }
        
        // If voice activity is not detected in the full frames, and there are remaining samples, process them.
        if !voiceActivityDetected {
            let remainingSamples = audioData.count % frameSize
            if remainingSamples > 0 {
                var lastFrame = Array(audioData[numberOfFullFrames * frameSize..<audioData.count])
                // Pad the remaining samples to create a full frame, if needed
                lastFrame.append(contentsOf: repeatElement(0, count: frameSize - remainingSamples))
                if vad.detect(frames: lastFrame, count: frameSize) == .activeVoice {
                    voiceActivityDetected = true
                }
            }
        }
        
        XCTAssertTrue(voiceActivityDetected, "Expected at least some voice activity to be detected in the audio file.")
    }
     */
}


