
//
//  ViewController.swift
//  Audio Processor
//
//  Created by Matthew Jeng on 7/26/18.
//  Copyright © 2018 Matthew Jeng. All rights reserved.
//

import UIKit
import AVFoundation
import CoreBluetooth

class ScanViewController: UIViewController, AVAudioRecorderDelegate,
AVAudioPlayerDelegate, CBPeripheralManagerDelegate {
    
    var currentScanMode = "suspected"
    
    var suspectedRecordingExists =  false
    var contralateralRecordingExists =  false
    
    var teal = UIColor(red: 0.0, green: 0.569, blue: 0.575, alpha: 1.0)
    var reddish = UIColor(red: 1.00, green: 0.149, blue: 0.0, alpha: 1.0)
    
    // how long each recording should be
    var recordingSeconds = 15.0
    
    @IBOutlet weak var trackIdSegControl: UISegmentedControl!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var buttonStackView: UIStackView!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var postButton: UIButton!
    @IBOutlet weak var calculateTransmissionRateButton: UIButton!
    @IBOutlet weak var suspectedScannedLabel: UILabel!
    @IBOutlet weak var contralateralScannedLabel: UILabel!
    // the scan button should perform recording, playback, and post
    @IBOutlet weak var scanButton: UIButton!
    
    var isUsingBluetooth = false
    var hasReceiviedInitialMessage = false
    
    var peripheralManager: CBPeripheralManager?
    var peripheral: CBPeripheral!
    private var consoleAsciiText: NSAttributedString? = NSAttributedString(string: "")
    
    var isRecording = false
    var audioRecorder: AVAudioRecorder?
    var player : AVAudioPlayer?
    var recordingExists = false
    
    
    
    //    var recordingSession: AVAudioSession!
    //    var audioRecorder: AVAudioRecorder!
    
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // bluetooth
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title:"Back", style:.plain, target:nil, action:nil)
        
        self.navigationItem.title = "Scan"
        
        // Asking user permission for accessing Microphone
        AVAudioSession.sharedInstance().requestRecordPermission () {
            [unowned self] allowed in
            if allowed {
                // Microphone allowed, do what you like!
                self.setUpUI()
            } else {
                // User denied microphone. Tell them off!
            }
        }
        print(getAudioFileUrl())
        
        //        buttonStackView.arrangedSubviews[0].isHidden = true
        //        buttonStackView.arrangedSubviews[1].isHidden = true
        
        // bluetooth
        if isUsingBluetooth {
            peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
            updateIncomingData()
        }
        
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        // peripheralManager?.stopAdvertising()
        // self.peripheralManager = nil
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        
    }
    
    
    // MARK: Bluetooth
    func updateIncomingData () {
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "Notify"), object: nil , queue: nil){
            notification in
            
            self.startScan()
        }
    }
        
    func startScan() {
        /* update UI for scan in progress
         * start actuator, and start recording */
        
        guard hasReceiviedInitialMessage == true else {
            // this is not a great way to do this but it works
            // not able to parse received messages yet, but they only
            // send once when bluetooth connects and then every time a button press
            // this guard makes sure we dont turn on the scanner for the initial
            // bluetooth connect message
            hasReceiviedInitialMessage = true
            return
        }
        
        let newAsciiText = NSMutableAttributedString(attributedString: self.consoleAsciiText!)
        titleLabel.text = "Scan in progress"
        
        print("char ascii val =" + (characteristicASCIIValue as String))
        if (trackIdSegControl.selectedSegmentIndex == 0) {
            recordingSeconds = 5
        }
        else if (trackIdSegControl.selectedSegmentIndex == 1) {
            recordingSeconds = 15
        }
        startRecording()
        startSelectedSoundFile()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + recordingSeconds) {
            self.finishRecording()
            self.titleLabel.text = "Scan complete"
            if (self.suspectedRecordingExists && self.contralateralRecordingExists) {
                
                UIView.animate(withDuration: 0.5, animations: {
                    
                    self.calculateTransmissionRateButton.isHidden = false
                    
                })
            }
        }
    }
    
    
    
    
    // Write functions
    func writeValue(data: String){
        let valueString = (data as NSString).data(using: String.Encoding.utf8.rawValue)
        //change the "data" to valueString
        if let blePeripheral = blePeripheral{
            if let txCharacteristic = txCharacteristic {
                blePeripheral.writeValue(valueString!, for: txCharacteristic, type: CBCharacteristicWriteType.withResponse)
            }
        }
    }
    
    func writeCharacteristic(val: Int8){
        var val = val
        let ns = NSData(bytes: &val, length: MemoryLayout<Int8>.size)
        blePeripheral!.writeValue(ns as Data, for: txCharacteristic!, type: CBCharacteristicWriteType.withResponse)
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            return
        }
        print("Peripheral manager is running")
    }
    
    //Check when someone subscribe to our characteristic, start sending the data
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("Device subscribe to characteristic")
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("\(error)")
            return
        }
    }
    
    // MARK: not Bluetooth
    
    @IBAction func debugButtonPressed(_ sender: UIButton) {
        UIView.animate(withDuration: 0.5, animations: {
            self.buttonStackView.arrangedSubviews[0].isHidden = !self.buttonStackView.arrangedSubviews[0].isHidden
            
        })
    }
    
    func setUpUI() {
        print("I ain't needa do nothin")
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //    @IBAction func onRecordClick(_ sender: Any) {
    //
    //        guard let url = URL(string: "https://emilys-server.herokuapp.com/") else { return }
    //
    //        let session = URLSession.shared
    //        session.dataTask(with: url) { (data, response, error) in
    //            if let response = response {
    //                print(response)
    //            }
    //
    //            if let data = data {
    //                do {
    //                    let json = try JSONSerialization.jsonObject(with: data, options: [])
    //                    print(json)
    //                } catch {
    //                    print(error)
    //                }
    //            }
    //
    //
    //        }.resume()
    //    }
    
    @IBAction func recordingTypeChanges(_ sender: UISegmentedControl) {
        // TODO: refactor this
        currentScanMode = sender.titleForSegment(at: sender.selectedSegmentIndex)!
        switch currentScanMode {
        case "suspected":
            if suspectedRecordingExists {
                scanButton.setTitle("re-scan", for: .normal)
                return
            }
            else {
                scanButton.setTitle("scan", for: .normal)
                return
            }
        default:
            if contralateralRecordingExists {
                scanButton.setTitle("re-scan", for: .normal)
                return
            }
            else {
                scanButton.setTitle("scan", for: .normal)
                return
            }
        }
    }
    
    @IBAction func recordButtonWasPressed(_ sender: UIButton) {
        if isRecording { 
            sender.setTitle("record", for: .normal)
            finishRecording()
        } else {
            sender.setTitle("stop", for: .normal)
            startRecording()
        }
    }
    
    @IBAction func play(_ sender: UIButton) {
        //playSound()
    }
    
    
    
    func startRecording() {
        //1. create the session
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
            audioRecorder = try AVAudioRecorder(url: getAudioFileUrl(), settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
            //5. Changing record icon to stop icon
            isRecording = true
            //            playButton.isEnabled = false
        }
        catch let error {
            print("ERROR in startRecording")
            print(error)
            // failed to record!
        }
    }
    
    // Stop recording
    func finishRecording() {
        audioRecorder?.stop()
        isRecording = false
        recordingExists = true
        
        switch currentScanMode {
        case "suspected":
            suspectedRecordingExists = true
            suspectedScannedLabel.text = "scanned"
            suspectedScannedLabel.textColor = teal
            scanButton.setTitle("re-scan", for: .normal)
        default:
            contralateralRecordingExists = true
            contralateralScannedLabel.text = "scanned"
            contralateralScannedLabel.textColor = teal
        }
        
        scanButton.setTitle("re-scan", for: .normal)
        scanButton.backgroundColor = teal
    }
    
    // Path for saving/retreiving the audio file
    func getAudioFileUrl() -> URL{
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let docsDirect = paths[0]
        let audioUrl = docsDirect.appendingPathComponent(currentScanMode + ".m4a")
        return audioUrl
    }
    
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            finishRecording()
        } else {
            // Recording interrupted by other reasons like call coming, reached time limit.
        }
        //playButton.isEnabled = true
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            
        } else {
            // Playing interrupted by other reasons like call coming, the sound has not finished playing.
        }
        recordButton.isEnabled = true
    }
    
    @IBAction func postButton(_ sender: Any) {
        postToHeroku()
    }
    
    func postToHeroku() {
        if recordingExists {
            guard let url = URL(string: "https://emilys-server.herokuapp.com/process_audio") else { return }
            var request = URLRequest(url: url)
            request.setValue("audio/x-wav", forHTTPHeaderField: "Content-Type")
            request.httpMethod = "POST"
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data, error == nil else {
                    print(error as Any)
                    return
                }
                DispatchQueue.main.async {
                    
                    let storyboard = UIStoryboard(name: "Main", bundle: nil)
                    let resultsViewController = storyboard.instantiateViewController(withIdentifier: "ResultsViewController") as! ResultsViewController
                    resultsViewController.resultsImage = UIImage(data: data)
                    self.navigationController?.pushViewController(resultsViewController, animated: true)
                    
                }
            }
            task.resume()
        }
    }
    
    private func startSelectedSoundFile() {
        let stringToSend = String(describing: trackIdSegControl.selectedSegmentIndex)
        writeValue(data: stringToSend)
    }
    
    @IBAction func calculateTransmissionRateAction(_ sender: UIButton) {
        self.titleLabel.text = "Calculating transmission rate"
        postToHeroku()
    }
    
    @IBAction func scanButtonPressed(_ sender: UIButton) {
  
    
    
    }
    
    
}

