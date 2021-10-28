//
//  ZLImageStickerView.swift
//  ZLImageEditor
//
//  Created by long on 2020/11/20.
//
//  Copyright (c) 2020 Long Zhang <495181165@qq.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import UIKit

protocol ZLStickerViewDelegate: NSObject {
    
    // Called when scale or rotate or move.
    func stickerBeginOperation(_ sticker: UIView)
    
    // Called during scale or rotate or move.
    func stickerOnOperation(_ sticker: UIView, panGes: UIPanGestureRecognizer)
    
    // Called after scale or rotate or move.
    func stickerEndOperation(_ sticker: UIView, panGes: UIPanGestureRecognizer)
    
    // Called when tap sticker.
    func stickerDidTap(_ sticker: UIView)
    
}


protocol ZLStickerViewAdditional: NSObject {
    
    var gesIsEnabled: Bool { get set }
    
    func resetState()
    
    func moveToAshbin()
    
    func addScale(_ scale: CGFloat)
    
}


class ZLImageStickerView: UIView, ZLStickerViewAdditional {

    static let edgeInset: CGFloat = 11
    
    static let borderWidth: CGFloat = 1
    
    weak var delegate: ZLStickerViewDelegate?
    
    var firstLayout = true
    
    var gesIsEnabled = true
    
    let originScale: CGFloat
    
    let originAngle: CGFloat
    
    var originFrame: CGRect
    
    var originTransform: CGAffineTransform = .identity
    
    let image: UIImage
    
    var pinchGes: UIPinchGestureRecognizer!
    
    var tapGes: UITapGestureRecognizer!
    
    var panGes: UIPanGestureRecognizer!
    
    var timer: Timer?
    
    var imageView: UIImageView!
    
    var totalTranslationPoint: CGPoint = .zero
    
    var gesTranslationPoint: CGPoint = .zero
    
    var gesRotation: CGFloat = 0
    
    var gesScale: CGFloat = 1
    
    var onOperation = false
    
    // Conver all states to model.
    var state: ZLImageStickerState {
        return ZLImageStickerState(image: self.image, originScale: self.originScale, originAngle: self.originAngle, originFrame: self.originFrame, gesScale: self.gesScale, gesRotation: self.gesRotation, totalTranslationPoint: self.totalTranslationPoint)
    }
    
    private let borderView = UIView()
    private let removeButton = UIButton(type: .custom)
    private let transformToolView = UIImageView()
    private let buttonSize = CGSize(width: 22, height: 22)
    
    deinit {
        self.cleanTimer()
    }
    
    convenience init(from state: ZLImageStickerState) {
        self.init(image: state.image, originScale: state.originScale, originAngle: state.originAngle, originFrame: state.originFrame, gesScale: state.gesScale, gesRotation: state.gesRotation, totalTranslationPoint: state.totalTranslationPoint, showBorder: false)
    }
    
