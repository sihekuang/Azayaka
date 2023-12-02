//
//  AudioRecorder.swift
//  Azayaka
//
//  Created by Daniel Lee on 12/2/23.
//

import Foundation
import AVFoundation

class AudioRecorder{
    
    fileprivate let audioEngine = AVAudioEngine()
    fileprivate let mixerNode = AVAudioMixerNode()
    fileprivate let bus = AVAudioNodeBus(0)
    fileprivate let assetWriter: AVAssetWriter
    
    init(with assetWriter: AVAssetWriter){
        self.assetWriter = assetWriter
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
    }
}



