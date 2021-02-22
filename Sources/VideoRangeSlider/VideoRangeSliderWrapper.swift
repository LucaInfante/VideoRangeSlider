//
//  File.swift
//
//
//  Created by Luca Infante on 09/02/21.
//

import UIKit
import SwiftUI
import AVKit

#if arch(arm64)
@available(iOS 13.0, *)
public struct VideoRangeSliderWrapper: UIViewRepresentable {
    @Binding var localPath: String
    @Binding var minSpace: Float
    @Binding var maxSpace: Float
    @Binding var startPosition: Float
    @Binding var endPosition: Float
    @Binding var actualPosition: Float
    @Binding var width: CGFloat
    @Binding var height: CGFloat
    @Binding var heightProgressIndicator: CGFloat
    @Binding var startY: CGFloat
    @Binding var imageFrame: Image?
    var customBackgroundStartEndTimeView: UIColor? = nil
    var fontStartEndTime: UIFont? = nil
    var startEndTimeViewPositionTop = true
    
    public init(localPath: Binding<String>, minSpace: Binding<Float>, maxSpace: Binding<Float>, startPosition: Binding<Float>, endPosition: Binding<Float>, actualPosition: Binding<Float>, width: Binding<CGFloat>, height: Binding<CGFloat> = .constant(159.0), heightProgressIndicator: Binding<CGFloat>, startY: Binding<CGFloat> = .constant(0), imageFrame: Binding<Image?>, customBackgroundStartEndTimeView: UIColor?, fontStartEndTime: UIFont?, startEndTimeViewPositionTop: Bool?) {
        self._localPath = localPath
        self._minSpace = minSpace
        self._maxSpace = maxSpace
        self._startPosition = startPosition
        
        self._actualPosition = actualPosition
        self._endPosition = endPosition

        self._width = width
        self._height = height
        self._heightProgressIndicator = heightProgressIndicator
        self._startY = startY
        self._imageFrame = imageFrame
        
        self.customBackgroundStartEndTimeView = customBackgroundStartEndTimeView
        self.fontStartEndTime = fontStartEndTime
        
        if startEndTimeViewPositionTop != nil
        {
            self.startEndTimeViewPositionTop = startEndTimeViewPositionTop!
        }
    }
    
    public func makeUIView(context: Context) -> VideoRangeSlider {
        let videoRangeSlider: VideoRangeSlider = VideoRangeSlider()

        // Correct indicator for SwiftUI
        videoRangeSlider.reSetupIndicator(width: self.width, height: self.height, heightProgressIndicator: self.heightProgressIndicator, startY: self.startY)
        
        // Set the video URL
        videoRangeSlider.setVideoURL(videoURL: URL(fileURLWithPath: self.localPath))
        
        // Set the delegate
        videoRangeSlider.delegate = context.coordinator

        // Set a minimun space (in seconds) between the Start indicator and End indicator
        videoRangeSlider.minSpace = self.minSpace

        // Set a maximun space (in seconds) between the Start indicator and End indicator - Default is 0 (no max limit)
        videoRangeSlider.maxSpace = self.maxSpace
        
        // Set initial position of Start Indicator
        videoRangeSlider.setStartPosition(seconds: self.startPosition)

        // Set initial position of End Indicator
        videoRangeSlider.setEndPosition(seconds: self.endPosition)
        
        // Set actual position
        videoRangeSlider.updateProgressIndicator(seconds: Float64(self.actualPosition))
            
        // Customize start and end time view
        if self.customBackgroundStartEndTimeView != nil
        {
            videoRangeSlider.startTimeView.backgroundView.backgroundColor = self.customBackgroundStartEndTimeView!
            videoRangeSlider.endTimeView.backgroundView.backgroundColor = self.customBackgroundStartEndTimeView!
        }
        
        // Customize font end time if exist
        if self.fontStartEndTime != nil
        {
            videoRangeSlider.startTimeView.timeLabel.font = self.fontStartEndTime
            videoRangeSlider.endTimeView.timeLabel.font = self.fontStartEndTime
        }
        
        videoRangeSlider.setTimeViewPosition(position: (self.startEndTimeViewPositionTop ? .top : .bottom))
            
        // Save image of frame (first frame)
        DispatchQueue.main.async {
            self.imageFrame = Image(uiImage: videoRangeSlider.getImageFromFrame(position: 0))
        }
        
        return videoRangeSlider
    }

    public func updateUIView(_ uiView: VideoRangeSlider, context: Context) {
        // Update end only if not setted
        if self.endPosition == 0
        {
            DispatchQueue.main.async {
                // If min space < 1 change
                if self.minSpace < 1.0
                {
                    self.minSpace = 1.0
                    uiView.minSpace = self.minSpace
                }
                
                // Update end and actual position
                let asset = AVAsset(url: URL(fileURLWithPath: self.localPath))
                let duration = asset.duration
                let durationTime = CMTimeGetSeconds(duration)
                
                self.endPosition = Float(durationTime)
                self.actualPosition = Float(durationTime)/2
                
                // Set initial position of End Indicator
                uiView.setEndPosition(seconds: self.endPosition)
                
                // Set actual position
                uiView.updateProgressIndicator(seconds: Float64(self.actualPosition))
            }
        }
        else
        {
            // Set actual position
            uiView.updateProgressIndicator(seconds: Float64(self.actualPosition))
        }
    }
    
    public func makeCoordinator() -> VideoRangeSliderWrapper.Coordinator {
        return Coordinator(self)
    }
}

@available(iOS 13.0, *)
extension VideoRangeSliderWrapper {
    public class Coordinator: NSObject, VideoRangeSliderDelegate {
        var parent: VideoRangeSliderWrapper
        
        init(_ parent: VideoRangeSliderWrapper) {
            self.parent = parent
        }
        
        public func indicatorDidChangePosition(videoRangeSlider: VideoRangeSlider, position: Float64) {
            // Save image of frame
            DispatchQueue.main.async {
                // Update parent var of actual position of progress indicator
                self.parent.actualPosition = Float(position)

                self.parent.imageFrame = Image(uiImage: videoRangeSlider.getImageFromFrame(position: Float(position)))
            }
        }
        
        public func didChangeValue(videoRangeSlider: VideoRangeSlider, startTime: Float64, endTime: Float64) {
            // Update parent var of actual position of indicator (start and end)
            self.parent.startPosition = Float(startTime)
            self.parent.endPosition = Float(endTime)
        }
    }
}
#endif