    init(image: UIImage, originScale: CGFloat, originAngle: CGFloat, originFrame: CGRect, gesScale: CGFloat = 1, gesRotation: CGFloat = 0, totalTranslationPoint: CGPoint = .zero, showBorder: Bool = true) {
        self.image = image
        self.originScale = originScale
        self.originAngle = originAngle
        self.originFrame = originFrame
        
        super.init(frame: .zero)
        
        self.gesScale = gesScale
        self.gesRotation = gesRotation
        self.totalTranslationPoint = totalTranslationPoint
        
        self.hideBorder()
        if showBorder {
            self.startTimer()
        }
        
        self.imageView = UIImageView(image: image)
        self.imageView.contentMode = .scaleAspectFit
        self.imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = true
        self.addSubview(self.imageView)
        
        insertSubview(borderView, at: 0)
        borderView.layer.borderWidth = ZLImageStickerView.borderWidth
        borderView.layer.borderColor = UIColor.white.cgColor
        
        removeButton.frame = .init(origin: .zero, size: buttonSize)
        removeButton.setImage(getImage("rr_sticker_remove"), for: .normal)
        removeButton.addTarget(self, action: #selector(onRemoveSticker), for: .touchUpInside)
        addSubview(removeButton)
        
        transformToolView.image = getImage("rr_sticker_transform")
        transformToolView.isUserInteractionEnabled = true
        addSubview(transformToolView)

        self.panGes = UIPanGestureRecognizer(target: self, action: #selector(panAction(_:)))
        imageView.addGestureRecognizer(self.panGes)

        self.tapGes = UITapGestureRecognizer(target: self, action: #selector(tapAction(_:)))
        imageView.addGestureRecognizer(self.tapGes)
        
        let rotationGes = UIPanGestureRecognizer(target: self, action: #selector(rotationAction(_:)))
        transformToolView.addGestureRecognizer(rotationGes)
        
        self.pinchGes = UIPinchGestureRecognizer(target: self, action: #selector(pinchAction(_:)))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        guard self.firstLayout else {
            return
        }
        
        // Rotate must be first when first layout.
        self.transform = self.transform.rotated(by: self.originAngle.toPi)
        
        if self.totalTranslationPoint != .zero {
            if self.originAngle == 90 {
                self.transform = self.transform.translatedBy(x: self.totalTranslationPoint.y, y: -self.totalTranslationPoint.x)
            } else if self.originAngle == 180 {
                self.transform = self.transform.translatedBy(x: -self.totalTranslationPoint.x, y: -self.totalTranslationPoint.y)
            } else if self.originAngle == 270 {
                self.transform = self.transform.translatedBy(x: -self.totalTranslationPoint.y, y: self.totalTranslationPoint.x)
            } else {
                self.transform = self.transform.translatedBy(x: self.totalTranslationPoint.x, y: self.totalTranslationPoint.y)
            }
        }
        
        self.transform = self.transform.scaledBy(x: self.originScale, y: self.originScale)
        
        self.originTransform = self.transform
        
        if self.gesScale != 1 {
            self.transform = self.transform.scaledBy(x: self.gesScale, y: self.gesScale)
        }
        if self.gesRotation != 0 {
            self.transform = self.transform.rotated(by: self.gesRotation)
        }
        
        self.firstLayout = false
        
        borderView.frame = bounds.insetBy(dx: ZLImageStickerView.edgeInset, dy: ZLImageStickerView.edgeInset)
        imageView.frame = bounds.insetBy(dx: ZLImageStickerView.edgeInset * 2, dy: ZLImageStickerView.edgeInset * 2)
        transformToolView.frame = CGRect(x: bounds.width - buttonSize.width, y: bounds.height - buttonSize.height, width: buttonSize.width, height: buttonSize.height)
    }
    
    @objc private func onRemoveSticker() {
        moveToAshbin()
    }
    
    @objc func tapAction(_ ges: UITapGestureRecognizer) {
        guard self.gesIsEnabled else { return }
        
        self.superview?.bringSubviewToFront(self)
        self.delegate?.stickerDidTap(self)
        self.startTimer()
    }
    
    @objc func pinchAction(_ ges: UIPinchGestureRecognizer) {
        guard self.gesIsEnabled else { return }
        
        self.gesScale *= ges.scale
        ges.scale = 1
        
        if ges.state == .began {
            self.setOperation(true)
        } else if ges.state == .changed {
            self.updateTransform()
        } else if (ges.state == .ended || ges.state == .cancelled){
            self.setOperation(false)
        }
    }
    
    private var initialBounds = CGRect.zero
    private var initialDistance: CGFloat = 0
    private var deltaAngle: CGFloat = 0

    @objc func rotationAction(_ recognizer: UIPanGestureRecognizer) {
        guard self.gesIsEnabled else { return }
        
        let touchLocation = recognizer.location(in: superview)
        let center = self.center
        
        switch recognizer.state {
        case .began:
            deltaAngle = CGFloat(atan2f(Float(touchLocation.y - center.y), Float(touchLocation.x - center.x))) - CGAffineTransformGetAngle(transform)
            initialBounds = bounds
            initialDistance = CGPointGetDistance(point1: center, point2: touchLocation)
            
            setOperation(true)
        case .changed:
            let angle = atan2f(Float(touchLocation.y - center.y), Float(touchLocation.x - center.x))
            let angleDiff = CGFloat(angle) - deltaAngle
            gesRotation = angleDiff
            
            var scale = CGPointGetDistance(point1: center, point2: touchLocation) / initialDistance
            let minimumScale = CGFloat(40) / min(initialBounds.size.width, initialBounds.size.height)
            scale = max(scale, minimumScale)
            gesScale = scale
            
            updateTransform()
        case .ended:
            setOperation(false)
        default:
            break
        }
    }
    
    @objc func panAction(_ ges: UIPanGestureRecognizer) {
        guard self.gesIsEnabled else { return }
        
        let point = ges.translation(in: self.superview)
        self.gesTranslationPoint = CGPoint(x: point.x / self.originScale, y: point.y / self.originScale)
        
        if ges.state == .began {
            self.setOperation(true)
        } else if ges.state == .changed {
            self.updateTransform()
        } else if (ges.state == .ended || ges.state == .cancelled) {
            self.totalTranslationPoint.x += point.x
            self.totalTranslationPoint.y += point.y
            self.setOperation(false)
            if self.originAngle == 90 {
                self.originTransform = self.originTransform.translatedBy(x: self.gesTranslationPoint.y, y: -self.gesTranslationPoint.x)
            } else if self.originAngle == 180 {
                self.originTransform = self.originTransform.translatedBy(x: -self.gesTranslationPoint.x, y: -self.gesTranslationPoint.y)
            } else if self.originAngle == 270 {
                self.originTransform = self.originTransform.translatedBy(x: -self.gesTranslationPoint.y, y: self.gesTranslationPoint.x)
            } else {
                self.originTransform = self.originTransform.translatedBy(x: self.gesTranslationPoint.x, y: self.gesTranslationPoint.y)
            }
            self.gesTranslationPoint = .zero
        }
    }
    
    func setOperation(_ isOn: Bool) {
        if isOn, !self.onOperation {
            self.onOperation = true
            self.cleanTimer()
            borderView.alpha = 1
            removeButton.alpha = 1
            transformToolView.alpha = 1
            self.superview?.bringSubviewToFront(self)
//            self.delegate?.stickerBeginOperation(self)
        } else if !isOn, self.onOperation {
            self.onOperation = false
            self.startTimer()
            self.delegate?.stickerEndOperation(self, panGes: self.panGes)
        }
    }
    
    func updateTransform() {
        var transform = self.originTransform
        
        if self.originAngle == 90 {
            transform = transform.translatedBy(x: self.gesTranslationPoint.y, y: -self.gesTranslationPoint.x)
        } else if self.originAngle == 180 {
            transform = transform.translatedBy(x: -self.gesTranslationPoint.x, y: -self.gesTranslationPoint.y)
        } else if self.originAngle == 270 {
            transform = transform.translatedBy(x: -self.gesTranslationPoint.y, y: self.gesTranslationPoint.x)
        } else {
            transform = transform.translatedBy(x: self.gesTranslationPoint.x, y: self.gesTranslationPoint.y)
        }
        // Scale must after translate.
        transform = transform.scaledBy(x: self.gesScale, y: self.gesScale)
        // Rotate must after scale.
        transform = transform.rotated(by: self.gesRotation)
        self.transform = transform
        
//        self.delegate?.stickerOnOperation(self, panGes: self.panGes)
    }
    
    @objc func hideBorder() {
        self.cleanTimer()
        
        borderView.alpha = 0
        removeButton.alpha = 0
        transformToolView.alpha = 0
    }
    
    func startTimer() {
        self.cleanTimer()
        
        borderView.alpha = 1
        removeButton.alpha = 1
        transformToolView.alpha = 1
        
        self.timer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(hideBorder), userInfo: nil, repeats: false)
        RunLoop.current.add(self.timer!, forMode: .default)
    }
    
    func cleanTimer() {
        self.timer?.invalidate()
        self.timer = nil
    }
    
    func resetState() {
        self.onOperation = false
        self.cleanTimer()
        self.hideBorder()
    }
    
    func moveToAshbin() {
        self.cleanTimer()
        self.removeFromSuperview()
    }
    
    func addScale(_ scale: CGFloat) {
        // Revert zoom scale.
        self.transform = self.transform.scaledBy(x: 1/self.originScale, y: 1/self.originScale)
        // Revert ges scale.
        self.transform = self.transform.scaledBy(x: 1/self.gesScale, y: 1/self.gesScale)
        // Revert ges rotation.
        self.transform = self.transform.rotated(by: -self.gesRotation)
        
        var origin = self.frame.origin
        origin.x *= scale
        origin.y *= scale
        
        let newSize = CGSize(width: self.frame.width * scale, height: self.frame.height * scale)
        let newOrigin = CGPoint(x: self.frame.minX + (self.frame.width - newSize.width)/2, y: self.frame.minY + (self.frame.height - newSize.height)/2)
        let diffX: CGFloat = (origin.x - newOrigin.x)
        let diffY: CGFloat = (origin.y - newOrigin.y)
        
        if self.originAngle == 90 {
            self.transform = self.transform.translatedBy(x: diffY, y: -diffX)
            self.originTransform = self.originTransform.translatedBy(x: diffY / self.originScale, y: -diffX / self.originScale)
        } else if self.originAngle == 180 {
            self.transform = self.transform.translatedBy(x: -diffX, y: -diffY)
            self.originTransform = self.originTransform.translatedBy(x: -diffX / self.originScale, y: -diffY / self.originScale)
        } else if self.originAngle == 270 {
            self.transform = self.transform.translatedBy(x: -diffY, y: diffX)
            self.originTransform = self.originTransform.translatedBy(x: -diffY / self.originScale, y: diffX / self.originScale)
        } else {
            self.transform = self.transform.translatedBy(x: diffX, y: diffY)
            self.originTransform = self.originTransform.translatedBy(x: diffX / self.originScale, y: diffY / self.originScale)
        }
        self.totalTranslationPoint.x += diffX
        self.totalTranslationPoint.y += diffY
        
        self.transform = self.transform.scaledBy(x: scale, y: scale)
        
        // Readd zoom scale.
        self.transform = self.transform.scaledBy(x: self.originScale, y: self.originScale)
        // Readd ges scale.
        self.transform = self.transform.scaledBy(x: self.gesScale, y: self.gesScale)
        // Readd ges rotation.
        self.transform = self.transform.rotated(by: self.gesRotation)
        
        self.gesScale *= scale
    }
    
    class func calculateSize(image: UIImage, width: CGFloat) -> CGSize {
        let maxSide = width / 4
        let minSide: CGFloat = 80
        let whRatio = image.size.width / image.size.height
        var size: CGSize = .zero
        if whRatio >= 1 {
            let w = min(maxSide, max(minSide, image.size.width))
            let h = w / whRatio
            size = CGSize(width: w, height: h)
        } else {
            let h = min(maxSide, max(minSide, image.size.width))
            let w = h * whRatio
            size = CGSize(width: w, height: h)
        }
        size.width += ZLImageStickerView.edgeInset * 2
        size.height += ZLImageStickerView.edgeInset * 2
        return size
    }
    
}

public class ZLImageStickerState: NSObject {
    
    let image: UIImage
    let originScale: CGFloat
    let originAngle: CGFloat
    let originFrame: CGRect
    let gesScale: CGFloat
    let gesRotation: CGFloat
    let totalTranslationPoint: CGPoint
    
    init(image: UIImage, originScale: CGFloat, originAngle: CGFloat, originFrame: CGRect, gesScale: CGFloat, gesRotation: CGFloat, totalTranslationPoint: CGPoint) {
        self.image = image
        self.originScale = originScale
        self.originAngle = originAngle
        self.originFrame = originFrame
        self.gesScale = gesScale
        self.gesRotation = gesRotation
        self.totalTranslationPoint = totalTranslationPoint
        super.init()
    }
    
}

@inline(__always) func CGAffineTransformGetAngle(_ t:CGAffineTransform) -> CGFloat {
    return atan2(t.b, t.a)
}

@inline(__always) func CGPointGetDistance(point1:CGPoint, point2:CGPoint) -> CGFloat {
    let fx = point2.x - point1.x
    let fy = point2.y - point1.y
    return sqrt(fx * fx + fy * fy)
}
