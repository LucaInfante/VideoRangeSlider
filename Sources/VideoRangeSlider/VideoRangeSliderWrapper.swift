//
//  File.swift
//  
//
//  Created by Luca Infante on 09/02/21.
//

import UIKit
import SwiftUI
import AVKit

@available(iOS 13.0, *)
struct ABVideoRangeSliderWrapper: UIViewRepresentable {
    @Binding var localPath: String
    @Binding var minSpace: Float
    @Binding var maxSpace: Float
    @Binding var startPosition: Float
    @Binding var endPosition: Float
    @Binding var actualPosition: Float
    @Binding var height: CGFloat
    @Binding var startY: CGFloat
    
    init(localPath: Binding<String>, minSpace: Binding<Float>, maxSpace: Binding<Float>, startPosition: Binding<Float> = .constant(0), endPosition: Binding<Float> = .constant(0), actualPosition: Binding<Float> = .constant(0), height: Binding<CGFloat> = .constant(159.0), startY: Binding<CGFloat> = .constant(0)) {
        self._localPath = localPath
        self._minSpace = minSpace
        self._maxSpace = maxSpace
        self._startPosition = startPosition
        self._endPosition = endPosition
        self._actualPosition = actualPosition
        self._height = height
        self._startY = startY
    }
    
    func makeUIView(context: Context) -> VideoRangeSlider {
        let videoRangeSlider: VideoRangeSlider = VideoRangeSlider()

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
        
        // Correct indicator for SwiftUI
        videoRangeSlider.reSetupIndicator(height: self.height, startY: self.startY)
        
        return videoRangeSlider
    }

    func updateUIView(_ uiView: VideoRangeSlider, context: Context) {
        //
    }
    
    func makeCoordinator() -> ABVideoRangeSliderWrapper.Coordinator {
        return Coordinator(self)
    }
}

@available(iOS 13.0, *)
extension ABVideoRangeSliderWrapper {
    class Coordinator: NSObject, VideoRangeSliderDelegate {
        var parent: ABVideoRangeSliderWrapper
        
        init(_ parent: ABVideoRangeSliderWrapper) {
            self.parent = parent
        }
        
        func indicatorDidChangePosition(videoRangeSlider: VideoRangeSlider, position: Float64) {
            // Update parent var of actual position of progress indicator
            self.parent.actualPosition = Float(position)
        }
        
        func didChangeValue(videoRangeSlider: VideoRangeSlider, startTime: Float64, endTime: Float64) {
            // Update parent var of actual position of indicator (start and end)
            self.parent.startPosition = Float(startTime)
            self.parent.endPosition = Float(endTime)
        }
    }
}
