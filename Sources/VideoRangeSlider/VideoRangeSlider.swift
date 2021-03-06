//
//  VideoRangeSlider.swift
//
//
//  Created by Luca Infante on 09/02/21.
//

import UIKit
import AVKit

extension String {
    func height(constraintedWidth width: CGFloat, font: UIFont) -> CGFloat {
        let label =  UILabel(frame: CGRect(x: 0, y: 0, width: width, height: .greatestFiniteMagnitude))
        label.numberOfLines = 0
        label.text = self
        label.font = font
        label.sizeToFit()
        
        return label.frame.height
    }
}

@objc public protocol VideoRangeSliderDelegate: class {
    func didChangeValue(videoRangeSlider: VideoRangeSlider, startTime: Float64, endTime: Float64)
    func indicatorDidChangePosition(videoRangeSlider: VideoRangeSlider, position: Float64)
    
    @objc optional func sliderGesturesBegan()
    @objc optional func sliderGesturesEnded()
}

public class VideoRangeSlider: UIView, UIGestureRecognizerDelegate {

    private enum DragHandleChoice {
        case start
        case end
    }
    
    public weak var delegate: VideoRangeSliderDelegate? = nil

    var startIndicator      = ABStartIndicator()
    var endIndicator        = ABEndIndicator()
    var topLine             = ABBorder()
    var bottomLine          = ABBorder()
    var progressIndicator   = ABProgressIndicator()
    var draggableView       = UIView()

    // For SwiftUI
    var viewForSwiftUI      = UIView()
    var flagSwiftUI         = false

    public var startTimeView       = ABTimeView()
    public var endTimeView         = ABTimeView()

    let thumbnailsManager   = ABThumbnailsManager()
    var duration: Float64   = 0.0
    var videoURL            = URL(fileURLWithPath: "")

    var progressPercentage: CGFloat = 0         // Represented in percentage
    var startPercentage: CGFloat    = 0         // Represented in percentage
    var endPercentage: CGFloat      = 100       // Represented in percentage

    let topBorderHeight: CGFloat      = 5
    let bottomBorderHeight: CGFloat   = 5

    let indicatorWidth: CGFloat = 20.0

    public var minSpace: Float = 1              // In Seconds
    public var maxSpace: Float = 0              // In Seconds
    
    public var isProgressIndicatorSticky: Bool = false
    public var isProgressIndicatorDraggable: Bool = true
    
    var isUpdatingThumbnails = false
    var isReceivingGesture: Bool = false
    
    public enum ABTimeViewPosition{
        case top
        case bottom
    }

