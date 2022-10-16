//
//  ContentView.swift
//  ARApp
//
//  Created by Mridang Sheth on 10/15/22.
//

import SwiftUI
import RealityKit
import ARKit
import AVFoundation

struct ContentView : View {
    @State var sceneDepthStr: String
    @State var frameImage: CVPixelBuffer?
    
    let classifier = Classifier()
    
    var body: some View {
        ZStack {
            ARViewContainer(sceneDepthStr: $sceneDepthStr, frameImage: $frameImage).edgesIgnoringSafeArea(.all)
            VStack {
                Text("Distance: \(self.sceneDepthStr) cm")
                    .background(Color.gray.opacity(0.65))
                    .foregroundColor(Color.white)
                    .multilineTextAlignment(.center)
                    .padding()
                    .font(.title)
                    .bold()
                    
                Spacer()
                Text("Tap Anywhere!")
                    .background(Color.gray.opacity(0.65))
                    .foregroundColor(Color.white)
                    .multilineTextAlignment(.center)
                    .padding()
                    .font(.title)
                    .bold()
            }
            
            Button(
                action: {
                    if let frameImage = self.frameImage {
                        Speaker.sharedInstance.speak(text: "Identifying Objects")
                        
                        self.classifier.classifyImage(cvPixelBuffer: frameImage)
                        print("Picture taken")
                    }
                }
            ) {
                Text("").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    
}

struct ARViewContainer: UIViewRepresentable {
    
    @Binding var sceneDepthStr: String
    @Binding var frameImage: CVPixelBuffer?
    
    func makeUIView(context: Context) -> ARView {
        
        let arView = ARView(frame: .zero)
        
        // Start AR session
        let session = arView.session
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            config.frameSemantics = .smoothedSceneDepth
        } else {
            // TODO: Raise Error
        }
        session.delegate = context.coordinator
        session.run(config)

        // Add coaching overlay
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coachingOverlay.session = session
        coachingOverlay.goal = .horizontalPlane
        arView.addSubview(coachingOverlay)
        
        
        
        return arView
        
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(sceneDepthStr: $sceneDepthStr, frameImage: $frameImage)
    }
    
    class Coordinator: NSObject, ARSessionDelegate, AVAudioPlayerDelegate {
        @Binding var sceneDepthStr: String
        @Binding var frameImage: CVPixelBuffer?
        
        var isAudioPlaying: Bool = false
        var readDistance: Bool = false
        
        var audioPlayer: AVAudioPlayer!
        
        var repeatFreq:Float = 5.0
        
        init(sceneDepthStr: Binding<String>, frameImage: Binding<CVPixelBuffer?>) {
            _sceneDepthStr = sceneDepthStr
            _frameImage = frameImage
            let beepFile = URL(filePath: Bundle.main.path(forResource: "beep", ofType: "m4a")!)
            audioPlayer =  try? AVAudioPlayer(contentsOf: beepFile)
            super.init()
            audioPlayer.delegate = self
        }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            self.frameImage = frame.capturedImage
            if let sceneDepth = frame.smoothedSceneDepth {
                let depthData = sceneDepth.depthMap
                let depthWidth = CVPixelBufferGetWidth(depthData) // 256
                let depthHeight = CVPixelBufferGetHeight(depthData) // 192
                
                CVPixelBufferLockBaseAddress(depthData, CVPixelBufferLockFlags(rawValue: 0))
                let floatBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(depthData), to: UnsafeMutablePointer<Float32>.self)
                var minDist: Float32 = 1000000
                for x in 71...121 { //width (0 to 192-1)
                    for y in 103...178 { //height (0 to 256-1)
                        let distXY = floatBuffer[x * depthWidth + y]
                        if minDist > distXY {
                            minDist = distXY
                        }
                    }
                }
                let roundedDist = round(minDist * 100) / 100.0
                DispatchQueue.main.async { [weak self] in
                    self?.sceneDepthStr = "\(Int(roundedDist * 100))"
                    var repeatFreq: Float = 0
                    if roundedDist <= 1 {
                        if !self!.readDistance {
                            self?.readDistance = true
                            Speaker.sharedInstance.speak(text: "Object 3 feet ahead")
                        }
                        repeatFreq = roundedDist * 3
                        if roundedDist < 0.25 {
                            repeatFreq *= 1/5
                        } else if roundedDist < 0.5 {
                            repeatFreq *= 1/2
                        }
                        self?.repeatFreq = repeatFreq
                        
                        if !self!.isAudioPlaying {
                            self?.isAudioPlaying = true
                            self?.audioPlayer.prepareToPlay()
                            self?.playBeep()
                        }
                    } else {
                        if self!.readDistance {
                            self?.readDistance = false
                        }
                        if self!.isAudioPlaying {
                            self?.isAudioPlaying = false
                            self?.audioPlayer.stop()
                        }
                    }
                }
            }
        }
        
        
        @objc func playBeep() {
            audioPlayer.play()
        }
        
        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            if isAudioPlaying {
                self.perform(#selector(playBeep), with: nil, afterDelay: Double(self.repeatFreq))
            }
        }
        
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
}


#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView(sceneDepthStr: "")
    }
}
#endif


