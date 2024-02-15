import XCTest
import AVFAudio
import CoreMedia
import Accelerate

@testable import VoiceActivityDetector

final class VoiceActivityDetectorTests: XCTestCase {
    
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
        vad.aggressiveness = .veryAggressive
        XCTAssertEqual(
            vad.aggressiveness,
            .veryAggressive,
            "Aggressiveness should be set to .veryAggressive"
        )
    }
    
    func testSampleRateSetting() {
        guard let vad = VoiceActivityDetector() else {
            XCTFail("Failed to initialize the VoiceActivityDetector.")
            return
        }
        
        // Attempt to set a valid sample rate
        vad.sampleRate = 16000
        XCTAssertEqual(
            vad.sampleRate,
            16000,
            "Sample rate should be set to 16000"
        )
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
    
    func initializeVoiceActivityDetector(
        sampleRate     : Int,
        aggressiveness : VoiceActivityDetector.DetectionAggressiveness
    ) -> VoiceActivityDetector? {
        return VoiceActivityDetector(
            sampleRate    : sampleRate,
            aggressiveness : aggressiveness
        )
    }
    
    func loadAudioFile(
        resourceName : String,
        ofType type  : String
    ) -> URL? {
        guard let path = Bundle.module.path(
            forResource: resourceName,
            ofType: type
        )
        else {
            XCTFail("Failed to find the audio file.")
            return nil
        }
        return URL(fileURLWithPath: path)
    }
    
    func readAudioFileIntoBuffer(audioURL: URL) -> AVAudioPCMBuffer? {
        do {
            let file = try AVAudioFile(forReading: audioURL)
            guard let pcmBuffer = AVAudioPCMBuffer(
                pcmFormat     : file.processingFormat,
                frameCapacity : AVAudioFrameCount(file.length)
            )
            else {
                XCTFail("Failed to create PCM buffer.")
                return nil
            }
            try file.read(into: pcmBuffer)
            return pcmBuffer
        } catch {
            XCTFail("Error opening or reading audio file: \(error)")
            return nil
        }
    }
    
    
    func testConvertFloatDataToInt16() {
        // Given a sample float array simulating audio data
        let floatData: [Float] = [0, 0.5, -0.5, 1.0, -1.0]
        let frameCount = floatData.count
        
        // When converting float data to Int16
        let int16Data = VoiceActivityDetector.convertFloatDataToInt16(floatData: floatData, frameCount: frameCount)
        
        // Then the conversion should be accurate
        XCTAssertEqual(
            int16Data,
            [0, 16383, -16383, 32767, -32767],
            "The conversion from float data to Int16 should be accurate."
        )
    }
    
    func testChunkAudioData() {
        // Given an array of Int16 audio data
        let int16Data: [Int16] = Array(repeating: 1234, count: 160) // Simulating 160 samples of audio data
        let frameSize = 80 // Chunk size
        
        // When chunking the audio data
        
        do {
            let chunks = try VoiceActivityDetector.chunkAudioData(int16Data: int16Data, frameSize: frameSize)
            
            // Then there should be 2 chunks of equal size
            XCTAssertEqual(chunks.count,    2,  "There should be exactly 2 chunks.")
            XCTAssertEqual(chunks[0].count, 80, "Each chunk should contain 80 frames.")
            XCTAssertEqual(chunks[1].count, 80, "Each chunk should contain 80 frames.")
        }
        catch { XCTFail("Error chunking audio data: \(error)") }
    }
    
    
    func testDetectVoiceActivityInChunk() {
        // Given a mock VoiceActivityDetector configured to always detect active voice
        guard let vad = VoiceActivityDetector(
            sampleRate     : 8000,
            aggressiveness : .veryAggressive
        )
        else {
            XCTFail("Failed to initialize the VoiceActivityDetector when testing voice activity in chunk.")
            return
        }
        
        // Simulate a chunk of audio data that matches the expected frame size for 10 ms at 8000 Hz
        let frameSize = vad.sampleRate / 100 // This should be 80 for 10 ms at 8 kHz
        let chunk: [Int16] = Array(repeating: 1234, count: frameSize)
        
        // When detecting voice activity in the chunk
        do {
            let activityDetected = try VoiceActivityDetector.detectVoiceActivityInChunk(vad: vad, chunk: chunk)
            
            // Then voice activity should be detected
            XCTAssertTrue(activityDetected, "Voice activity should be detected in the chunk.")
        }
        catch { XCTFail("Error detecting voice activity in chunk: \(error)") }
    }

    
    
    /// Test voice activity detection using a sample audio file
    func testVoiceActivityWithSampleAudio() {
        
        guard let vad = VoiceActivityDetector(
            sampleRate     : 8000,
            aggressiveness : .veryAggressive
        ) else {
            XCTFail("Failed to initialize the VoiceActivityDetector.")
            return
        }
        
        guard let audioURL = Bundle.module.url(
            forResource: "sample_speech_audio",
            withExtension: "wav"
        ) else {
            XCTFail("Failed to find the audio file.")
            return
        }
        
        guard let pcmBuffer = try? VoiceActivityDetector.readAudioFileIntoBuffer(audioURL: audioURL) else {
            XCTFail("Failed to read the audio file into buffer.")
            return
        }
        
        do {
            let voiceActivityDetected = try VoiceActivityDetector.processAudioData(
                pcmBuffer: pcmBuffer,
                vad: vad
            )
            
            XCTAssertTrue(voiceActivityDetected, "Expected at least some voice activity to be detected in the audio file.")
        }
        catch { XCTFail("Error processing audio data: \(error)") }
    }
}

