//
//  ResultsViewController.swift
//  Audio Processor
//
//  Created by Paige Plander on 8/2/18.
//  Copyright © 2018 Matthew Jeng. All rights reserved.
//

import UIKit
import AVFoundation

class ResultsViewController: UIViewController, AVAudioPlayerDelegate {

    @IBOutlet weak var imageView: UIImageView!
    
    var player : AVAudioPlayer?
    var resultsImage: UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        imageView.contentMode = .scaleAspectFit
        
        if let resultsImage = resultsImage {
            imageView.image = resultsImage
        }
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
        
        return docsDirect.appendingPathComponent(urlName + ".mp4")
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            
        } else {
            // Playing interrupted by other reasons like call coming, the sound has not finished playing.
        }
    }
    @IBAction func playbackSuspected(_ sender: UIButton) {
        playSound(urlName: "suspected")
    }
    
    @IBAction func playbackContralateral(_ sender: UIButton) {
        playSound(urlName: "contralateral")
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
