//
//  ResultsViewController.swift
//  Audio Processor
//
//  Created by Paige Plander on 8/2/18.
//  Copyright © 2018 Matthew Jeng. All rights reserved.
//

import UIKit
import AVFoundation
import SwiftChart

class ResultsViewController: UIViewController {
    
    @IBOutlet weak var chart: Chart!
    
    var player : AVAudioPlayer?
    var jsonDict: [String : Any]?
    

    var xHealthy: [Float] = []
    var yHealthy: [Float] = []
    var xCf: [Float] = []
    var yCf: [Float] = []
    
    var data1 = [(1.0,1.0)]
    var data2 = [(1.0,1.0)]
    
    @IBOutlet weak var transmissionRateLabel: UILabel!
    
    override func viewDidLoad() {
    
        super.viewDidLoad()
        
        navigationItem.title = "Magnitude vs. Frequency"
        parseJSON()
        let chart = Chart(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 400))
        
        chart.center = view.center
        chart.delegate = self
        
        chart.minX = 0
        chart.maxX = 1200
        chart.minY = 0
        chart.maxY = 150
        chart.xLabels = [0, 200, 400, 600, 800, 1000, 1200]
        

        let series1 = ChartSeries(data: data1)
        series1.area = true
        series1.color = ChartColors.blueColor()
        let series2 = ChartSeries(data: data2)
        series1.area = true
        series2.color = ChartColors.redColor()
        chart.add(series1)
        chart.add(series2)
        view.addSubview(chart)
    }
    
    
    func parseJSON() {
        let xHealthy = jsonDict!["x_healthy"] as! [Double]
        let yHealthy = jsonDict!["y_healthy"] as! [Double]
        for i in 0..<xHealthy.count {
            data1.append((x: xHealthy[i], y: yHealthy[i]))
        }
        
        
        var transmissionRate = (jsonDict!["tr"] as! Double)*100
        transmissionRate = transmissionRate.rounded(toPlaces: 1)
        //transmissionRateLabel.text = String(describing: transmissionRate) + "%"
        
        let xCf = jsonDict!["x_cf"] as! [Double]
        let yCf = jsonDict!["y_cf"] as! [Double]
        for i in 0..<xCf.count {
            data2.append((x: xCf[i], y: yCf[i]))
        }
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

    }
    
    func playSound(urlName: String){
        let url = getAudioFileUrl(urlName: urlName)
        
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
    
    // Path for saving/retreiving the audio file
    func getAudioFileUrl(urlName: String) -> URL{
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let docsDirect = paths[0]
        let audioUrl = docsDirect.appendingPathComponent(urlName
            + ".m4a")
        return audioUrl
    }
    
    @IBAction func playbackSuspected(_ sender: UIButton) {
        playSound(urlName: "audio2")
    }
    
    @IBAction func playbackContralateral(_ sender: UIButton) {
        playSound(urlName: "audio1")
    }
}

extension ResultsViewController: AVAudioPlayerDelegate {
    
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            
        } else {
            // Playing interrupted by other reasons like call coming, the sound has not finished playing.
        }
    }
}

extension ResultsViewController: ChartDelegate {
    
    // Chart delegate
    func didTouchChart(_ chart: Chart, indexes: Array<Int?>, x: Double, left: CGFloat) {
        for (seriesIndex, dataIndex) in indexes.enumerated() {
            if dataIndex != nil {
                // The series at `seriesIndex` is that which has been touched
                let value = chart.valueForSeries(seriesIndex, atIndex: dataIndex)
            }
        }
    }
    
    func didFinishTouchingChart(_ chart: Chart) {
        // Do something when finished
    }
    
    func didEndTouchingChart(_ chart: Chart) {
        // Do something when ending touching chart
    }

}


extension Double {
    /// Rounds the double to decimal places value
    func rounded(toPlaces places:Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
