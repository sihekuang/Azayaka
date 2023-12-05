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
        audioEngine.attach(mixerNode)
        let format = audioEngine.inputNode.inputFormat(forBus: bus)
        audioEngine.connect(audioEngine.inputNode, to:mixerNode, format: format)
        
        mixerNode.installTap(onBus: bus, bufferSize: 2048, format: format){[weak self]buffer,time in
            guard let avbuffer = buffer.toStandardSampleBuffer() else{
                return
                
            }
            self?.assetWriterInput.append(avbuffer)
            //            guard let avBuffer  = buffer.convertAVAudioPCMBufferToCMSampleBuffer() else
            //                        {
            //                            return
            //                        }
            //
            //                        self?.assetWriterInput.append(avBuffer)
            
        }
        
    }
    
    
}

extension AVAudioPCMBuffer {
    
    fileprivate func convert32BitsTo16Bits(inputBufferList: AudioBufferList, outputBufferList: AudioBufferList){
        
        let outputBuffer = outputBufferList.mBuffers.mData
        let inputBuffer = inputBufferList.mBuffers.mData
        
        let numberFrams = min(inputBufferList.mBuffers.mDataByteSize / 4, outputBufferList.mBuffers.mDataByteSize / 2)
        
        for frame in 0..<numberFrams{
            let frameVal = inputBuffer!.loadUnaligned(fromByteOffset: Int(frame), as: Float.Type.self)
            outputBuffer?.storeBytes(of: frameVal, toByteOffset: Int(frame), as: Float.Type.self)
        }
    }
    
    public func toStandardSampleBuffer(duration: CMTime? = nil, pts: CMTime? = nil, dts: CMTime? = nil) -> CMSampleBuffer? {
        
        var sampleBuffer: CMSampleBuffer? = nil
        
        let based_pts = pts ?? CMTime.zero
        
        let new_pts = CMTimeMakeWithSeconds(CMTimeGetSeconds(based_pts), preferredTimescale: based_pts.timescale)
        
        var timing = CMSampleTimingInfo(duration: CMTimeMake(value: 1, timescale: 44100), presentationTimeStamp: new_pts, decodeTimeStamp: CMTime.invalid)
        
        var output_format = self.format
        
        var pcmBuffer = self
        
        if ((self.format.streamDescription.pointee.mFormatFlags & kAudioFormatFlagIsSignedInteger) != kAudioFormatFlagIsSignedInteger) {
            
            var convert_asbd = AudioStreamBasicDescription(mSampleRate: self.format.sampleRate, mFormatID: kAudioFormatLinearPCM, mFormatFlags: (kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked), mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
            
            guard let covert_format = AVAudioFormat(streamDescription: &convert_asbd) else {return nil}
            
            
            guard let covert_buffer = AVAudioPCMBuffer(pcmFormat: covert_format, frameCapacity: self.frameCapacity) else {return nil}
            
            covert_buffer.frameLength = covert_buffer.frameCapacity
            
            //                PLAudioMixerUtlis.covert32bitsTo16bits(self.mutableAudioBufferList, outputBufferList: covert_buffer.mutableAudioBufferList)
            
            convert32BitsTo16Bits(inputBufferList: self.mutableAudioBufferList.pointee, outputBufferList: covert_buffer.mutableAudioBufferList.pointee)
            
            output_format = covert_format
            
            pcmBuffer = covert_buffer
            
        }
        
        guard CMSampleBufferCreate(allocator: kCFAllocatorDefault, dataBuffer: nil, dataReady: false, makeDataReadyCallback: nil, refcon: nil, formatDescription: output_format.formatDescription, sampleCount: CMItemCount(self.frameLength), sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sampleBuffer) == noErr else { return nil }
        
        guard CMSampleBufferSetDataBufferFromAudioBufferList(sampleBuffer!, blockBufferAllocator: kCFAllocatorDefault, blockBufferMemoryAllocator: kCFAllocatorDefault, flags: 0, bufferList: pcmBuffer.audioBufferList) == noErr else {
            
            return nil
            
        }
        
        return sampleBuffer
        
    }
}


//    static func convertAVAudioPCMBufferToCMSampleBuffer(pcmBuffer: AVAudioPCMBuffer) -> CMSampleBuffer? {
//        var status: OSStatus = noErr
//
//        // Create a CMFormatDescription from the AVAudioFormat
//        var formatDescription: CMFormatDescription?
//        status = CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault,
//                                                asbd: pcmBuffer.format.streamDescription,
//                                                layoutSize: 0,
//                                                layout: nil,
//                                                magicCookieSize: 0,
//                                                magicCookie: nil,
//                                                extensions: nil,
//                                                formatDescriptionOut: &formatDescription)
//
//        guard status == noErr, let formatDesc = formatDescription else {
//            return nil
//        }
//
//        // Create a CMBlockBuffer to store audio data
//        var blockBuffer: CMBlockBuffer?
//        status = CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault,
//                                                    memoryBlock: nil,
//                                                    blockLength: Int(pcmBuffer.frameLength * pcmBuffer.format.streamDescription.pointee.mBytesPerFrame),
//                                                    blockAllocator: kCFAllocatorNull,
//                                                    customBlockSource: nil,
//                                                    offsetToData: 0,
//                                                    dataLength: Int(pcmBuffer.frameLength * pcmBuffer.format.streamDescription.pointee.mBytesPerFrame),
//                                                    flags: 0,
//                                                    blockBufferOut: &blockBuffer)
//
//        guard status == noErr, let buffer = blockBuffer else {
//            return nil
//        }
//
//        // Copy audio data to the block buffer
//        if let audioData = pcmBuffer.int16ChannelData {
//            CMBlockBufferReplaceDataBytes(with: audioData, blockBuffer: buffer, offsetIntoDestination: 0, dataLength: Int(pcmBuffer.frameLength * pcmBuffer.format.streamDescription.pointee.mBytesPerFrame))
//        }
//
//        // Create a CMSampleBuffer
//        var sampleBuffer: CMSampleBuffer?
//        status = CMSampleBufferCreate(allocator: kCFAllocatorDefault,
//                                      dataBuffer: buffer,
//                                      dataReady: true,
//                                      makeDataReadyCallback: nil,
//                                      refcon: nil,
//                                      formatDescription: formatDesc,
//                                      sampleCount: Int(pcmBuffer.frameLength),
//                                      sampleTimingEntryCount: 0,
//                                      sampleTimingArray: nil,
//                                      sampleSizeEntryCount: 0,
//                                      sampleSizeArray: nil,
//                                      sampleBufferOut: &sampleBuffer)
//
//        if status == noErr {
//            return sampleBuffer
//        } else {
//            return nil
//        }
//    }





