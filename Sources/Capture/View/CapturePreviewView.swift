//
//  CapturePreviewView.swift
//  AnyImageKit
//
//  Created by 刘栋 on 2019/7/22.
//  Copyright © 2019 AnyImageProject.org. All rights reserved.
//

import UIKit
import CoreMedia

protocol CapturePreviewViewDelegate: class {
    
    func previewView(_ previewView: CapturePreviewView, didFocusAt point: CGPoint)
}

final class CapturePreviewView: UIView {
    
    private lazy var previewContentView: CapturePreviewContentView = {
        let view = CapturePreviewContentView(frame: .zero)
        return view
    }()
    
    private lazy var previewMaskView: CapturePreviewMaskView = {
        let view = CapturePreviewMaskView(frame: .zero, options: options)
        return view
    }()
    
    private lazy var blurView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .dark)
        let view = UIVisualEffectView(effect: effect)
        view.alpha = 0
        return view
    }()
    
    private lazy var focusView: CaptureFocusView = {
        let view = CaptureFocusView(frame: .zero, color: options.tintColor)
        return view
    }()
    
    private let options: CaptureParsedOptionsInfo
    
    weak var delegate: CapturePreviewViewDelegate?
    
    init(frame: CGRect, options: CaptureParsedOptionsInfo) {
        self.options = options
        super.init(frame: frame)
        setupView()
        setupGestrue()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        addSubview(previewContentView)
        previewContentView.addSubview(blurView)
        addSubview(previewMaskView)
        addSubview(focusView)
        previewContentView.snp.makeConstraints { maker in
            maker.edges.equalToSuperview()
        }
        blurView.snp.makeConstraints { maker in
            maker.edges.equalToSuperview()
        }
        previewMaskView.snp.makeConstraints { maker in
            maker.edges.equalToSuperview()
        }
        focusView.snp.makeConstraints { (maker) in
            maker.edges.equalToSuperview()
        }
    }
    
    private func setupGestrue() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(onTapped(_:)))
        addGestureRecognizer(tap)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        addGestureRecognizer(pan)
    }
}

// MARK: - Action
extension CapturePreviewView {
    
    @objc private func onTapped(_ sender: UITapGestureRecognizer) {
        let touchPoint = sender.location(in: self)
        guard touchPoint.x > 0, touchPoint.x < frame.width else { return }
        guard touchPoint.y > 0, touchPoint.y < frame.height else { return }
        let point = CGPoint(x: touchPoint.x/frame.width, y: touchPoint.y/frame.height)
        focusView.focusing(at: point)
        delegate?.previewView(self, didFocusAt: point)
    }
    
    @objc private func onPan(_ sender: UIPanGestureRecognizer) {
        guard focusView.isFocusing else { return }
        let point = sender.translation(in: self)
        sender.setTranslation(.zero, in: self)
        let value = point.y / bounds.height
        focusView.setLight(focusView.exposureValue + value)
    }
}

// MARK: - Preview Buffer
extension CapturePreviewView {
    
    func clear() {
        let size = previewContentView.drawableSize
        let image = CIImage.image(size: size, backgroundColor: .black) ?? .empty()
        previewContentView.draw(image: image)
    }
    
    func draw(_ sampleBuffer: CMSampleBuffer) {
        if let imageBuffer = sampleBuffer.imageBuffer {
            let image = CIImage(cvImageBuffer: imageBuffer)
            previewContentView.draw(image: image)
        }
    }
}

// MARK: - Animation
extension CapturePreviewView {
    
    func hideToolMask(animated: Bool) {
        let duration = animated ? 0.25 : 0
        let timingParameters = UICubicTimingParameters(animationCurve: .easeInOut)
        let animator = UIViewPropertyAnimator(duration: duration, timingParameters: timingParameters)
        animator.addAnimations {
            self.previewMaskView.topMaskView.alpha = 0
            self.previewMaskView.bottomMaskView.alpha = 0
        }
        animator.startAnimation()
    }
    
    func showToolMask(animated: Bool) {
        let duration = animated ? 0.25 : 0
        let timingParameters = UICubicTimingParameters(animationCurve: .easeInOut)
        let animator = UIViewPropertyAnimator(duration: duration, timingParameters: timingParameters)
        animator.addAnimations {
            self.previewMaskView.topMaskView.alpha = 1.0
            self.previewMaskView.bottomMaskView.alpha = 1.0
        }
        animator.startAnimation()
    }
    
    func transitionFlip(isIn: Bool, stopPreview: @escaping () -> Void, startPreview: @escaping () -> Void, completion: @escaping () -> Void) {
        let transform = previewContentView.transform
        UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseInOut, animations: {
            self.previewContentView.transform = transform.scaledBy(x: 0.85, y: 0.85)
        }) { _ in
            self.blurView.alpha = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now()+0.05) {
            let options: UIView.AnimationOptions = isIn ? .transitionFlipFromLeft : .transitionFlipFromRight
            UIView.transition(with: self.previewContentView, duration: 0.25, options: options, animations: nil, completion: nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now()+0.2) {
            UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseInOut, animations: {
                self.previewContentView.transform = transform
            }) { _ in
                DispatchQueue.global().async {
                    stopPreview()
                }
                DispatchQueue.main.asyncAfter(deadline: .now()+0.3) {
                    UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseInOut, animations: {
                        self.previewContentView.alpha = 0
                    }) { _ in
                        self.clear()
                        self.blurView.alpha = 0
                        startPreview()
                        UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseInOut, animations: {
                            self.previewContentView.alpha = 1
                        }) { _ in
                            completion()
                        }
                    }
                }
            }
        }
    }
    
    func rotate(to orientation: DeviceOrientation, animated: Bool) {
        // TODO:
//        let duration = animated ? 0.25 : 0
//        let timingParameters = UICubicTimingParameters(animationCurve: .easeInOut)
//        let animator = UIViewPropertyAnimator(duration: duration, timingParameters: timingParameters)
//        animator.addAnimations {
//            self.focusView.transform = orientation.transformMirrored
//        }
//        animator.startAnimation()
    }
}
