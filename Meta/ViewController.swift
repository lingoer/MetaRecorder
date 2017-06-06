//
//  ViewController.swift
//  Meta
//
//  Created by Ruoyu Fu on 22/5/2017.
//  Copyright © 2017 Ruoyu. All rights reserved.
//

import UIKit
import CoreMotion
import CoreVideo
import AVFoundation

class ViewController: UIViewController {

    let manager = CMMotionManager()

    @IBOutlet weak var imageView: UIImageView!

    @IBOutlet weak var x: UILabel!
    @IBOutlet weak var y: UILabel!
    @IBOutlet weak var z: UILabel!

    @IBOutlet weak var rotation: UILabel!
    let session = AVCaptureSession()
    let output = AVCaptureVideoDataOutput()
    let semaphore = DispatchSemaphore(value: 1)
    var dataPath: URL!

    override func viewDidLoad() {
        super.viewDidLoad()
        let documentsPath = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
        dataPath = documentsPath.appendingPathComponent("data")
        print(dataPath)
        try? FileManager.default.createDirectory(at: dataPath, withIntermediateDirectories: true, attributes: nil)
        videoInit()
        if manager.isDeviceMotionAvailable {
            manager.deviceMotionUpdateInterval = 0.001
            manager.startDeviceMotionUpdates()
        }
    }

    func videoInit() {
        let queue = DispatchQueue(label: "com.video.queue")
        output.setSampleBufferDelegate(self, queue: queue)
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable: kCVPixelFormatType_32BGRA]
        guard let videoDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo) else { return }
        try? session.addInput(AVCaptureDeviceInput(device: videoDevice))
        session.addOutput(output)
        output.connection(withMediaType: AVMediaTypeVideo).videoOrientation = .portrait
        session.sessionPreset = AVCaptureSessionPreset352x288
        session.startRunning()
    }


}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate{

    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        guard let motion = manager.deviceMotion else {return}
        guard let imageBuff = CMSampleBufferGetImageBuffer(sampleBuffer) else {return}
        CVPixelBufferLockBaseAddress(imageBuff, .readOnly)
        defer{ CVPixelBufferUnlockBaseAddress(imageBuff, .readOnly) }
        let baseAddress = CVPixelBufferGetBaseAddress(imageBuff)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuff)
        let width = CVPixelBufferGetWidth(imageBuff)
        let height = CVPixelBufferGetHeight(imageBuff)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: baseAddress,width: width,height: height,bitsPerComponent: 8,bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) else { return }
        let quartzImage = context.makeImage()

        if let quartzImage = quartzImage {
            let image = UIImage(cgImage: quartzImage)
            DispatchQueue.main.async {
                self.imageView.image = image
            }
            let time = Int(Date().timeIntervalSince1970*100)
            let jpgFilename = dataPath.appendingPathComponent("\(time).jpg")
            let labelFilename = dataPath.appendingPathComponent("\(time).bin")

            let jpgData = UIImageJPEGRepresentation(image, 0.5)
            let label = [motion.rotationRate.x, motion.rotationRate.y, motion.rotationRate.z,
                motion.attitude.rotationMatrix.m11,
                motion.attitude.rotationMatrix.m12,
                motion.attitude.rotationMatrix.m13,
                motion.attitude.rotationMatrix.m21,
                motion.attitude.rotationMatrix.m22,
                motion.attitude.rotationMatrix.m23,
                motion.attitude.rotationMatrix.m31,
                motion.attitude.rotationMatrix.m32,
                motion.attitude.rotationMatrix.m33].map{Float($0)}
            let labelData = Data(bytes:label, count:label.count*MemoryLayout<Float>.size)
            try? jpgData?.write(to: jpgFilename)
            try? labelData.write(to: labelFilename)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.semaphore.signal()
        }
    }
}














