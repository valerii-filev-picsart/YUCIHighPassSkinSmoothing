//
//  DrawViewController.swift
//  YUCIHighPassSkinSmoothingDemo
//
//  Created by Valera on 06/02/2020.
//  Copyright © 2020 YuAo. All rights reserved.
//

import Foundation
import UIKit
import GLKit
import AVFoundation
import YUCIHighPassSkinSmoothing

class DrawViewController: UIViewController, GLKViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    var context : EAGLContext!
    var ciContext : CIContext!
    @IBOutlet weak var glView: GLKView!
    @IBOutlet weak var sliderRadius: UISlider!
    @IBOutlet weak var sliderAmount: UISlider!
    
    var filter = YUCIHighPassSkinSmoothing()
        
    var inputCIImage = CIImage(cgImage: UIImage(named: "SampleImage")!.cgImage!)
    var previousCIImage = CIImage(cgImage: UIImage(named: "SampleImage")!.cgImage!)
    
    var mask: CIImage?
    
    var point: CGPoint = CGPoint(x: 0, y: 0)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        self.context = EAGLContext(api: .openGLES2)
        self.ciContext = CIContext(eaglContext: self.context, options: [.workingColorSpace: colorSpace])
        self.glView.context = self.context
        
        let sz = CGSize(width: inputCIImage.extent.size.width / 3, height: inputCIImage.extent.size.height / 3)
        self.mask = CIImage(cgImage: UIImage(color: .black, size: sz)!.cgImage!)

//        self.glView.setNeedsDisplay()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.glView.display()
    }
    
    func reset() {
        let sz = CGSize(width: inputCIImage.extent.size.width / 3, height: inputCIImage.extent.size.height / 3)
        self.mask = CIImage(cgImage: UIImage(color: .black, size: sz)!.cgImage!)
    }
    
    @IBAction func chooseImage(_ sender: Any) {
//        let imagePickerController = UIImagePickerController()
//        imagePickerController.view.backgroundColor = UIColor.white
//        imagePickerController.delegate = self
//        self.present(imagePickerController, animated: true, completion: nil)
//        saveImage(image: glView.snapshot, name: "smooth_result.png")
        UIImageWriteToSavedPhotosAlbum(glView.snapshot, nil, nil, nil)
    }
        
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
        
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        self.dismiss(animated: true, completion: nil)
            
        if let image = info[.originalImage] as? UIImage {
            self.inputCIImage = CIImage(cgImage: image.cgImage!).oriented(forExifOrientation: Int32(image.imageOrientation.rawValue))
            filter = YUCIHighPassSkinSmoothing()
            reset()
            self.glView.display()
        }
    }
    
    @IBAction func radiusTouch(_ sender: Any) {
        reset()
        self.glView.display()
    }
    
    @IBAction func amountTouch(_ sender: Any) {
        reset()
        self.glView.display()
    }
    
    @IBAction func panGesture(_ sender: UIPanGestureRecognizer) {
        self.point = sender.location(in: glView)
        self.glView.display()
    }
    
    func glkView(_ view: GLKView, drawIn rect: CGRect) {
        let amount = 0.7//abs(sin(NSDate().timeIntervalSince(self.startDate as Date)) * 0.7)
        self.title = String(format: "Input Amount: %.3f", amount)
        self.filter.inputImage = self.inputCIImage
        self.filter.inputAmount = self.sliderAmount.value as NSNumber
        self.filter.inputRadius = 7.0 * self.inputCIImage.extent.width/750.0 as NSNumber
        self.filter.inputSharpnessFactor = 0
        let outputCIImage = self.filter.outputImage!
        
        let scale = CGAffineTransform(scaleX: self.glView.contentScaleFactor, y: self.glView.contentScaleFactor)
        let bounds = self.glView.bounds.applying(scale)
        
        var vicPoint = self.point.applying(scale)
        vicPoint.y = bounds.height - vicPoint.y

        let pp = vicPoint.applying(CGAffineTransform(scaleX: self.mask!.extent.width / bounds.width, y: self.mask!.extent.height / bounds.height))
        let circle = CIFilter(name: "CIRadialGradient", parameters:[
            "inputCenter": CIVector(cgPoint: vicPoint),
            "inputRadius0":self.sliderRadius.value * 100,
            "inputRadius1":self.sliderRadius.value * 100 + 10,
            "inputColor0":CIColor(red: 1, green: 1, blue: 1, alpha:1),
            "inputColor1":CIColor(red: 0, green: 0, blue: 0, alpha:0)
            ])?.outputImage!
        
        let addedMask = CIFilter(name: "CIAdditionCompositing", parameters: ["inputBackgroundImage": mask, "inputImage":circle])?.outputImage!
//        let addedMask = circle?.composited(over: mask!)
//
        let maskAlpha = CIFilter(name: "CIMaskToAlpha", parameters: [kCIInputImageKey:addedMask!])?.outputImage!
        let combine = CIFilter(name: "CIBlendWithAlphaMask", parameters:[
            kCIInputMaskImageKey:maskAlpha!,
            kCIInputImageKey:outputCIImage,
            kCIInputBackgroundImageKey: self.inputCIImage
            ])?.outputImage!
                
//        self.ciContext.draw(combine!, in: AVMakeRect(aspectRatio: outputCIImage.extent.size, insideRect: bounds), from: combine!.extent)
        self.ciContext.draw(combine!, in: AVMakeRect(aspectRatio: outputCIImage.extent.size, insideRect: bounds), from: combine!.extent)
        
        let cgImage = self.ciContext.createCGImage(addedMask!, from: combine!.extent)
        self.mask = CIImage(cgImage: cgImage!)
        
//        self.ciContext.draw(outputCIImage, in: rect, from: outputCIImage.extent)
    }
}

public extension UIImage {
  public convenience init?(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) {
    let rect = CGRect(origin: .zero, size: size)
    UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
    color.setFill()
    UIRectFill(rect)
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    guard let cgImage = image?.cgImage else { return nil }
    self.init(cgImage: cgImage)
  }
}
