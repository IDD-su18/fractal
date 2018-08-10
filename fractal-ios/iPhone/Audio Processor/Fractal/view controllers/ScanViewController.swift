
//
//  ScanViewController.swift
//  Audio Processor
//
//  Created by Matthew Jeng on 7/26/18.
//  Copyright © 2018 Matthew Jeng. All rights reserved.
//

import UIKit
import AVFoundation
import AudioKit
import AudioKitUI
import CoreBluetooth

class ScanViewController: UIViewController, AVAudioRecorderDelegate,
AVAudioPlayerDelegate, CBPeripheralManagerDelegate {
    
    let INDEX_PLAY_BTN = 1
    let INDEX_DEL_BTN = 2
    
    var contralateralScanViewModel: ScanViewModel
    var suspectedScanViewModel: ScanViewModel
    
    private var bothScansComplete: Bool = {
        return contralateralScanViewModel.progress = .finishedScanning &&
        suspectedScanViewModel.progress = .finishedScanning
    }

    @IBOutlet weak var suspectedStatusLabel: UILabel!
    @IBOutlet weak var contralateralStatusLabel: UILabel!
    @IBOutlet weak var suspectedBackgroundView: UIView!
    @IBOutlet weak var contralateralBackgroundView: UIView!
    
    
    // how long each recording should be
    var recordingSeconds = 15.0
    
    @IBOutlet weak var trackIdSegControl: UISegmentedControl!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var buttonStackView: UIStackView!
    @IBOutlet weak var contralateralButton: UIButton!
    @IBOutlet weak var suspectedButton: UIButton!
    @IBOutlet weak var suspectedStackView: UIStackView!
    @IBOutlet weak var contralateralStackView: UIStackView!
    @IBOutlet weak var audioPlot: EZAudioPlot!

    // stuff for the audio viz
    var mic: AKMicrophone!
    var tracker: AKFrequencyTracker!
    var silence: AKBooster!
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view, typically from a nib.
        
        // audiokit
        AKSettings.audioInputEnabled = true
        mic = AKMicrophone()
        tracker = AKFrequencyTracker(mic)
        silence = AKBooster(tracker, gain: 0)
        
        // Asking user permission for accessing Microphone
        AVAudioSession.sharedInstance().requestRecordPermission () {
            [unowned self] allowed in
            if allowed {
                // Microphone allowed, do what you like!
                
            } else {
                // User denied microphone. Tell them off!
            }
        }
        print(getAudioFileUrl())
        
        if isUsingBluetooth {
            peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        }
        updateIncomingData()
        updateUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AudioKit.output = silence
        do {
            try AudioKit.start()
        } catch {
            AKLog("AudioKit did not start!")
        }
        setupPlot()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // peripheralManager?.stopAdvertising()
        // self.peripheralManager = nil
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        recordingExists = false
        
    }
    
    func setupPlot() {
        let plot = AKNodeOutputPlot(mic, frame: audioPlot.bounds)
        plot.plotType = .rolling
        plot.shouldFill = true
        plot.shouldMirror = true
        plot.color = UIColor.blue
        audioPlot.addSubview(plot)
        audioPlot.isHidden = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    @IBAction func contralateralAction(_ sender: UIButton) {
        suspectedScanViewModel.isSelected = false
        contralateralScanViewModel.isSelected = true
        updateUI()
    }
    
    @IBAction func suspectedAction(_ sender: UIButton) {
        suspectedScanViewModel.isSelected = true
        contralateralScanViewModel.isSelected = false
        updateUI()
    }
    
    func updateUI() {
        for scanState in [contralateralScanViewModel, suspectedScanViewModel] {
            switch scanState.progress {
            case .scanInProgress:
                // TODO: maybe change color instead of hiding it
                audioPlot.isHidden = false
                scanState.progressLabel.text = Strings.SCANNING
            case .scanCancelled:
                audioPlot.isHidden = true
                audioPlot.isHidden = false
                scanState.progressLabel.text = Strings.CANCELLED
            case .notYetScanned:
                scanState.deleteButton.isHidden = true
                scanState.playbackButton.isHidden = true
                if scanState.isSelected {
                    scanState.progressLabel.text = Strings.READY_TO_SCAN
                } else {
                    scanState.progressLabel.text = Strings.NOT_YET_SCANNED
                }
            case .finishedScanning:
                audioPlot.isHidden = true
                scanState.progressLabel.text = Strings.SCAN_COMPLETE
                scanState.deleteButton.isHidden = false
                scanState.playbackButton.isHidden = false
            }
            if scanState.isSelected {
                scanState.bgView.backgroundColor = Colors.SELECTED_BTN
                
            } else {
                scanState.bgView.backgroundColor = Colors.DESELECTED_BTN
            }
        }
    }
    
    // MARK: Bluetooth
    func updateIncomingData () {
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "Notify"), object: nil , queue: nil) {
            notification in
            
            guard self.hasReceiviedInitialMessage else {
                // this is not a great way to do this but it works
                // not able to parse received messages yet, but they only
                // send once when bluetooth connects and then every time a button press
                // this guard makes sure we dont turn on the scanner for the initial
                // bluetooth connect message
                self.hasReceiviedInitialMessage = true
                return
            }
            
            if self.bothScansComplete {
                self.postToHeroku()
                return
            }
            
            if (self.contralateralScanViewModel.canStartQuickScan) {
                self.startScan(for: self.contralateralScanViewModel)
            }
            else if (self.suspectedScanViewModel.canStartQuickScan) {
                self.startScan(for: self.suspectedScanViewModel)
            }
        }
    }

    
    
    
    
    
    func startScan(for viewModel: ScanViewModel) {
        /* update UI for scan in progress
         * start actuator, and start recording */
        
        let newAsciiText = NSMutableAttributedString(attributedString: self.consoleAsciiText!)
    
        viewModel.setScanProgress(to: .scanInProgress)
        updateUI()
        // todo: add setting for switching b/w sounds
        recordingSeconds = 15
        
        startRecording()
        startSelectedSoundFile()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + recordingSeconds) {
            self.finishRecording()
            viewModel.setScanProgress(to: .finishedScanning)
            self.updateUI()
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
    
    @IBAction func play(_ sender: UIButton) {
        //playSound()
        // TODO
    }
    
    func startRecording(viewModel: ScanViewModel) {
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
            audioRecorder = try AVAudioRecorder(url: getAudioFileUrl(viewModel: viewModel), settings: settings)
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
    
    // Stop recording
    func finishRecording() {
        audioRecorder?.stop()
        isRecording = false
        recordingExists = true
    }
    
    // Path for saving/retreiving the audio file
    func getAudioFileUrl(viewModel: ScanViewModel) -> URL{
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let docsDirect = paths[0]
        
        return docsDirect.appendingPathComponent(viewModel.filename + ".mp4")
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
    
    func postToHeroku() {
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
                var resultsViewController = self.instantiateViewController(withID: "ResultsViewController") as! ResultsViewController
                resultsViewController.resultsImage = UIImage(data: data)
                self.navigationController?.pushViewController(resultsViewController, animated: true)
            }
        }
        task.resume()
    }
    
    private func instantiateViewController(withID id: String) -> UIViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        return storyboard.instantiateViewController(withIdentifier: id)
    }
    
    private func startSelectedSoundFile() {
        let stringToSend = String(describing: trackIdSegControl.selectedSegmentIndex)
        writeValue(data: stringToSend)
    }
}

