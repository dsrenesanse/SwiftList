//
//  ContentView.swift
//  SwiftListExample
//
//  Created by Dan on 18/07/2026.
//

//
//  BenchmarkView.swift
//  SwiftListExample
//

import SwiftList
import SwiftUI
import UIKit

let inset: CGFloat = 12

nonisolated struct TextItem: Identifiable, Hashable {
   let id = UUID()
   var text: String
}

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
      // Ask for the full ProMotion range, otherwise the system may
      // throttle the display (and this link) to 60 Hz or lower.
      link.preferredFrameRateRange = CAFrameRateRange(
         minimum: 30,
         maximum: Float(maximumFPS),
         preferred: Float(maximumFPS)
      )
      // .common so it keeps ticking while the user is scrolling.
      link.add(to: .main, forMode: .common)
      self.link = link
   }

   func stop() {
      link?.invalidate()  // also breaks the display link's retain of self
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

struct BenchmarkView: View {
   @State private var items: [TextItem] = []
   @State private var fpsMonitor = FPSMonitor()

   private static let words = [
      "swift", "collection", "layout", "performance", "asynchronous",
      "benchmark", "generation", "token", "stream", "diffing",
      "cache", "invalidate", "reconfigure", "measurement", "incremental",
      "the", "a", "of", "and", "extraordinarily",
   ]

   var body: some View {
      GeometryReader { proxy in
         SwiftList(items: $items) { item in
            await Self.size(for: item.text, width: proxy.size.width)
         } cell: { item in
            Text(item.text)
               .font(.body)
               .frame(maxWidth: .infinity, alignment: .leading)
               .padding(inset)
               .background(
                  RoundedRectangle(cornerRadius: 12)
                     .fill(Color(.secondarySystemBackground))
               )
         }
      }
      .overlay(alignment: .bottomTrailing) {
         HStack(spacing: 8) {
            Text(
               "\(Int(fpsMonitor.fps.rounded())) / \(fpsMonitor.maximumFPS) fps"
            )
            .foregroundStyle(fpsColor)
            Text("items: \(items.count)")
         }
         .font(.caption.monospacedDigit())
         .padding(6)
         .background(.thinMaterial, in: Capsule())
         .padding()
      }
      .task { await generate() }
      .onAppear { fpsMonitor.start() }
      .onDisappear { fpsMonitor.stop() }
   }

   private var fpsColor: Color {
      let ratio = fpsMonitor.fps / Double(fpsMonitor.maximumFPS)
      if ratio >= 0.9 { return .green }
      if ratio >= 0.75 { return .orange }
      return .red
   }

   private func generate() async {
      // Initial single item
      items.append(TextItem(text: Self.words.randomElement()!))

      while !Task.isCancelled {
         try? await Task.sleep(for: .milliseconds(10))
         let word = Self.words.randomElement()!

         if items[items.count - 1].text.count > 50_000_000_000_000_000 {
            // Latest "message" is full — start a new one
            items.append(TextItem(text: word))
         } else {
            // Keep streaming into the latest item
            items[items.count - 1].text += " " + word
         }
      }
   }

   @concurrent
   private static func size(
      for text: String,
      width: CGFloat
   ) async -> CGSize {
      let font = UIFont.preferredFont(forTextStyle: .body)
      let target = CGSize(
         width: max(width - inset * 2, 0),
         height: .greatestFiniteMagnitude
      )
      let rect = (text as NSString).boundingRect(
         with: target,
         options: [.usesLineFragmentOrigin, .usesFontLeading],
         attributes: [.font: font],
         context: nil
      )
      return CGSize(width: width, height: ceil(rect.height) + inset * 2)
   }
}

#Preview {
   BenchmarkView()
}
