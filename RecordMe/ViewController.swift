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
    var seconds: Int = 1
    
    var isAudioRecordingGranted: Bool!
    var isRecording = false
    var isPlaying = false
    
    @IBAction func recordTapped(_ sender: UIButton) {
        
        if isRecording {
            
            audioRecorder.stop()
        } else {
            
            if setupRecorder() {
                
                audioRecorder.record()
                isRecording = true
                meterTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.updateAudioMeter(timer:)), userInfo: nil, repeats: true)
                recordButton.setTitle("Stop", for: .normal)
                playButton.isEnabled = false
            }
            
        }
        
    }
    
    
    @IBAction func playTapped(_ sender: UIButton) {
        
        if isPlaying {
            
            finishAudioPlaying(success: true)
        } else {
            
            if FileManager.default.fileExists(atPath: getFileUrl().path) {
                
                if setupPlay() {
                    
                    audioPlayer.play()
                    isPlaying = true
                    meterTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.updateAudioMeter(timer:)), userInfo: nil, repeats: true)
                    playButton.setTitle("Stop", for: .normal)
                    recordButton.isEnabled = false
                }
                
            } else {
                
                displayAlert(title: "Error", message: "Audio file is missing.")
            }
            
        }
        
    }
    
    
    @objc func updateAudioMeter(timer: Timer) {
        
        if isRecording {
            
            let hr = Int(seconds / 3600)
            let min = Int(seconds / 60) % 60
            let sec = Int(seconds % 60)
//            BUG: .currenTime changes after AVAudioRouteChange
//            let hr = Int((audioRecorder.currentTime / 60) / 60)
//            let min = Int(audioRecorder.currentTime / 60)
//            let sec = Int(audioRecorder.currentTime.truncatingRemainder(dividingBy: 60))
            let timeString = String(format: "%02d:%02d:%02d", hr, min, sec)
            timeLabel.text = timeString
            seconds += 1
        }
        
        if isPlaying {
            
            let hr = Int((audioPlayer.currentTime / 60) / 60)
            let min = Int(audioPlayer.currentTime / 60)
            let sec = Int(audioPlayer.currentTime.truncatingRemainder(dividingBy: 60))
            let timeString = String(format: "%02d:%02d:%02d", hr, min, sec)
            timeLabel.text = timeString
        }
        
    }
    
    
    func finishAudioRecording(success: Bool) {
        
        if !success {
            
            displayAlert(title: "Error", message: "Recording failed.")
        }
        
        meterTimer.invalidate()
        seconds = 1
        audioRecorder = nil
        recordButton.setTitle("Record", for: .normal)
        playButton.isEnabled = true
        isRecording = false
        timeLabel.text = "00:00:00"
    }
    
    
    func finishAudioPlaying(success: Bool) {
        
        if !success {
            
            displayAlert(title: "Error", message: "Could not play audio file.")
        }
        
        meterTimer.invalidate()
        audioPlayer.stop()
        recordButton.isEnabled = true
        playButton.setTitle("Play", for: .normal)
        isPlaying = false
        timeLabel.text = "00:00:00"
    }
    
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        finishAudioRecording(success: flag)
    }
    
    
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("Did finish playing")
        finishAudioPlaying(success: flag)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        checkRecordPermission()
        setupNotifications()
    }
    
    
    //Check's if we have microphone usage permission (.plist)
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
    
    
    //Let's setup our notifications
    func setupNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleRouteChange),
                                               name: AVAudioSession.routeChangeNotification,
                                               object: AVAudioSession.sharedInstance())
    }
    
    
    //Let's handle audio session route changes
    @objc func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue:reasonValue) else {
                return
        }
        switch reason {
        case .newDeviceAvailable:
            if isRecording {
                audioRecorder.stop()
            }
        case .oldDeviceUnavailable:
            if isRecording {
                audioRecorder.stop()
            }
            if isPlaying {
                audioPlayer.pause()
            }
        default: ()
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
        
        let fileName = "myRecording1.m4a"
        let filePath = getDirectory().appendingPathComponent(fileName)
        return filePath
    }
    
    
    func setupRecorder() -> Bool {
        
        if isAudioRecordingGranted {
            
            do {
                
                let session = AVAudioSession.sharedInstance()
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
                audioRecorder.prepareToRecord()
                return true
            } catch let error {
                displayAlert(title: "Error", message: error.localizedDescription)
                return false
            }
            
        } else {
            
            displayAlert(title: "Error", message: "App does not have permission to use your microphone.")
            return false
        }
        
    }
    
    
    func setupPlay() -> Bool {
        
        do {
            
            audioPlayer = try AVAudioPlayer(contentsOf: getFileUrl())
            audioPlayer.delegate = self
            audioPlayer.prepareToPlay()
            return true
        } catch {
            
            displayAlert(title: "Error", message: "Could not setup play function.")
            return false
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

