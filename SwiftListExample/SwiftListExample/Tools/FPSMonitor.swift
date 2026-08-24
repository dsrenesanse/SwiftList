//
//  FPSMonitor.swift
//  SwiftListExample
//
//  Created by Dan on 2026/08/24.
//
import UIKit

@MainActor
@Observable
final class FPSMonitor {
   var fps: Double = 0

   let maximumFPS = UIScreen.main.maximumFramesPerSecond

   private var link: CADisplayLink?
   private var frameCount = 0
   private var windowStart: CFTimeInterval = 0

   func start() {
	  guard link == nil else { return }
	  let link = CADisplayLink(target: self, selector: #selector(tick))
	  link.preferredFrameRateRange = CAFrameRateRange(
		 minimum: 30,
		 maximum: Float(maximumFPS),
		 preferred: Float(maximumFPS)
	  )
	  link.add(to: .main, forMode: .common)
	  self.link = link
   }

   func stop() {
	  link?.invalidate()
	  link = nil
	  frameCount = 0
	  windowStart = 0
   }

   @objc private func tick(_ link: CADisplayLink) {
	  if windowStart == 0 {
		 windowStart = link.timestamp
		 return
	  }
	  frameCount += 1
	  let elapsed = link.timestamp - windowStart
	  if elapsed >= 0.5 {
		 fps = Double(frameCount) / elapsed
		 frameCount = 0
		 windowStart = link.timestamp
	  }
   }
}
