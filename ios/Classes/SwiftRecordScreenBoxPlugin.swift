import Flutter
import UIKit
import ReplayKit
import Photos

public class SwiftRecordScreenBoxPlugin: NSObject, FlutterPlugin {
    let recorder = RPScreenRecorder.shared()
    
    var videoName: String = ""
    var pathToSaveRecording: URL?
    
    var videoWriter: AVAssetWriter?
    var videoWriterInput: AVAssetWriterInput?
    
    var audioWriterInput: AVAssetWriterInput!
    
    var result: FlutterResult?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "screen_recorder_box", binaryMessenger: registrar.messenger())
        let instance = SwiftRecordScreenBoxPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let method = call.method
        
        // Start recording
        if (method == "startScreenRecording") {
            print("startScreenRecording")
            self.initializeProperties(call: call, result: result)
            self.startRecording()
            
            // Stop recording
        } else if (method == "stopScreenRecording") {
            print("stopScreenRecording")
            self.stopRecording()
            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
            result(String(documentsPath.appendingPathComponent(videoName)))
            // Pause recording
        } else if (method == "pauseScreenRecording") {
            print("NOT SUPPORTED ON IOS")
            // Resume recording
        } else if (method == "resumeScreenRecording") {
            print("NOT SUPPORTED ON IOS")
            // Is recording
        } else if (method == "isRecording") {
            print("isRecording")
            result(self.recorder.isRecording)
            // Has been started
        } else if (method == "hasBeenStarted") {
            print("hasBeenStarted")
            result(self.recorder.isRecording)
        }
    }
    
    func initializeProperties(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as! Dictionary<String, Any>
        
        // Set values from arguments passed to ios
        self.videoName = arguments["name"]! as! String
        
        let path = arguments["path"]! as! String
        self.pathToSaveRecording = URL(fileURLWithPath: path.appending(self.videoName))
        
        self.result = result
    }
    
    @objc func startRecording() {
        // First remove the previous video if any
        do {
            try FileManager.default.removeItem(at: self.pathToSaveRecording!)
        } catch {
            // No video found, which is okay. Nothing to do here...
        }
        
        // Not really sure what this is...
        do {
            try videoWriter = AVAssetWriter(outputURL: self.pathToSaveRecording!, fileType: AVFileType.mp4)
        } catch let writerError as NSError {
            print("Error opening video file: ", writerError);
            videoWriter = nil;
            self.result!(false)
        }
        
        // Enable audio on recorder
        recorder.isMicrophoneEnabled = true
        
        // Configure video settings
        let videoSettings: [String : Any] = [
            AVVideoCodecKey  : AVVideoCodecType.h264,
            AVVideoWidthKey  : UIScreen.main.bounds.width,
            AVVideoHeightKey : UIScreen.main.bounds.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoAverageBitRateKey: 6000000
            ],
        ]
        
        // Create the asset writer input object which is actually used to write out the video
        self.videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings);
        self.videoWriterInput?.expectsMediaDataInRealTime = true;
        self.videoWriter?.add(videoWriterInput!);
        
        // Configure audio settings
        let audioOutputSettings: [String : Any] = [
            AVNumberOfChannelsKey : 2,
            AVFormatIDKey : kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        // Create the asset writer input object which is actually used to write out the audio
        self.audioWriterInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: audioOutputSettings)
        self.audioWriterInput?.expectsMediaDataInRealTime = true;
        self.videoWriter?.add(audioWriterInput!);
        
        print("START CAPTURE")
        self.recorder.startCapture { buffer, type, error in
            print("CAPTURE")
        } completionHandler: { error in
            print("COMPLETE")
        }

        /*self.recorder.startCapture(handler: { (cmSampleBuffer, rpSampleType, error) in
            print("STARTED????")
            guard error == nil else {
                //Handle error
                print("Error starting capture");
                self.result!(false)
                return;
            }
            
            print("SAMPLE TYPE")
            print(rpSampleType)
            
            // If video sample type
            if (rpSampleType == RPSampleBufferType.video) {
                print("Writing video...");
                
                if (self.videoWriter?.status == AVAssetWriter.Status.unknown) {
                    self.result!(true)
                    self.videoWriter?.startWriting()
                    self.videoWriter?.startSession(atSourceTime:  CMSampleBufferGetPresentationTimeStamp(cmSampleBuffer))
                }
                
                if (self.videoWriter?.status == AVAssetWriter.Status.writing) {
                    if (self.videoWriterInput?.isReadyForMoreMediaData == true) {
                        print("Append sample...");
                        if  self.videoWriterInput?.append(cmSampleBuffer) == false {
                            print("Problems writing video")
                            self.result!(false)
                        }
                    }
                }
            }
            
            // If audio sample type
            if (rpSampleType == RPSampleBufferType.audioMic) {
                print("Writing audio....");
                if self.audioWriterInput?.isReadyForMoreMediaData == true {
                    print("starting audio....");
                    if self.audioWriterInput?.append(cmSampleBuffer) == false {
                        print("Problems writing audio")
                    }
                }
            }
        }){(error) in
            print("HERE")
            print(error)
            guard error == nil else {
                //Handle error
                print("Screen record not allowed");
                self.result!(false)
                return;
            }
        }*/
        
        print("END OF START SCREEN RECORDING")
    }
    
    @objc func stopRecording() {
        //Stop Recording the screen
        self.recorder.stopCapture( handler: { (error) in
            print("Stopping recording...");
        })
        
        self.videoWriterInput?.markAsFinished();
        self.audioWriterInput?.markAsFinished();
        
        self.videoWriter?.finishWriting {
            print("Finished writing video");
            
            //Now save the video
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: self.pathToSaveRecording!)
            })
        }
    }
}
