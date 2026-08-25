# SwiftList

<br>

<br>

A fast list for SwiftUI, built on `UICollectionView` with a flow layout and async item size estimation.

It is made for lists where items change all the time — chat apps, and especially AI chat apps where text streams into the last message many times per second. A plain SwiftUI `List` or `ScrollView` starts to drop frames in that case. SwiftList does not, because it:

- Measures item sizes off the main thread. You give it an async closure that returns the size for an item. Sizes are computed in parallel with a task group and cached by item id.
- Only touches what changed. It diffs the old and new arrays by id, so it knows exactly which items were inserted, deleted, or moved. Items whose content changed (same id, different hash) are reconfigured in place, without animation.
- Never re-renders the whole list. Cells are reused by `UICollectionView`, and each cell hosts your SwiftUI view through `UIHostingConfiguration`.

## Requirements

- iOS 16+
- Swift 6

## Usage

`SwiftList` takes three things:

1. An array of items. Items must be `Identifiable`, `Hashable`, and `Sendable`. The hash is how SwiftList detects that an item's content changed.
2. An async closure that returns the size for one item. This should run off the main thread, so you can do real measurement here without blocking scrolling.
3. A view builder for the cell.

```swift
SwiftList(items: items) { item in
    // async — runs off the main thread
    await size(for: item)
} cell: { item in
    Text(item.text)
}
```

## Example

Take a look at the example in the `SwiftListExample` folder and run it to see the result for yourself — a streaming chat that keeps the list at full frame rate even while text pours in.

## License

SwiftList is licensed under [CC BY-ND 4.0](https://creativecommons.org/licenses/by-nd/4.0/). In short:

- **Free to use**, including in commercial products.
- **Credit required.** Mention SwiftList somewhere the user can reach — for example the app's Settings or About screen — with the author name (Dan) and a link to https://github.com/dsrenesanse/SwiftList.
- **No modified copies.** You may not distribute a changed version of this library. If you want to improve it, propose the change to this repository instead.

See the [LICENSE](LICENSE) file for details.
