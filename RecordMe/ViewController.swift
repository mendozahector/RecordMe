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
    
    @IBOutlet weak var recordingsTableView: UITableView!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var pauseButton: UIButton!
    @IBOutlet weak var timeLabel: UILabel!
    
    var audioRecorder: AVAudioRecorder!
    var audioPlayer: AVAudioPlayer!
    var meterTimer: Timer!
    var seconds: Int = 1
    
    var isAudioRecordingGranted: Bool!
    var isRecording = false
    var isPlaying = false
    var isPaused = false
    
    @IBAction func recordTapped(_ sender: UIButton) {
        
        if isRecording {
            
            audioRecorder.stop()
        } else {
            
            if setupRecorder() {
                
                audioRecorder.record()
                pauseButton.isHidden = false
                isRecording = true
                meterTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.updateAudioMeter(timer:)), userInfo: nil, repeats: true)
            }
            
        }
        
    }
    
    
    @IBAction func pauseTapped(_ sender: UIButton) {
        
        if isRecording && !isPaused {
            
            audioRecorder.pause()
        } else if isRecording && isPaused {
            
            audioRecorder.record()
        }
        
        if isPlaying && !isPaused {
            
            audioPlayer.pause()
        } else if isPlaying && isPaused {
            
            audioPlayer.play()
        }
        
        isPaused = !isPaused
    }
    
    
//    @IBAction func playTapped(_ sender: UIButton) {
//
//        if isPlaying {
//
//            finishAudioPlaying(success: true)
//        } else {
//
//            if FileManager.default.fileExists(atPath: getFileUrl().path) {
//
//                if setupPlay() {
//
//                    audioPlayer.play()
//                    isPlaying = true
//                    meterTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.updateAudioMeter(timer:)), userInfo: nil, repeats: true)
//                }
//
//            } else {
//
//                displayAlert(title: "Error", message: "Audio file is missing.")
//            }
//
//        }
//
//    }
    
    
    @objc func updateAudioMeter(timer: Timer) {
        
        if isRecording && !isPaused {
            
            let hr = Int(seconds / 3600)
            let min = Int(seconds / 60) % 60
            let sec = Int(seconds % 60)
            let timeString = String(format: "%02d:%02d:%02d", hr, min, sec)
            timeLabel.text = timeString
            seconds += 1
        }
        
        if isPlaying && !isPaused {
            
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
        pauseButton.isHidden = true
        isRecording = false
        timeLabel.text = "00:00:00"
    }
    
    
    func finishAudioPlaying(success: Bool) {
        
        if !success {
            
            displayAlert(title: "Error", message: "Could not play audio file.")
        }
        
        meterTimer.invalidate()
        audioPlayer.stop()
        pauseButton.isHidden = true
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
        setupTableView()
    }
    
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
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



//MARK: - TableView Methods
extension ViewController: UITableViewDelegate, UITableViewDataSource {
    
    func setupTableView() {
        recordingsTableView.delegate = self
        recordingsTableView.dataSource = self
        //cityListTableView.tableFooterView = UIView()
        //cityListTableView.rowHeight = 80.0
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "recordingCell", for: indexPath)
        cell.textLabel?.text = "Recording 1"
        return cell
    }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("Row selected: \(indexPath.row)")
    }
    
}
