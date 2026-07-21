# SwiftList

A fast list for SwiftUI, built on `UICollectionView` with a flow layout and async item size estimation.

It is made for lists where items change all the time — chat apps, and especially AI chat apps where text streams into the last message many times per second. A plain SwiftUI `List` or `ScrollView` starts to drop frames in that case. SwiftList does not, because it:

- Measures item sizes off the main thread. You give it an async closure that returns the size for an item. Sizes are computed in parallel with a task group and cached by item id.
- Only touches what changed. It diffs the old and new arrays by id, so it knows exactly which items were inserted, deleted, or moved. Items whose content changed (same id, different hash) are reconfigured in place, without animation.
- Never re-renders the whole list. Cells are reused by `UICollectionView`, and each cell hosts your SwiftUI view through `UIHostingConfiguration`.
- Coalesces rapid updates. If a new update comes in while one is still being applied, the old one is cancelled. Aggressive text updates do not pile up.

## Requirements

- iOS 16+
- Swift 6

## Installation

Add the package in Xcode (File → Add Package Dependencies) or in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/dsrenesanse/SwiftList.git", from: "1.0.0")
]
```

Then import it:

```swift
import SwiftList
```

## Usage

`SwiftList` takes three things:

1. An array of items. Items must be `Identifiable`, `Hashable`, and `Sendable`. The hash is how SwiftList detects that an item's content changed.
2. An async closure that returns the size for one item. This runs off the main thread, so you can do real text measurement here without blocking scrolling.
3. A view builder for the cell.

```swift
SwiftList(items: items) { item in
    // async — runs off the main thread
    await size(for: item)
} cell: { item in
    Text(item.text)
}
```

### Full example: a streaming chat

This is the example from the `SwiftListExample` folder. It streams words into the last message every 10 ms — the same load pattern as an AI chat — and shows an FPS meter on top so you can see the list stays at full frame rate.

First, the item type. The hash of `text` is what tells SwiftList a message changed:

```swift
nonisolated struct TextItem: Identifiable, Hashable {
    let id = UUID()
    var text: String
}
```

The list itself. `GeometryReader` gives us the width to measure text against:

```swift
let inset: CGFloat = 12

var body: some View {
    GeometryReader { proxy in
        SwiftList(items: items) { item in
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
}
```

The size closure measures the text with `boundingRect`. It is marked `@concurrent`, so it never runs on the main thread:

```swift
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
```

And the "AI is typing" simulation — append a word to the last item every 10 ms. That means 100 updates per second, and each one only reconfigures a single cell:

```swift
private func generate() async {
    items.append(TextItem(text: Self.words.randomElement()!))

    while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(10))
        let word = Self.words.randomElement()!
        // Keep streaming into the latest item
        items[items.count - 1].text += " " + word
    }
}
```

### The FPS meter

The example includes a small `FPSMonitor` built on `CADisplayLink`. It asks for the full ProMotion range (up to 120 Hz on supported devices) and shows the current frame rate over the list:

```swift
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
        // .common so it keeps ticking while the user is scrolling.
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
```

Overlay it on the list and start it when the view appears:

```swift
.overlay(alignment: .bottomTrailing) {
    Text("\(Int(fpsMonitor.fps.rounded())) / \(fpsMonitor.maximumFPS) fps")
        .font(.caption.monospacedDigit())
        .padding(6)
        .background(.thinMaterial, in: Capsule())
        .padding()
}
.onAppear { fpsMonitor.start() }
.onDisappear { fpsMonitor.stop() }
```

Run the example, scroll while the text is streaming, and watch the meter stay at the display's maximum frame rate.

## How it works

1. When `items` changes, SwiftList diffs the new array against the old one by id, with move inference.
2. Items with the same id but a different hash are marked for reconfigure.
3. Sizes for inserted and changed items are computed in parallel through your async closure and stored in a cache. Sizes for removed items are dropped from the cache.
4. Inserts, deletes, and moves are applied with `performBatchUpdates`. Changed items are reconfigured in place with `reconfigureItems`, without animation, so streaming text does not flicker.
5. The flow layout reads sizes straight from the cache, so layout on the main thread is just a dictionary lookup.

If updates arrive faster than they can be applied, the pending one is cancelled and replaced by the newest — the list never falls behind the data.

## Running the example

Open `SwiftListExample/SwiftListExample.xcodeproj` and run it on a device. Use a real device with a ProMotion display if you can — that is where the FPS meter is most interesting.

## License

SwiftList is licensed under [CC BY-ND 4.0](https://creativecommons.org/licenses/by-nd/4.0/). In short:

- **Free to use**, including in commercial products.
- **Credit required.** Mention SwiftList somewhere the user can reach — for example the app's Settings or About screen — with the author name (Dan) and a link to https://github.com/dsrenesanse/SwiftList.
- **No modified copies.** You may not distribute a changed version of this library. If you want to improve it, propose the change to this repository instead.

See the [LICENSE](LICENSE) file for details.
