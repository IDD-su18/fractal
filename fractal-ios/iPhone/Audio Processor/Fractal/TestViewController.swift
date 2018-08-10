//
//  TestViewController.swift
//  Audio Processor
//
//  Created by Paige Plander on 8/9/18.
//  Copyright © 2018 Matthew Jeng. All rights reserved.
//

import UIKit

import AVFoundation
import AudioKit
import AudioKitUI
import Alamofire

class TestViewController: UIViewController, AVAudioRecorderDelegate,
AVAudioPlayerDelegate {
    
    var isRecording = false
    var audioRecorder: AVAudioRecorder?
    var player : AVAudioPlayer?
    var recordingExists = false
    
    var testFile1Name = "audio1"
    var testFile2Name = "audio2"
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func record1(_ sender: Any) {
        if isRecording {
            finishRecording()
        }
        else {
            startRecording(testFile1Name)
            isRecording = true
        }
    }
    
    @IBAction func play1(_ sender: Any) {
        playSound(urlName: testFile1Name)
        //var sigArray = loadAudioSignal(audioURL: getAudioFileUrl(name: testFile1Name))
        //print(sigArray)
    }
    
    @IBAction func send1(_ sender: UIButton) {
        postAudio(fileName: testFile1Name, herokuURL: "https://emilys-server.herokuapp.com/save_audio_1")
    }
    
    
    @IBAction func record2(_ sender: Any) {
        if isRecording {
            finishRecording()
        }
        else {
            startRecording(testFile2Name)
            isRecording = true
        }
    }
    
    @IBAction func play2(_ sender: Any) {
        playSound(urlName: testFile2Name)
    }
    
    
    @IBAction func send2(_ sender: Any) {
        postAudio(fileName: testFile2Name, herokuURL: "https://emilys-server.herokuapp.com/save_audio_2")
    }
    
    @IBAction func processButtonAction(_ sender: UIButton) {
        
        let rlJSONObj = getProcessedAudio()
    }
    
    func startRecording(_ recordingName: String) {
        //1. create the session
        
        let url = getAudioFileUrl(name: recordingName)
        print("start recording: " + url.absoluteString)
        let session = AVAudioSession.sharedInstance()
        
        do {
            // 2. configure the session for recording and playback
            try session.setCategory(AVAudioSessionCategoryPlayAndRecord, with: .defaultToSpeaker)
            try session.setActive(true)
            // 3. set up a high-quality recording session
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            // 4. create the audio recording, and assign ourselves as the delegate
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
            //5. Changing record icon to stop icon
            
        }
        catch let error {
            print("ERROR in startRecording")
            print(error)
            // failed to record!
        }
    }
    
    func loadAudioSignal(audioURL: URL) -> (signal: [Float], rate: Double, frameCount: Int) {
        let file = try! AVAudioFile(forReading: audioURL)
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: file.fileFormat.sampleRate, channels: file.fileFormat.channelCount, interleaved: false)
        let buf = AVAudioPCMBuffer(pcmFormat: format!, frameCapacity: UInt32(file.length))
        try! file.read(into: buf!) // You probably want better error handling
        let floatArray = Array(UnsafeBufferPointer(start: buf!.floatChannelData?[0], count:Int(buf!.frameLength)))
        return (signal: floatArray, rate: file.fileFormat.sampleRate, frameCount: Int(file.length))
    }
    
    
    // Path for saving/retreiving the audio file
    func getAudioFileUrl(name: String) -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let docsDirect = paths[0]
        
        
        return docsDirect.appendingPathComponent(name + ".m4a")
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            finishRecording()
        } else {
            // Recording interrupted by other reasons like call coming, reached time limit.
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            // TODO
        } else {
            // Playing interrupted by other reasons like call coming, the sound has not finished playing.
        }
    }
    
    // Stop recording
    func finishRecording() {
        print("finish recording")
        audioRecorder?.stop()
        isRecording = false
        recordingExists = true
    }
    
    func getProcessedAudio() {
        guard let url = URL(string: "https://emilys-server.herokuapp.com/process_audio") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print(error as Any)
                return
            }
        
            DispatchQueue.main.async {
                // do whatever
                print("dataa")
                
                do {
                    let stringDic = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any]
                    print(stringDic)
                } catch let error {
                    print(error)
                }
                
             //   print(response)
          
            }
        }
        task.resume()
    }
    
    func postAudio(fileName: String, herokuURL: String) {
        let url = getAudioFileUrl(name: fileName)
        Alamofire.upload(
            multipartFormData: { multipartFormData in
                multipartFormData.append(url, withName: fileName, fileName: fileName, mimeType: "audio/x-m4a")
                
        },
            to: herokuURL,
            encodingCompletion: { encodingResult in
                switch encodingResult {
                case .success(let upload, _, _):
                    upload.responseJSON { response in
                        debugPrint(response)
                    }
                case .failure(let encodingError):
                    print(encodingError)
                }
        }
        )
    }

    @IBAction func getdata(_ sender: Any) {
        getProcessedAudio()
    }
    
    func playSound(urlName: String){
        let url = getAudioFileUrl(name: urlName)
        
        do {
            // AVAudioPlayer setting up with the saved file URL
            let sound = try AVAudioPlayer(contentsOf: url)
            self.player = sound
            
            // Here conforming to AVAudioPlayerDelegate
            sound.delegate = self
            sound.prepareToPlay()
            sound.play()
        } catch {
            print("error loading file")
            // couldn't load file :(
        }
    }
}
