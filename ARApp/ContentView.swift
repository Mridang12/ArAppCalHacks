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
    @State var supportsLIDAR: Bool = false
    @State var sceneDepthStr: String
    var body: some View {
        ZStack {
            ARViewContainer(supportsLIDAR: $supportsLIDAR, sceneDepthStr: $sceneDepthStr).edgesIgnoringSafeArea(.all)
            VStack {
                Spacer()
                Text("Supports LIDAR: \(supportsLIDAR.description)")
                Text("Depth: \(self.sceneDepthStr)")
                Spacer()
            }
            
            Button(
                action: {
                    Speaker.sharedInstance.speak(text: "Stop touching me.")
                    print("Picture taken")
                }
            ) {
                Text("Take a Picture").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    
}

struct ARViewContainer: UIViewRepresentable {
    
    @Binding var supportsLIDAR: Bool
    @Binding var sceneDepthStr: String
    
    func makeUIView(context: Context) -> ARView {
        
        let arView = ARView(frame: .zero)
        
        // Start AR session
        let session = arView.session
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            config.frameSemantics = .smoothedSceneDepth
            
            
            DispatchQueue.main.async {
                supportsLIDAR = true
            }
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
        return Coordinator(sceneDepthStr: $sceneDepthStr)
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        @Binding var sceneDepthStr: String
    
        init(sceneDepthStr: Binding<String>) {
            _sceneDepthStr = sceneDepthStr
        }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            if let sceneDepth = frame.smoothedSceneDepth {
                let depthData = sceneDepth.depthMap
                let depthWidth = CVPixelBufferGetWidth(depthData)
                let depthHeight = CVPixelBufferGetHeight(depthData)
                
                CVPixelBufferLockBaseAddress(depthData, CVPixelBufferLockFlags(rawValue: 0))
                let floatBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(depthData), to: UnsafeMutablePointer<Float32>.self)
                
                var minDist: Float32 = 1000000
                for y in 0...depthHeight-1 {
                    for x in 0...depthWidth-1 {
                        let distXY = floatBuffer[y * depthWidth + x]
                        if minDist > distXY {
                            minDist = distXY
                        }
                    }
                }
                self.sceneDepthStr = "\(round(minDist * 100) / 100.0)"
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
