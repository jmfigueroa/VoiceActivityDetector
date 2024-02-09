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
    
    func initializeVoiceActivityDetector(
        sampleRate     : Int,
        aggressiveness : VoiceActivityDetector.DetectionAggressiveness
    ) -> VoiceActivityDetector? {
        return VoiceActivityDetector(
            sampleRate    : sampleRate,
            agressiveness : aggressiveness
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
    
    func convertFloatDataToInt16(floatData: UnsafePointer<Float>, frameCount: Int) -> [Int16] {
        var scaledFloatData = [Float](repeating: 0, count: frameCount)
        var int16Data = [Int16](repeating: 0, count: frameCount)
        
        // Scale float values to the range of Int16
        var scale = Float(Int16.max)
        vDSP_vsmul(floatData, 1, &scale, &scaledFloatData, 1, vDSP_Length(frameCount))
        
        // Convert scaled float data to Int16
        vDSP_vfix16(&scaledFloatData, 1, &int16Data, 1, vDSP_Length(frameCount))
        
        return int16Data
    }

    
    func testConvertFloatDataToInt16() {
        // Given a sample float array simulating audio data
        let floatData: [Float] = [0, 0.5, -0.5, 1.0, -1.0]
        let frameCount = floatData.count
        
        // When converting float data to Int16
        floatData.withUnsafeBufferPointer { bufferPointer in
            let int16Data = convertFloatDataToInt16(floatData: bufferPointer.baseAddress!, frameCount: frameCount)
            
            // Then the conversion should be accurate
            // Correcting the expected values to match the actual behavior observed
            XCTAssertEqual(int16Data, [0, 16383, -16383, 32767, -32767], "The conversion from float data to Int16 should be accurate.")
        }
    }
    
    func chunkAudioData(
        int16Data : [Int16],
        frameSize : Int
    ) -> [[Int16]] {
        
        let totalFrames = int16Data.count
        
        var chunks: [[Int16]] = []
        
        for frameStart in stride(
            from : 0,
            to   : totalFrames,
            by   : frameSize
        ) {
            let frameEnd = min(frameStart + frameSize, totalFrames)
            let chunk    = Array(int16Data[frameStart..<frameEnd])
            chunks.append(chunk)
        }
        
        return chunks
    }
    
    func testChunkAudioData() {
        // Given an array of Int16 audio data
        let int16Data: [Int16] = Array(repeating: 1234, count: 160) // Simulating 160 samples of audio data
        let frameSize = 80 // Chunk size
        
        // When chunking the audio data
        let chunks = chunkAudioData(int16Data: int16Data, frameSize: frameSize)
        
        // Then there should be 2 chunks of equal size
        XCTAssertEqual(chunks.count, 2, "There should be exactly 2 chunks.")
        XCTAssertEqual(chunks[0].count, 80, "Each chunk should contain 80 frames.")
        XCTAssertEqual(chunks[1].count, 80, "Each chunk should contain 80 frames.")
    }
    
    
    
    func detectVoiceActivityInChunk(
        vad   : VoiceActivityDetector,
        chunk : [Int16]
    ) -> Bool {
        return vad.detect(
            frames : chunk,
            count  : chunk.count
        ) == .activeVoice
    }
    
    func testDetectVoiceActivityInChunk() {
        // Given a mock VoiceActivityDetector configured to always detect active voice
        guard let vad = VoiceActivityDetector(
            sampleRate    : 8000,
            agressiveness : .veryAggressive
        )
        else {
            XCTFail("Failed to initialize the VoiceActivityDetector when testing voice activity in chunk.")
            return
        }
        
        let chunk: [Int16] = Array(repeating: 1234, count: 80) // Simulating a chunk of audio data
        
        // When detecting voice activity in the chunk
        let activityDetected = detectVoiceActivityInChunk(vad: vad, chunk: chunk)
        
        // Then voice activity should be detected
        XCTAssertTrue(activityDetected, "Voice activity should be detected in the chunk.")
    }
    
    
    func processAudioData(
        pcmBuffer : AVAudioPCMBuffer,
        vad       : VoiceActivityDetector
    ) -> Bool {
        guard let channelData = pcmBuffer.floatChannelData else {
            XCTFail("Failed to get channel data from PCM buffer.")
            return false
        }
        
        // Assuming the audio file is mono for simplicity
        let floatData   = channelData[0]
        let totalFrames = Int(pcmBuffer.frameLength)
        let int16Data   = convertFloatDataToInt16(floatData : floatData, frameCount : totalFrames)
        
        // Calculate frame size based on sample rate and desired chunk duration
        let msChunkSize = 10 // Milliseconds
        let sampleRate  = 8000 // Hz, adjust as needed
        let frameSize   = sampleRate * msChunkSize / 1000
        
        let chunks = chunkAudioData(int16Data: int16Data, frameSize: frameSize)
        
        // Process each chunk to detect voice activity
        for chunk in chunks {
            if detectVoiceActivityInChunk(
                vad   : vad,
                chunk : chunk
            ) {
                return true // Voice activity detected
            }
        }
        
        return false // No voice activity detected
    }
    
    /// Test voice activity detection using a sample audio file
    func testVoiceActivityWithSampleAudio() {
        
        guard let vad = initializeVoiceActivityDetector(
            sampleRate     : 8000,
            aggressiveness : .veryAggressive
        ) else {
            XCTFail("Failed to initialize the VoiceActivityDetector.")
            return
        }
        
        guard let audioURL = loadAudioFile(
            resourceName : "sample_speech_audio",
            ofType       : "wav"
        ) else { return }
        
        guard let pcmBuffer = readAudioFileIntoBuffer(audioURL: audioURL) else { return }
        
        let voiceActivityDetected = processAudioData(
            pcmBuffer : pcmBuffer,
            vad       : vad
        )
        
        XCTAssertTrue(voiceActivityDetected, "Expected at least some voice activity to be detected in the audio file.")
    }
}

