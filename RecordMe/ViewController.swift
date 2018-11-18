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
    
    var fileNames: [String] = []
    let defaults = UserDefaults.standard
    
    @IBAction func recordTapped(_ sender: UIButton) {
        
        if !isRecording && !isPlaying {
            
            if setupRecorder() {
                
                audioRecorder.record()
                pauseButton.isHidden = false
                recordButton.setImage(UIImage(named: "stop"), for: .normal)
                isRecording = true
                meterTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.updateAudioMeter(timer:)), userInfo: nil, repeats: true)
            }
            
            return
        }
        
        if isRecording {
            
            audioRecorder.stop()
        }
        
        if isPlaying {
            
            finishAudioPlaying(success: true)
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
            
            let lastRecordingIndex = fileNames.count - 1
            fileNames.remove(at: lastRecordingIndex)
            defaults.set(fileNames, forKey: "storedNames")
            displayAlert(title: "Error", message: "Recording failed.")
        }
        
        meterTimer.invalidate()
        seconds = 1
        audioRecorder = nil
        pauseButton.isHidden = true
        recordButton.setImage(UIImage(named: "record"), for: .normal)
        isRecording = false
        timeLabel.text = "00:00:00"
        recordingsTableView.reloadData()
    }
    
    
    func finishAudioPlaying(success: Bool) {
        
        if !success {
            
            displayAlert(title: "Error", message: "Could not play audio file.")
        }
        
        meterTimer.invalidate()
        audioPlayer.stop()
        pauseButton.isHidden = true
        isPlaying = false
        pauseButton.isHidden = true
        recordButton.setImage(UIImage(named: "record"), for: .normal)
        timeLabel.text = "00:00:00"
    }
    
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        finishAudioRecording(success: flag)
    }
    
    
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        finishAudioPlaying(success: flag)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let storedNames = defaults.array(forKey: "storedNames") as? [String] {
            
            fileNames = storedNames
            recordingsTableView.reloadData()
        }
        
        checkRecordPermission()
        setupNotifications()
        setupTableView()
        setupLongPressGesture()
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
    func getFileUrl(fileName: String) -> URL {
        
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
                
                let fileName: String = "\(UUID().uuidString).m4a"
                let fileUrl: URL = getFileUrl(fileName: fileName)
                audioRecorder = try AVAudioRecorder(url: fileUrl, settings: settings)
                fileNames.append(fileName)
                defaults.set(fileNames, forKey: "storedNames")
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
    
    
    func setupPlay(url: URL) -> Bool {
        
        do {
            
            audioPlayer = try AVAudioPlayer(contentsOf: url)
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



//MARK: - TableView Methods & Long Gesture Recognizer
extension ViewController: UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate {
    
    func setupTableView() {
        recordingsTableView.delegate = self
        recordingsTableView.dataSource = self
        recordingsTableView.tableFooterView = UIView()
        recordingsTableView.rowHeight = 80.0
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fileNames.count
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "recordingCell", for: indexPath)
        cell.textLabel?.text = "Recording \(indexPath.row + 1)"
        return cell
    }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        playRecording(atUrl: getFileUrl(fileName: fileNames[indexPath.row]))
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    
    func playRecording(atUrl: URL) {
        
        if FileManager.default.fileExists(atPath: atUrl.path) {
            
            if setupPlay(url: atUrl) {
                
                audioPlayer.play()
                isPlaying = true
                pauseButton.isHidden = false
                recordButton.setImage(UIImage(named: "stop"), for: .normal)
                meterTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.updateAudioMeter(timer:)), userInfo: nil, repeats: true)
            }
            
        } else {
            
            displayAlert(title: "Error", message: "Audio file is missing.")
        }
        
    }
    
    
    func setupLongPressGesture() {
        let longPressGesture:UILongPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handleLongPress))
        longPressGesture.minimumPressDuration = 1.0 // 1 second press
        longPressGesture.delegate = self
        self.recordingsTableView.addGestureRecognizer(longPressGesture)
    }
    
    
    @objc func handleLongPress(_ gestureRecognizer: UILongPressGestureRecognizer){
        
        if gestureRecognizer.state == .ended {
            let touchPoint = gestureRecognizer.location(in: self.recordingsTableView)
            if let indexPath = recordingsTableView.indexPathForRow(at: touchPoint) {
                
                deleteRecording(index: indexPath.row)
            }
        }
        
    }
    
    func deleteRecording(index: Int) {
        
        do {
            
            try FileManager.default.removeItem(at: getFileUrl(fileName: fileNames[index]))
            fileNames.remove(at: index)
            defaults.set(fileNames, forKey: "storedNames")
            recordingsTableView.reloadData()
        } catch {
            
            displayAlert(title: "Error", message: "Could not delete recording.")
        }
        
    }
    
}
