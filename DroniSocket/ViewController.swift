//
//  ViewController.swift
//  DroniSocket
//
//  Created by Gweltaz calori on 09/02/2019.
//  Copyright © 2019 Gweltaz calori. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController,AVCaptureVideoDataOutputSampleBufferDelegate {

    
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var trackingView: TrackingView!
    
    var objectsToTrack = [TrackedPolyRect]()
    var selectedBounds:TrackedPolyRect?
    
    lazy var sequenceRequestHandler = VNSequenceRequestHandler()
    private var trackingRequests: [VNTrackObjectRequest] = []
    
    private lazy var cameraLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
 
    private lazy var captureSession: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = AVCaptureSession.Preset.photo
        guard
            let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: backCamera)
            else { return session }
        session.addInput(input)
        return session
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        cameraView?.layer.addSublayer(cameraLayer)
        cameraLayer.frame = cameraView.bounds
        
        trackingView.imageAreaRect = cameraView.bounds
        
        //        cameraLayer.videoGravity = .resizeAspectFill
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "MyQueue"))
        self.captureSession.addOutput(videoOutput)
        self.captureSession.startRunning()
    }

    func exifOrientationForDeviceOrientation(_ deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        
        switch deviceOrientation {
        case .portraitUpsideDown:
            return .rightMirrored
            
        case .landscapeLeft:
            return .downMirrored
            
        case .landscapeRight:
            return .upMirrored
            
        default:
            return .leftMirrored
        }
    }
    
    
    func exifOrientationForCurrentDeviceOrientation() -> CGImagePropertyOrientation {
        return exifOrientationForDeviceOrientation(UIDevice.current.orientation)
    }
    
    @IBAction func clear(_ sender: Any) {
        self.selectedBounds = nil
        trackingView.rubberbandingStart = CGPoint.zero
        trackingView.rubberbandingVector = CGPoint.zero
        trackingView.setNeedsDisplay()
    }
    
    @IBAction func startTracking(_ sender: Any) {
        
        if let rect = selectedBounds {
            let inputObservation = VNDetectedObjectObservation(boundingBox: rect.boundingBox)
            let request = VNTrackObjectRequest(detectedObjectObservation: inputObservation)
            
            request.trackingLevel = .fast
            
            trackingRequests.append(request)
        }
        
        clear(self)
        
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let exifOrientation = self.exifOrientationForCurrentDeviceOrientation()
        
        
        do {
            try self.sequenceRequestHandler.perform(self.trackingRequests,
                                                    on: pixelBuffer,
                                                    orientation: exifOrientation)
        } catch let error as NSError {
            NSLog("Failed to perform SequenceRequest: %@", error)
        }
        
        for trackingRequest in self.trackingRequests {
            
            guard let results = trackingRequest.results else {
                return
            }
            
            guard let observation = results[0] as? VNDetectedObjectObservation else {
                return
            }
            
            
            self.trackingView.polyRect = TrackedPolyRect(observation: observation, color: UIColor.black, style: .solid)
        }
        
        DispatchQueue.main.async {
            self.trackingView.setNeedsDisplay()
            
        }
        
        
    
    }
    
    
    
    @IBAction func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            let locationInView = gestureRecognizer.location(in: trackingView)
            trackingView.rubberbandingStart = locationInView
        case .changed:
            let translation = gestureRecognizer.translation(in: trackingView)
      
            trackingView.rubberbandingVector = translation
            trackingView.setNeedsDisplay()
        case .ended:
            let selectedBBox = trackingView.rubberbandingRectNormalized
            if selectedBBox.width > 0 && selectedBBox.height > 0 {
                let rectColor = TrackedObjectsPalette.color(atIndex: self.objectsToTrack.count)
                self.selectedBounds = TrackedPolyRect(cgRect: selectedBBox, color: rectColor)
            }
        default:
            break
        }
    }
    
}

enum TrackedObjectType: Int {
    case object
    case rectangle
}

enum TrackedPolyRectStyle: Int {
    case solid
    case dashed
}

struct TrackedObjectsPalette {
    static var palette = [
        UIColor.green,
        UIColor.cyan,
        UIColor.orange,
        UIColor.brown,
        UIColor.darkGray,
        UIColor.red,
        UIColor.yellow,
        UIColor.magenta,
        #colorLiteral(red: 0, green: 1, blue: 0, alpha: 1), // light green
        UIColor.gray,
        UIColor.purple,
        UIColor.clear,
        #colorLiteral(red: 0, green: 0.9800859094, blue: 0.941437602, alpha: 1),   // light blue
        UIColor.lightGray,
        UIColor.black,
        UIColor.blue
    ]
    
    static func color(atIndex index: Int) -> UIColor {
        if index < palette.count {
            return palette[index]
        }
        return randomColor()
    }
    
    static func randomColor() -> UIColor {
        func randomComponent() -> CGFloat {
            return CGFloat(arc4random_uniform(256)) / 255.0
        }
        return UIColor(red: randomComponent(), green: randomComponent(), blue: randomComponent(), alpha: 1.0)
    }
}

struct TrackedPolyRect {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomLeft: CGPoint
    var bottomRight: CGPoint
    var color: UIColor
    var style: TrackedPolyRectStyle
    
    var cornerPoints: [CGPoint] {
        return [topLeft, topRight, bottomRight, bottomLeft]
    }
    
    var boundingBox: CGRect {
        let topLeftRect = CGRect(origin: topLeft, size: .zero)
        let topRightRect = CGRect(origin: topRight, size: .zero)
        let bottomLeftRect = CGRect(origin: bottomLeft, size: .zero)
        let bottomRightRect = CGRect(origin: bottomRight, size: .zero)
        
        return topLeftRect.union(topRightRect).union(bottomLeftRect).union(bottomRightRect)
    }
    
    init(observation: VNDetectedObjectObservation, color: UIColor, style: TrackedPolyRectStyle = .solid) {
        self.init(cgRect: observation.boundingBox, color: color, style: style)
    }
    
    init(observation: VNRectangleObservation, color: UIColor, style: TrackedPolyRectStyle = .solid) {
        topLeft = observation.topLeft
        topRight = observation.topRight
        bottomLeft = observation.bottomLeft
        bottomRight = observation.bottomRight
        self.color = color
        self.style = style
    }
    
    init(cgRect: CGRect, color: UIColor, style: TrackedPolyRectStyle = .solid) {
        topLeft = CGPoint(x: cgRect.minX, y: cgRect.maxY)
        topRight = CGPoint(x: cgRect.maxX, y: cgRect.maxY)
        bottomLeft = CGPoint(x: cgRect.minX, y: cgRect.minY)
        bottomRight = CGPoint(x: cgRect.maxX, y: cgRect.minY)
        self.color = color
        self.style = style
    }
}