class Speaker {
    static let sharedInstance = Speaker()
    let speechSynthesizer = AVSpeechSynthesizer()
    
    func speak(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.pitchMultiplier = 1.0
        utterance.rate = 0.6
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        speechSynthesizer.speak(utterance)
    }
}

struct Classifier {
    
    var visionModel: VNCoreMLModel = {
        do {
            let modelToBeUsed = try? YOLOv3(configuration: MLModelConfiguration()).model
            return try VNCoreMLModel(for: modelToBeUsed!)
        } catch {
            fatalError("⚠️ Failed to create VNCoreMLModel: \(error)")
        }
    }()
    
    func convertImage(cvPixelbuffer: CVPixelBuffer) -> CVPixelBuffer {
        var ciImage = CIImage(cvPixelBuffer: cvPixelbuffer)
        let image = UIImage(ciImage: ciImage)
        

        UIGraphicsBeginImageContext(CGSize(width: 416, height: 416))
        image.draw(in: CGRect(x: 0, y: 0, width: 416, height: 416))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        // Convert UIImage to CVPixelBuffer
        // The code for the conversion is adapted from this post of StackOverflow
        // https://stackoverflow.com/questions/44462087/how-to-convert-a-uiimage-to-a-cvpixelbuffer

        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(resizedImage.size.width), Int(resizedImage.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard (status == kCVReturnSuccess) else {
            return cvPixelbuffer
        }

        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)

        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: Int(resizedImage.size.width), height: Int(resizedImage.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

        context?.translateBy(x: 0, y: resizedImage.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)

        UIGraphicsPushContext(context!)
        resizedImage.draw(in: CGRect(x: 0, y: 0, width: resizedImage.size.width, height: resizedImage.size.height))
        UIGraphicsPopContext()

        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        return pixelBuffer!
    }
    
    func classifyImage(cvPixelBuffer: CVPixelBuffer) {
        var visionRequest: VNCoreMLRequest = {
            // 1. Create the completion handler for the analysis request
            var requestCompletionHandler: VNRequestCompletionHandler = { request, error in
                if let results = request.results as? [VNRecognizedObjectObservation] {
                    /**
                     * In here you do something with the request results.
                     * In this example we will just list the detected objects.
                     */
                    let detectionConfidenceThreshold: Float = 0.80
                    for result in results {
                        let resultDetectionConfidence = result.labels.first?.confidence ?? 0
                        if  resultDetectionConfidence >= detectionConfidenceThreshold {
                            let detectedObject = result.labels.first?.identifier ?? "Nothing"
                            let detectedObjectConfidence = result.labels.first?.confidence ?? 0
                            print("\(detectedObject) detected with \(detectedObjectConfidence) confidence")
                            Speaker.sharedInstance.speak(text: "\(detectedObject) detected")
                        } else {
                            print("The result does not match the confidence threshold \(resultDetectionConfidence) \(result.labels.first?.identifier ?? "Nothing").")
                            Speaker.sharedInstance.speak(text: "confidence threshold not met")
                        }
                    }
                    if results.isEmpty {
                        Speaker.sharedInstance.speak(text: "Nothing detected")
                    }
                } else {
                    print("Error while getting the request results.")
                }
            }
            
            // 2. Create the request with the model container and completion handler
            let request = VNCoreMLRequest(model: visionModel,
                                          completionHandler: requestCompletionHandler)
            
            // 3. Inform the Vision algorithm how to scale the input image
            request.imageCropAndScaleOption = .scaleFill
            
            return request
        }()
        
        // 1. Create the handler, which will perform requests on a single image
        let handler = VNImageRequestHandler(cvPixelBuffer: self.convertImage(cvPixelbuffer: cvPixelBuffer))

        // 2. Performs the image analysis request on the image.
        do {
            try handler.perform([visionRequest])
        } catch {
            print("Failed to perform the Vision request: \(error)")
        }
    }
    
}
