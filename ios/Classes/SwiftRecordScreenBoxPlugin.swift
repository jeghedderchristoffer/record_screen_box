import Flutter
import UIKit
import ReplayKit
import Photos

public class SwiftRecordScreenBoxPlugin: NSObject, FlutterPlugin {
    let recorder = RPScreenRecorder.shared()
    var videoOutputURL : URL?
    var videoWriter : AVAssetWriter?
    var audioInput:AVAssetWriterInput!
    var videoWriterInput : AVAssetWriterInput?
    var nameVideo: String = ""
    var myResult: FlutterResult?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "screen_recorder_box", binaryMessenger: registrar.messenger())
        let instance = SwiftRecordScreenBoxPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("CALLED")
        if(call.method == "startScreenRecording"){
            print("START")
            myResult = result
            let args = call.arguments as? Dictionary<String, Any>
            
            self.nameVideo = (args?["name"] as? String)!+".mp4"
            let stringURL : String? = args?["path"] as? String
            var isDir:ObjCBool = true
            
            if stringURL != nil {
                let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
                self.videoOutputURL = URL(fileURLWithPath: documentsPath.appendingPathComponent(nameVideo))
                //Checks if the path given does not exist or if it isn't a directory
            } else if !(!FileManager.default.fileExists(atPath: stringURL! , isDirectory: &isDir)) {
                let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
                self.videoOutputURL = URL(fileURLWithPath: documentsPath.appendingPathComponent(nameVideo))
                //Path exists
            } else{
                let _ : URL = URL(string: stringURL!)!
                self.videoOutputURL = URL(string: stringURL!)!
            }
            
            print(self.videoOutputURL?.absoluteString as Any)
            startRecording()
        }else if(call.method == "stopScreenRecording"){
            if(videoWriter != nil){
                stopRecording()
                let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
                result(String(documentsPath.appendingPathComponent(nameVideo)))
            }
            result("")
        }
    }
    
    
    
    @objc func startRecording() {
        //Use ReplayKit to record the screen
        //Create the file path to write to
        //let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        //self.videoOutputURL = URL(fileURLWithPath: documentsPath.appendingPathComponent(nameVideo))
        //Check the file does not already exist by deleting it if it does
        do {
            try FileManager.default.removeItem(at: videoOutputURL!)
        } catch {
            
        }
        
        do {
            try videoWriter = AVAssetWriter(outputURL: videoOutputURL!, fileType: AVFileType.mp4)
        } catch let writerError as NSError {
            print("Error opening video file", writerError);
            videoWriter = nil;
            return;
        }
        
        //Create the video and audio settings
        if #available(iOS 11.0, *) {
            recorder.isMicrophoneEnabled = true
            
            let videoSettings: [String : Any] = [
                AVVideoCodecKey  : AVVideoCodecH264,
                AVVideoWidthKey  : UIScreen.main.bounds.width,
                AVVideoHeightKey : UIScreen.main.bounds.height,
                AVVideoCompressionPropertiesKey: [
                    //AVVideoQualityKey: 1,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                    AVVideoAverageBitRateKey: 6000000
                ],
            ]
            
            //Create the asset writer input object which is actually used to write out the video
            self.videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings);
            self.videoWriterInput?.expectsMediaDataInRealTime = true;
            self.videoWriter?.add(videoWriterInput!);
            let audioOutputSettings: [String : Any] = [
                AVNumberOfChannelsKey : 2,
                AVFormatIDKey : kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            //Create the asset writer input object which is actually used to write out the audio
            self.audioInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: audioOutputSettings)
            self.audioInput?.expectsMediaDataInRealTime = true;
            self.videoWriter?.add(audioInput!);
        }
        
        //Tell the screen recorder to start capturing and to call the handler
        if #available(iOS 11.0, *) {
            
            recorder.startCapture(handler: { (cmSampleBuffer, rpSampleType, error) in
                guard error == nil else {
                    //Handle error
                    print("Error starting capture");
                    self.myResult!(false)
                    return;
                }
                
                switch rpSampleType {
                case RPSampleBufferType.video:
                    print("Writing video...");
                    if self.videoWriter?.status == AVAssetWriter.Status.unknown {
                        self.myResult!(true)
                        self.videoWriter?.startWriting()
                        self.videoWriter?.startSession(atSourceTime:  CMSampleBufferGetPresentationTimeStamp(cmSampleBuffer))
                    }else if self.videoWriter?.status == AVAssetWriter.Status.writing {
                        if (self.videoWriterInput?.isReadyForMoreMediaData == true) {
                            print("Append sample...");
                            if  self.videoWriterInput?.append(cmSampleBuffer) == false {
                                print("Problems writing video")
                                self.myResult!(false)
                            }
                        }
                    }
                case RPSampleBufferType.audioMic:
                    print("Writing audio....");
                    if self.audioInput?.isReadyForMoreMediaData == true {
                        print("starting audio....");
                        if self.audioInput?.append(cmSampleBuffer) == false {
                            print("Problems writing audio")
                        }
                    }
                default:
                    print("not a video sample, so ignore");
                }
            } ){(error) in
                guard error == nil else {
                    //Handle error
                    print("Screen record not allowed");
                    self.myResult!(false)
                    return;
                }
            }
        } else {
            //Fallback on earlier versions
        }
    }
    
    @objc func stopRecording() {
        //Stop Recording the screen
        if #available(iOS 11.0, *) {
            recorder.stopCapture( handler: { (error) in
                print("Stopping recording...");
            })
        } else {
            //  Fallback on earlier versions
        }
        
        self.videoWriterInput?.markAsFinished();
        self.audioInput?.markAsFinished();
        
        self.videoWriter?.finishWriting {
            print("Finished writing video");
            //Now save the video
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: self.videoOutputURL!)
            })
        }
    }
}
