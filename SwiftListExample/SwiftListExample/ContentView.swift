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

nonisolated enum BenchmarkItem: Identifiable, Hashable, Sendable {
   case text(UUID, String)
   case image(UUID, Int)
   case button(UUID, String)

   var id: UUID {
      switch self {
      case .text(let id, _): return id
      case .image(let id, _): return id
      case .button(let id, _): return id
      }
   }
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
   @State private var items: [BenchmarkItem] = []
   @State private var fpsMonitor = FPSMonitor()

   private static let words = [
      "swift", "collection", "layout", "performance", "asynchronous",
      "benchmark", "generation", "token", "stream", "diffing",
      "cache", "invalidate", "reconfigure", "measurement", "incremental",
      "the", "a", "of", "and", "extraordinarily",
   ]

   var body: some View {
      GeometryReader { proxy in
         SwiftList(
            items: items,
            reuseIds: Set(["Text", "Image", "Button"]),
            reuseIdentifier: { item in
               switch item {
               case .text: return "Text"
               case .image: return "Image"
               case .button: return "Button"
               }
            },
            itemSize: { item in
               await Self.size(for: item, width: proxy.size.width)
            }
         ) { item in
            Self.cell(for: item)
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
      .toolbar {
         ToolbarItem(placement: .topBarTrailing) {
            NavigationLink {
               EditableListView()
            } label: {
               Label("Edit", systemImage: "slider.horizontal.3")
            }
         }
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
      items.append(.text(UUID(), Self.words.randomElement()!))

      while !Task.isCancelled {
         try? await Task.sleep(for: .milliseconds(10))
         let word = Self.words.randomElement()!
         if case .text(_, let text) = items[items.count - 1] {
            if text.count > 3000 {
               items.append(.image(UUID(), Int.random(in: 0..<Self.imageNames.count)))
               items.append(.button(UUID(), Self.words.randomElement()!))
               items.append(.text(UUID(), word))
            } else {
               let id = items[items.count - 1].id
               items[items.count - 1] = .text(id, text + " " + word)
            }
         }
      }
   }

   @concurrent
   private static func size(
      for item: BenchmarkItem,
      width: CGFloat
   ) async -> CGSize {
      switch item {
      case .text(_, let text):
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
      case .image:
         return CGSize(width: width / 2, height: 160)
      case .button:
         return CGSize(width: width / 1.5, height: 56)
      }
   }

   private static let imageNames = [
      "photo", "photo.fill", "person.crop.circle", "star.fill", "heart.fill",
   ]

   @ViewBuilder
   private static func cell(for item: BenchmarkItem) -> some View {
      switch item {
      case .text(_, let text):
         Text(text)
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(inset)
            .background(
               RoundedRectangle(cornerRadius: 12)
                  .fill(Color(.secondarySystemBackground))
            )
      case .image(_, let index):
         Image(systemName: Self.imageNames[index % Self.imageNames.count])
            .font(.system(size: 72))
            .frame(maxWidth: .infinity)
            .padding(inset)
            .background(
               RoundedRectangle(cornerRadius: 12)
                  .fill(Color(.secondarySystemBackground))
            )
      case .button(_, let label):
         Button {
            // no-op action for the demo
         } label: {
            Text(label)
               .font(.headline)
               .frame(maxWidth: .infinity)
               .padding(inset)
               .foregroundStyle(.white)
               .background(
                  RoundedRectangle(cornerRadius: 12)
                     .fill(Color.accentColor)
               )
         }
      }
   }
}

#Preview {
   BenchmarkView()
}