    override public func awakeFromNib() {
        super.awakeFromNib()
        self.setup()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    private func setup() {
        self.isUserInteractionEnabled = true
        
        // Setup Start Indicator
        let startDrag = UIPanGestureRecognizer(target:self,
                                               action: #selector(startDragged(recognizer:)))

        startIndicator = ABStartIndicator(frame: CGRect(x: 0,
                                                        y: -topBorderHeight,
                                                        width: 20,
                                                        height: self.frame.size.height + bottomBorderHeight + topBorderHeight))
        startIndicator.layer.anchorPoint = CGPoint(x: 1, y: 0.5)
        startIndicator.addGestureRecognizer(startDrag)
        self.addSubview(startIndicator)

        // Setup End Indicator

        let endDrag = UIPanGestureRecognizer(target:self,
                                             action: #selector(endDragged(recognizer:)))

        endIndicator = ABEndIndicator(frame: CGRect(x: 0,
                                                    y: -topBorderHeight,
                                                    width: indicatorWidth,
                                                    height: self.frame.size.height + bottomBorderHeight + topBorderHeight))
        endIndicator.layer.anchorPoint = CGPoint(x: 0, y: 0.5)
        endIndicator.addGestureRecognizer(endDrag)
        self.addSubview(endIndicator)


        // Setup Top and bottom line

        topLine = ABBorder(frame: CGRect(x: 0,
                                         y: -topBorderHeight,
                                         width: indicatorWidth,
                                         height: topBorderHeight))
        self.addSubview(topLine)

        bottomLine = ABBorder(frame: CGRect(x: 0,
                                            y: self.frame.size.height,
                                            width: indicatorWidth,
                                            height: bottomBorderHeight))
        self.addSubview(bottomLine)

        self.addObserver(self,
                         forKeyPath: "bounds",
                         options: NSKeyValueObservingOptions(rawValue: 0),
                         context: nil)

        // Setup Progress Indicator

        let progressDrag = UIPanGestureRecognizer(target: self,
                                                  action: #selector(progressDragged(recognizer:)))

        progressIndicator = ABProgressIndicator(frame: CGRect(x: 0,
                                                              y: -topBorderHeight,
                                                              width: 10,
                                                              height: self.frame.size.height + bottomBorderHeight + topBorderHeight))
        progressIndicator.addGestureRecognizer(progressDrag)
        self.addSubview(progressIndicator)

        // Setup Draggable View

        let viewDrag = UIPanGestureRecognizer(target: self,
                                              action: #selector(viewDragged(recognizer:)))

        draggableView.addGestureRecognizer(viewDrag)
        self.draggableView.backgroundColor = .clear
        self.addSubview(draggableView)
        self.sendSubviewToBack(draggableView)

        // Setup time labels
                
        startTimeView = ABTimeView(size: CGSize(width: 60, height: 30), position: -38)
        startTimeView.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        self.addSubview(startTimeView)

        endTimeView = ABTimeView(size: CGSize(width: 60, height: 30), position: -38)
        endTimeView.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        self.addSubview(endTimeView)
    }

    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "bounds"{
            self.updateThumbnails()
        }
    }

    // MARK: Public functions
    public func getImageFromFrame(position: Float) -> UIImage
    {
        // Return image from selected frame
        let image = ABVideoHelper.thumbnailFromVideo(videoUrl: self.videoURL, time: CMTimeMake(value: Int64(position), timescale: 1))
        return image
    }
    
    public func setProgressIndicatorImage(image: UIImage) {
        self.progressIndicator.imageView.image = image
    }

    public func hideProgressIndicator() {
        self.progressIndicator.isHidden = true
    }

    public func showProgressIndicator() {
        self.progressIndicator.isHidden = false
    }

    public func updateProgressIndicator(seconds: Float64) {
        if !isReceivingGesture {
            let endSeconds = secondsFromValue(value: self.endPercentage)
            
            if seconds >= endSeconds {
                self.resetProgressPosition()
            } else {
                self.progressPercentage = self.valueFromSeconds(seconds: Float(seconds))
            }

            layoutSubviews()
        }
    }

    public func setStartIndicatorImage(image: UIImage){
        self.startIndicator.imageView.image = image
    }

    public func setEndIndicatorImage(image: UIImage){
        self.endIndicator.imageView.image = image
    }

    public func setBorderImage(image: UIImage){
        self.topLine.imageView.image = image
        self.bottomLine.imageView.image = image
    }

    public func setTimeView(view: ABTimeView){
        self.startTimeView = view
        self.endTimeView = view
    }

    public func setTimeViewPosition(position: ABTimeViewPosition){
        switch position {
        case .top:
            self.startTimeView.frame.origin = CGPoint(x: self.startTimeView.frame.origin.x, y: -self.startTimeView.frame.size.height - 8)
            self.endTimeView.frame.origin = CGPoint(x: self.endTimeView.frame.origin.x, y: -self.endTimeView.frame.size.height - 8)
        case .bottom:
            self.startTimeView.frame.origin = CGPoint(x: self.startTimeView.frame.origin.x, y: self.startTimeView.frame.size.height + 12 + self.startTimeView.timeLabel.text!.height(constraintedWidth: self.startTimeView.timeLabel.frame.size.width, font: self.startTimeView.timeLabel.font))
            self.endTimeView.frame.origin = CGPoint(x: self.endTimeView.frame.origin.x, y: self.endTimeView.frame.size.height + 12 + self.endTimeView.timeLabel.text!.height(constraintedWidth: self.endTimeView.timeLabel.frame.size.width, font: self.endTimeView.timeLabel.font))
        }
    }

    public func setVideoURL(videoURL: URL) {
        self.duration = ABVideoHelper.videoDuration(videoURL: videoURL)
        self.videoURL = videoURL
        self.superview?.layoutSubviews()
        self.updateThumbnails()
    }

    public func updateThumbnails() {
        if !isUpdatingThumbnails {
            self.isUpdatingThumbnails = true
            let backgroundQueue = DispatchQueue(label: "com.app.queue", qos: .background, target: nil)
            backgroundQueue.async {
                _ = self.thumbnailsManager.updateThumbnails(view: (self.flagSwiftUI ? self.viewForSwiftUI : self), videoURL: self.videoURL, duration: self.duration)
                self.isUpdatingThumbnails = false
            }
        }
    }

    public func setStartPosition(seconds: Float){
        self.startPercentage = self.valueFromSeconds(seconds: seconds)
        layoutSubviews()
    }

    public func setEndPosition(seconds: Float){
        self.endPercentage = self.valueFromSeconds(seconds: seconds)
        layoutSubviews()
    }
    
    // MARK: - Internal functions
    internal func reSetupIndicator(width: CGFloat, height: CGFloat, heightProgressIndicator: CGFloat, startY: CGFloat)
    {
        // Set flag SwiftUI to true
        self.viewForSwiftUI = UIView(frame: CGRect(x: 20, y: 0, width: width - 40, height: height))
        self.addSubview(self.viewForSwiftUI)
        self.flagSwiftUI = true
        
        // Re-Setup frame of start, progress and end indicator for correct use with SwiftUI
        self.startIndicator.removeFromSuperview()
        let startDrag = UIPanGestureRecognizer(target:self,
                                               action: #selector(startDragged(recognizer:)))

        self.startIndicator = ABStartIndicator(frame: CGRect(x: 0,
                                                        y: startY - topBorderHeight,
                                                        width: 20,
                                                        height: height + topBorderHeight + bottomBorderHeight))
        self.startIndicator.layer.anchorPoint = CGPoint(x: 0, y: 0.5)
        self.startIndicator.addGestureRecognizer(startDrag)
        self.addSubview(self.startIndicator)

        self.endIndicator.removeFromSuperview()
        let endDrag = UIPanGestureRecognizer(target:self,
                                             action: #selector(endDragged(recognizer:)))

        self.endIndicator = ABEndIndicator(frame: CGRect(x: 0,
                                                    y: startY - topBorderHeight,
                                                    width: indicatorWidth,
                                                    height: height + topBorderHeight + bottomBorderHeight))
        self.endIndicator.layer.anchorPoint = CGPoint(x: 1, y: 0.5)
        self.endIndicator.addGestureRecognizer(endDrag)
        self.addSubview(self.endIndicator)
        
        self.progressIndicator.removeFromSuperview()
        let progressDrag = UIPanGestureRecognizer(target:self,
                                                  action: #selector(progressDragged(recognizer:)))

        self.progressIndicator = ABProgressIndicator(frame: CGRect(x: 0,
                                                              y: startY - topBorderHeight - (heightProgressIndicator - height)/2,
                                                              width: 10,
                                                              height: heightProgressIndicator + topBorderHeight + bottomBorderHeight))
        self.progressIndicator.addGestureRecognizer(progressDrag)
        self.addSubview(self.progressIndicator)

        // Setup Draggable View

        let viewDrag = UIPanGestureRecognizer(target: self,
                                              action: #selector(viewDragged(recognizer:)))

        draggableView.addGestureRecognizer(viewDrag)
        self.draggableView.backgroundColor = .clear
        self.viewForSwiftUI.addSubview(draggableView)
        self.viewForSwiftUI.sendSubviewToBack(draggableView)

        // Setup time labels
        startTimeView.removeFromSuperview()
        startTimeView = ABTimeView(size: CGSize(width: 60, height: 30), position: -38)
        startTimeView.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        self.viewForSwiftUI.addSubview(startTimeView)

        endTimeView.removeFromSuperview()
        endTimeView = ABTimeView(size: CGSize(width: 60, height: 30), position: -38)
        endTimeView.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        self.viewForSwiftUI.addSubview(endTimeView)

    }
    
    // MARK: - Private functions

    // MARK: - Crop Handle Drag Functions
    @objc private func startDragged(recognizer: UIPanGestureRecognizer){
        self.processHandleDrag(
            recognizer: recognizer,
            drag: .start,
            currentPositionPercentage: self.startPercentage,
            currentIndicator: self.startIndicator
        )
    }
    
    @objc private func endDragged(recognizer: UIPanGestureRecognizer){
        self.processHandleDrag(
            recognizer: recognizer,
            drag: .end,
            currentPositionPercentage: self.endPercentage,
            currentIndicator: self.endIndicator
        )
    }

    private func processHandleDrag(
        recognizer: UIPanGestureRecognizer,
        drag: DragHandleChoice,
        currentPositionPercentage: CGFloat,
        currentIndicator: UIView
        ) {
        
        self.updateGestureStatus(recognizer: recognizer)
        
        let translation = recognizer.translation(in: self)
        
        var position: CGFloat = positionFromValue(value: currentPositionPercentage) // self.startPercentage or self.endPercentage
        
        position = position + translation.x
        
        if position < 0 { position = 0 }
        
        if position > self.frame.size.width {
            position = self.frame.size.width
        }

        let positionLimits = getPositionLimits(with: drag)
        position = checkEdgeCasesForPosition(with: position, and: positionLimits.min, and: drag)

        if Float(self.duration) > self.maxSpace && self.maxSpace > 0 {
            if drag == .start {
                if position < positionLimits.max {
                    position = positionLimits.max
                }
            } else {
                if position > positionLimits.max {
                    position = positionLimits.max
                }
            }
        }
        
        recognizer.setTranslation(CGPoint.zero, in: self)
        
        currentIndicator.center = CGPoint(x: position , y: currentIndicator.center.y)
        
        let percentage = currentIndicator.center.x * 100 / self.frame.width
        
        let startSeconds = secondsFromValue(value: self.startPercentage)
        let endSeconds = secondsFromValue(value: self.endPercentage)
        
        self.delegate?.didChangeValue(videoRangeSlider: self, startTime: startSeconds, endTime: endSeconds)
        
        var progressPosition: CGFloat = 0.0 + (self.flagSwiftUI ? self.startIndicator.imageView.frame.size.width : 0)
        
        if drag == .start {
            self.startPercentage = percentage
        } else {
            self.endPercentage = percentage
        }
                
        // Set corret position for progress
        if positionFromValue(value: self.progressPercentage) < positionFromValue(value: self.startPercentage) + (self.flagSwiftUI ? self.startIndicator.imageView.frame.size.width : 0)
        {
            progressPosition = positionFromValue(value: self.startPercentage) + (self.flagSwiftUI ? self.startIndicator.imageView.frame.size.width : 0)
        }
        else if positionFromValue(value: self.progressPercentage) > positionFromValue(value: self.endPercentage) - (self.flagSwiftUI ? (self.endIndicator.imageView.frame.size.width) : 0)
        {
            progressPosition = positionFromValue(value: self.endPercentage) - (self.flagSwiftUI ? (self.endIndicator.imageView.frame.size.width) : 0)
        }
        else
        {
            progressPosition = positionFromValue(value: self.progressPercentage)
        }
        
/*        if drag == .start {
            progressPosition = positionFromValue(value: self.startPercentage)
        } else {
            if recognizer.state != .ended {
                progressPosition = positionFromValue(value: self.endPercentage)
            } else {
                progressPosition = positionFromValue(value: self.startPercentage)
            }
        }*/
                
        progressIndicator.center = CGPoint(x: progressPosition , y: progressIndicator.center.y)
        let progressPercentage = progressIndicator.center.x * 100 / self.frame.width

        if self.progressPercentage != progressPercentage {
            let progressSeconds = secondsFromValue(value: progressPercentage)
            self.delegate?.indicatorDidChangePosition(videoRangeSlider: self, position: progressSeconds)
        }
        
        self.progressPercentage = progressPercentage
                
        layoutSubviews()
    }
    
    @objc func progressDragged(recognizer: UIPanGestureRecognizer){
        if !isProgressIndicatorDraggable {
            return
        }
        
        updateGestureStatus(recognizer: recognizer)
        
        let translation = recognizer.translation(in: self)

        let positionLimitStart  = positionFromValue(value: self.startPercentage) + (self.flagSwiftUI ? self.startIndicator.imageView.frame.size.width : 0)
        let positionLimitEnd    = positionFromValue(value: self.endPercentage) - (self.flagSwiftUI ? (self.endIndicator.imageView.frame.size.width) : 0)

        var position = positionFromValue(value: self.progressPercentage)
        position = position + translation.x
        
        if position < positionLimitStart {
            position = positionLimitStart
        }

        if position > positionLimitEnd {
            position = positionLimitEnd
        }

        recognizer.setTranslation(CGPoint.zero, in: self)

        progressIndicator.center = CGPoint(x: position , y: progressIndicator.center.y)

        let percentage = progressIndicator.center.x * 100 / self.frame.width

        let progressSeconds = secondsFromValue(value: progressPercentage)

        self.delegate?.indicatorDidChangePosition(videoRangeSlider: self, position: progressSeconds)

        self.progressPercentage = percentage

        layoutSubviews()
    }

    @objc func viewDragged(recognizer: UIPanGestureRecognizer){
        updateGestureStatus(recognizer: recognizer)
        
        let translation = recognizer.translation(in: self)

        var progressPosition = positionFromValue(value: self.progressPercentage)
        var startPosition = positionFromValue(value: self.startPercentage)
        var endPosition = positionFromValue(value: self.endPercentage)

        startPosition = startPosition + translation.x
        endPosition = endPosition + translation.x
        progressPosition = progressPosition + translation.x

        if startPosition < 0 {
            startPosition = 0
            endPosition = endPosition - translation.x
            progressPosition = progressPosition - translation.x
        }

        if endPosition > self.frame.size.width {
            endPosition = self.frame.size.width
            startPosition = startPosition - translation.x
            progressPosition = progressPosition - translation.x
        }

        recognizer.setTranslation(CGPoint.zero, in: self)

        progressIndicator.center = CGPoint(x: progressPosition , y: progressIndicator.center.y)
        startIndicator.center = CGPoint(x: startPosition , y: startIndicator.center.y)
        endIndicator.center = CGPoint(x: endPosition , y: endIndicator.center.y)

        let startPercentage = startIndicator.center.x * 100 / self.frame.width
        let endPercentage = endIndicator.center.x * 100 / self.frame.width
        let progressPercentage = progressIndicator.center.x * 100 / self.frame.width

        let startSeconds = secondsFromValue(value: startPercentage)
        let endSeconds = secondsFromValue(value: endPercentage)

        self.delegate?.didChangeValue(videoRangeSlider: self, startTime: startSeconds, endTime: endSeconds)

        if self.progressPercentage != progressPercentage{
            let progressSeconds = secondsFromValue(value: progressPercentage)
            self.delegate?.indicatorDidChangePosition(videoRangeSlider: self, position: progressSeconds)
        }

        self.startPercentage = startPercentage
        self.endPercentage = endPercentage
        self.progressPercentage = progressPercentage

        layoutSubviews()
    }
    
    // MARK: - Drag Functions Helpers
    private func positionFromValue(value: CGFloat) -> CGFloat{
        let position = value * self.frame.size.width / 100
        return position
    }
    
    private func getPositionLimits(with drag: DragHandleChoice) -> (min: CGFloat, max: CGFloat) {
        if drag == .start {
            return (
                positionFromValue(value: self.endPercentage - valueFromSeconds(seconds: self.minSpace)),
                positionFromValue(value: self.endPercentage - valueFromSeconds(seconds: self.maxSpace))
            )
        } else {
            return (
                positionFromValue(value: self.startPercentage + valueFromSeconds(seconds: self.minSpace)),
                positionFromValue(value: self.startPercentage + valueFromSeconds(seconds: self.maxSpace))
            )
        }
    }
    
    private func checkEdgeCasesForPosition(with position: CGFloat, and positionLimit: CGFloat, and drag: DragHandleChoice) -> CGFloat {
        if drag == .start {
            if Float(self.duration) < self.minSpace {
                return 0
            } else {
                if position > positionLimit {
                    return positionLimit
                }
            }
        } else {
            if Float(self.duration) < self.minSpace {
                return self.frame.size.width
            } else {
                if position < positionLimit {
                    return positionLimit
                }
            }
        }
        
        return position
    }
    
    private func secondsFromValue(value: CGFloat) -> Float64 {
        // Fix for SwiftUI
        if value < 6
        {
            return duration * Float64((0 / 100))
        }
        else if value > 94
        {
            return duration * Float64((100 / 100))
        }
        else
        {
            return duration * Float64((value / 100))
        }
    }

    private func valueFromSeconds(seconds: Float) -> CGFloat {
        return CGFloat(seconds * 100) / CGFloat(duration)
    }
    
    private func updateGestureStatus(recognizer: UIGestureRecognizer) {
        if recognizer.state == .began {
            
            self.isReceivingGesture = true
            self.delegate?.sliderGesturesBegan?()
            
        } else if recognizer.state == .ended {
            
            self.isReceivingGesture = false
            self.delegate?.sliderGesturesEnded?()
        }
    }
    
    private func resetProgressPosition() {
        self.progressPercentage = self.startPercentage
        let progressPosition = positionFromValue(value: self.progressPercentage)
        progressIndicator.center = CGPoint(x: progressPosition , y: progressIndicator.center.y)
        
        let startSeconds = secondsFromValue(value: self.progressPercentage)
        self.delegate?.indicatorDidChangePosition(videoRangeSlider: self, position: startSeconds)
    }

    // MARK: -

    override public func layoutSubviews() {
        super.layoutSubviews()

        startTimeView.timeLabel.text = "\(self.secondsToFormattedString(totalSeconds: secondsFromValue(value: self.startPercentage)))s"
        endTimeView.timeLabel.text = "\(self.secondsToFormattedString(totalSeconds: secondsFromValue(value: self.endPercentage)))s"

        let startPosition = positionFromValue(value: self.startPercentage)
        let endPosition = positionFromValue(value: self.endPercentage)
                
        let progressPosition = positionFromValue(value: self.progressPercentage)

        startIndicator.center = CGPoint(x: startPosition, y: startIndicator.center.y)
        endIndicator.center = CGPoint(x: endPosition, y: endIndicator.center.y)
        progressIndicator.center = CGPoint(x: progressPosition, y: progressIndicator.center.y)

        draggableView.frame = CGRect(x: startIndicator.frame.origin.x + startIndicator.frame.size.width,
                                     y: 0,
                                     width: endIndicator.frame.origin.x - startIndicator.frame.origin.x - endIndicator.frame.size.width,
                                     height: self.frame.height)

        topLine.frame = CGRect(x: startIndicator.frame.origin.x + startIndicator.frame.width,
                               y: -topBorderHeight,
                               width: endIndicator.frame.origin.x - startIndicator.frame.origin.x - endIndicator.frame.size.width,
                               height: topBorderHeight)

        bottomLine.frame = CGRect(x: startIndicator.frame.origin.x + startIndicator.frame.width,
                                  y: self.frame.size.height,
                                  width: endIndicator.frame.origin.x - startIndicator.frame.origin.x - endIndicator.frame.size.width,
                                  height: bottomBorderHeight)

        // Update time view
        startTimeView.center = CGPoint(x: startIndicator.center.x, y: startTimeView.center.y)
        endTimeView.center = CGPoint(x: endIndicator.frame.origin.x - endIndicator.frame.size.width, y: endTimeView.center.y)
    }

    override public func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let extendedBounds = CGRect(x: -startIndicator.frame.size.width,
                                    y: -topLine.frame.size.height,
                                    width: self.frame.size.width + startIndicator.frame.size.width + endIndicator.frame.size.width,
                                    height: self.frame.size.height + topLine.frame.size.height + bottomLine.frame.size.height)
        return extendedBounds.contains(point)
    }

    private func secondsToFormattedString(totalSeconds: Float64) -> String{
        let hours:Int = Int(totalSeconds.truncatingRemainder(dividingBy: 86400) / 3600)
        let minutes:Int = Int(totalSeconds.truncatingRemainder(dividingBy: 3600) / 60)
        let seconds:Int = Int(totalSeconds.truncatingRemainder(dividingBy: 60))

        if hours > 0 {
            return String(format: "%i:%02i:%02i", hours, minutes, seconds)
        } else {
            return String(format: "%02i:%02i", minutes, seconds)
        }
    }

    deinit {
      // removeObserver(self, forKeyPath: "bounds")
    }
}
