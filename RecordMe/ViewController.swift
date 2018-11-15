//
//  ViewController.swift
//  RecordMe
//
//  Created by Hector Mendoza on 11/14/18.
//  Copyright © 2018 Hector Mendoza. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var timeLabel: UILabel!
    
    var audioRecorder: AVAudioRecorder!
    var audioPlayer: AVAudioPlayer!
    var meterTimer: Timer!
    
    var isAudioRecordingGranted: Bool!
    var isRecording = false
    var isPlaying = false
    
    
    @IBAction func recordTapped(_ sender: UIButton) {
        
        if isRecording {
            
            finishAudioRecording(success: true)
            recordButton.setTitle("Record", for: .normal)
            playButton.isEnabled = true
            isRecording = false
        } else {
            
            setupRecorder()
            
            audioRecorder.record()
            meterTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.updateAudioMeter(timer:)), userInfo: nil, repeats: true)
            recordButton.setTitle("Stop", for: .normal)
            playButton.isEnabled = false
            isRecording = true
        }
        
    }
    
    
    @IBAction func playTapped(_ sender: UIButton) {
        
        if isPlaying {
            
            audioPlayer.stop()
            recordButton.isEnabled = true
            playButton.setTitle("Play", for: .normal)
            isPlaying = false
        } else {
            
            if FileManager.default.fileExists(atPath: getFileUrl().path) {
                
                recordButton.isEnabled = false
                playButton.setTitle("Stop", for: .normal)
                setupPlay()
                audioPlayer.play()
                isPlaying = true
            } else {
                
                displayAlert(title: "Error", message: "Audio file is missing.")
            }
            
        }
        
    }
    
    
    @objc func updateAudioMeter(timer: Timer) {
        
        if audioRecorder.isRecording {
            
            let hr = Int((audioRecorder.currentTime / 60) / 60)
            let min = Int(audioRecorder.currentTime / 60)
            let sec = Int(audioRecorder.currentTime.truncatingRemainder(dividingBy: 60))
            let timeString = String(format: "%02d:%02d:%02d", hr, min, sec)
            timeLabel.text = timeString
            audioRecorder.updateMeters()
        }
        
    }
    
    
    func finishAudioRecording(success: Bool) {
        
        if success {
            
            audioRecorder.stop()
            audioRecorder = nil
            meterTimer.invalidate()
        } else {
            
            displayAlert(title: "Error", message: "Recording failed.")
        }
        
    }
    
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            finishAudioRecording(success: false)
        }
        playButton.isEnabled = true
    }
    
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        recordButton.isEnabled = true
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        checkRecordPermission()
    }
    
    
    func checkRecordPermission() {
        
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            isAudioRecordingGranted = true
            break
        case .denied:
            isAudioRecordingGranted = false
            break
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { (granted) in
                if granted {
                    self.isAudioRecordingGranted = true
                } else {
                    self.isAudioRecordingGranted = false
                }
            }
            break
        default:
            break
        }
        
    }
    
    
    //Path to where to save recordings
    func getDirectory() -> URL {
        
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let directory = paths[0]
        return directory
    }
    
    
    //Directory + fileName = filePath
    func getFileUrl() -> URL {
        
        let fileName = "myRecording.m4a"
        let filePath = getDirectory().appendingPathComponent(fileName)
        return filePath
    }
    
    
    func setupRecorder() {
        
        if isAudioRecordingGranted {
            
            let session = AVAudioSession.sharedInstance()
            do {
                
                try session.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
                try session.setActive(true)
                let settings = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 2,
                    AVEncoderAudioQualityKey:AVAudioQuality.high.rawValue
                ]
                
                audioRecorder = try AVAudioRecorder(url: getFileUrl(), settings: settings)
                audioRecorder.delegate = self
                audioRecorder.isMeteringEnabled = true
                audioRecorder.prepareToRecord()
            } catch let error {
                displayAlert(title: "Could not setup recorder", message: error.localizedDescription)
            }
            
        } else {
            
            displayAlert(title: "Error", message: "App does not have access to your microphone")
        }
        
    }
    
    
    func setupPlay() {
        
        do {
            
            audioPlayer = try AVAudioPlayer(contentsOf: getFileUrl())
            audioPlayer.delegate = self
            audioPlayer.prepareToPlay()
        } catch {
            
            displayAlert(title: "Error", message: "Could not setup play function")
        }
        
    }
    
    
    //General alert message
    func displayAlert(title: String, message: String) {
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "Dismiss", style: .default, handler: nil)
        alert.addAction(action)
        
        present(alert, animated: true)
    }
    
}

