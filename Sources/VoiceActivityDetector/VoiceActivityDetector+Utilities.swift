import Foundation
import AVFoundation
import Accelerate

// MARK: - Utilities

extension VoiceActivityDetector {
    
    
    /// Reads an audio file from a specified URL and creates an audio PCM buffer.
    ///
    /// **Note:** This utility function is provided for convenience and is optimized for reading
    ///  audio files that are processed by the VoiceActivityDetector. The buffer is set to the
    ///  file's original processing format. If the processing format has a different sample rate,
    ///  ensure to handle resampling separately to match the VAD's operating sample rate of 8000 Hz.
    ///
    /// - Parameter audioURL: The URL of the audio file to be read.
    /// - Returns: An `AVAudioPCMBuffer` containing the audio data.
    /// - Throws: An error of type `Error` if the file could not be read or the buffer could not be created.
    public static func readAudioFileIntoBuffer(audioURL: URL) throws -> AVAudioPCMBuffer {
        do {
            let file = try AVAudioFile(forReading: audioURL)
            
            guard let pcmBuffer = AVAudioPCMBuffer(
                pcmFormat     : file.processingFormat,
                frameCapacity : AVAudioFrameCount(file.length)
            )
            else {
                throw NSError(
                    domain   : "VoiceActivityDetectorError",
                    code     : -1,
                    userInfo : [NSLocalizedDescriptionKey : "Failed to create PCM buffer."]
                )
            }
            try file.read(into: pcmBuffer)
            return pcmBuffer
        }
        catch { throw error }
    }
    
    /// Converts an array of floating-point audio samples to 16-bit signed integer samples.
    ///
    /// **Note:** This is a convenience utility for processing audio data for voice activity detection.
    ///  It scales the floating-point samples to the range that `Int16` can represent.
    ///  The input array should have values between -1.0 and 1.0 to avoid clipping.
    ///  Any values outside this range will be clipped to fit within the Int16 range.
    ///
    /// - Parameters:
    ///   - floatData: A pointer to an array of floating-point samples to be converted.
    ///   - frameCount: The number of samples to convert.
    /// - Returns: An array of `Int16` samples.
    public static func convertFloatDataToInt16(
        floatData  : UnsafePointer<Float>,
        frameCount : Int
    ) -> [Int16] {
        var scaledFloatData = [Float](
            repeating : 0,
            count     : frameCount
        )
        var int16Data = [Int16](
            repeating : 0,
            count     : frameCount
        )
        
        // Scale float values to the range of Int16
        var scale = Float(Int16.max)
        vDSP_vsmul(floatData, 1, &scale, &scaledFloatData, 1, vDSP_Length(frameCount))
        
        // Convert scaled float data to Int16
        vDSP_vfix16(&scaledFloatData, 1, &int16Data, 1, vDSP_Length(frameCount))
        
        return int16Data
    }
    
    
    /// Divides an array of 16-bit integer audio samples into chunks of a specified frame size.
    ///
    /// **Note:** This utility is provided for convenience and can be used to prepare data for
    ///  voice activity detection, which often requires processing fixed-size frames.
    ///
    /// - Parameters:
    ///   - int16Data: An array of 16-bit integer samples to be chunked.
    ///   - frameSize: The size of each frame in samples. This is typically the number of samples in 10, 20, or 30 ms of audio.
    /// - Returns: An array of arrays, where each inner array represents a chunk of audio data.
    /// - Throws: An error if `frameSize` is not a positive integer.
    public static func chunkAudioData(
        int16Data : [Int16],
        frameSize : Int
    ) throws -> [[Int16]] {
        guard frameSize > 0 else {
            throw NSError(
                domain   : "VoiceActivityDetectorError",
                code     : -1,
                userInfo : [NSLocalizedDescriptionKey : "Frame size must be a positive integer."]
            )
        }
        
        let totalFrames        = int16Data.count
        var chunks : [[Int16]] = []
        
        for frameStart in stride(
            from : 0,
            to   : totalFrames,
            by   : frameSize
        ) {
            let frameEnd = min(frameStart + frameSize, totalFrames)
            let chunk = Array(int16Data[frameStart..<frameEnd])
            chunks.append(chunk)
        }
        
        return chunks
    }
    
    
    
    /// Detects voice activity within a chunk of audio data.
    ///
    /// **Note:** This convenience utility leverages the `VoiceActivityDetector` instance to analyze a single
    ///  chunk of audio data for voice presence. It's useful for processing audio data that has been
    ///  partitioned into frames of equal size.
    ///
    /// - Parameters:
    ///   - vad: An instance of `VoiceActivityDetector` configured with the desired settings.
    ///   - chunk: An array of 16-bit integer samples representing a single chunk of audio data.
    /// - Returns: A `Bool` indicating whether voice activity is detected (`true`) or not (`false`).
    /// - Throws: An error if the chunk size does not match one of the expected frame sizes for the current sample rate.
    public static func detectVoiceActivityInChunk(
        vad   : VoiceActivityDetector,
        chunk : [Int16]
    ) throws -> Bool {
        // Calculate the expected frame size based on the sample rate and duration enum.
        let expectedFrameSize = vad.sampleRate / 1000 * Duration.msec10.rawValue
        
        guard chunk.count == expectedFrameSize else {
            throw NSError(
                domain   : "VoiceActivityDetectorError",
                code     : -1,
                userInfo : [NSLocalizedDescriptionKey : "Chunk size does not match the expected frame size for the current sample rate."]
            )
        }
        
        return vad.detect(frames: chunk, count: chunk.count) == .activeVoice
    }
    
    
    /// Processes an audio PCM buffer and detects voice activity.
    ///
    /// **Note:** This convenience utility leverages the `VoiceActivityDetector` to analyze the entire audio buffer
    ///  and returns a boolean indicating whether any voice activity was detected.
    ///
    /// - Parameters:
    ///   - pcmBuffer: An `AVAudioPCMBuffer` containing the audio data to be processed.
    ///   - vad: An instance of `VoiceActivityDetector` configured with the desired settings.
    /// - Returns: A `Bool` indicating whether voice activity is detected (`true`) or not (`false`).
    /// - Throws: An error if the audio data cannot be processed or if the chunk size does not match the expected frame size.
    public static func processAudioData(
        pcmBuffer   : AVAudioPCMBuffer,
        vad         : VoiceActivityDetector,
        msChunkSize : Int = 10,
        sampleRate  : Int = 8000
    ) throws -> Bool {
        guard let channelData = pcmBuffer.floatChannelData
        else {
            throw NSError(
                domain   : "VoiceActivityDetectorError",
                code     : -1,
                userInfo : [NSLocalizedDescriptionKey : "Failed to get channel data from PCM buffer."]
            )
        }
        
        // Assuming the audio file is mono for simplicity
        let floatData   = channelData[0]
        let totalFrames = Int(pcmBuffer.frameLength)
        let int16Data   = convertFloatDataToInt16(
            floatData  : floatData,
            frameCount : totalFrames
        )
        
        // Calculate frame size based on sample rate and desired chunk duration
        let frameSize   = sampleRate * msChunkSize / 1000
        
        let chunks = try chunkAudioData(int16Data: int16Data, frameSize: frameSize)
        
        // Process each chunk to detect voice activity
        for chunk in chunks {
            if try detectVoiceActivityInChunk(vad: vad, chunk: chunk) {
                return true // Voice activity detected
            }
        }
        
        return false // No voice activity detected
        
    }
}
