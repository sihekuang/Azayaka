//
//  AudioRecorder.swift
//  Azayaka
//
//  Created by Daniel Lee on 12/2/23.
//

import Foundation
import AVFoundation
import CoreMedia


class AudioRecorder{
    
    fileprivate let audioEngine = AVAudioEngine()
    fileprivate let mixerNode = AVAudioMixerNode()
    fileprivate let bus = AVAudioNodeBus(0)
    fileprivate let assetWriterInput: AVAssetWriterInput
    
    init(with assetWriterInput: AVAssetWriterInput){
        self.assetWriterInput = assetWriterInput
        setupRouting()
    }
}

// MARK: - Internal Methods
extension AudioRecorder{
    func startRecording() throws{
        try audioEngine.start()
    }
    
    func stopRecording(){
        audioEngine.stop()
    }
}


// MARK: - Private Methods
extension AudioRecorder{
    fileprivate func setupRouting() {
        let format = audioEngine.inputNode.inputFormat(forBus: bus)
        audioEngine.connect(audioEngine.inputNode, to:mixerNode, format: format)
        
        mixerNode.installTap(onBus: bus, bufferSize: 2048, format: format){[weak self]buffer,time in
            guard let avBuffer = AudioRecorder.convertAVAudioPCMBufferToCMSampleBuffer(pcmBuffer: buffer) else
            {
                return
            }
            
            self?.assetWriterInput.append(avBuffer)
        }
    }
    
    static func convertAVAudioPCMBufferToCMSampleBuffer(pcmBuffer: AVAudioPCMBuffer) -> CMSampleBuffer? {
        var status: OSStatus = noErr
        
        // Create a CMFormatDescription from the AVAudioFormat
        var formatDescription: CMFormatDescription?
        status = CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault,
                                                asbd: pcmBuffer.format.streamDescription,
                                                layoutSize: 0,
                                                layout: nil,
                                                magicCookieSize: 0,
                                                magicCookie: nil,
                                                extensions: nil,
                                                formatDescriptionOut: &formatDescription)
        
        guard status == noErr, let formatDesc = formatDescription else {
            return nil
        }
        
        // Create a CMBlockBuffer to store audio data
        var blockBuffer: CMBlockBuffer?
        status = CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault,
                                                    memoryBlock: nil,
                                                    blockLength: Int(pcmBuffer.frameLength * pcmBuffer.format.streamDescription.pointee.mBytesPerFrame),
                                                    blockAllocator: kCFAllocatorNull,
                                                    customBlockSource: nil,
                                                    offsetToData: 0,
                                                    dataLength: Int(pcmBuffer.frameLength * pcmBuffer.format.streamDescription.pointee.mBytesPerFrame),
                                                    flags: 0,
                                                    blockBufferOut: &blockBuffer)
        
        guard status == noErr, let buffer = blockBuffer else {
            return nil
        }
        
        // Copy audio data to the block buffer
        if let audioData = pcmBuffer.int16ChannelData {
            CMBlockBufferReplaceDataBytes(with: audioData, blockBuffer: buffer, offsetIntoDestination: 0, dataLength: Int(pcmBuffer.frameLength * pcmBuffer.format.streamDescription.pointee.mBytesPerFrame))
        }
        
        // Create a CMSampleBuffer
        var sampleBuffer: CMSampleBuffer?
        status = CMSampleBufferCreate(allocator: kCFAllocatorDefault,
                                      dataBuffer: buffer,
                                      dataReady: true,
                                      makeDataReadyCallback: nil,
                                      refcon: nil,
                                      formatDescription: formatDesc,
                                      sampleCount: Int(pcmBuffer.frameLength),
                                      sampleTimingEntryCount: 0,
                                      sampleTimingArray: nil,
                                      sampleSizeEntryCount: 0,
                                      sampleSizeArray: nil,
                                      sampleBufferOut: &sampleBuffer)
        
        if status == noErr {
            return sampleBuffer
        } else {
            return nil
        }
    }
    
    
}



