//
//  EditableListView.swift
//  SwiftListExample
//
//  Demonstrates adding, removing and reordering items in a SwiftList.
//

import SwiftList
import SwiftUI
import UIKit

struct EditableListView: View {
    @State private var items: [TextItem] = EditableListView.sampleItems()

    private static let words = [
        "swift", "collection", "layout", "diffing", "insert",
        "remove", "reorder", "animate", "binding", "cell",
    ]

    var body: some View {
        GeometryReader { proxy in
            SwiftList(
                items: items,
                reuseIds: Set(["TextView"]),
                reuseIdentifier: { item in "TextView" },
            ) { item in
                await Self.size(for: item.text, width: proxy.size.width)
            } cell: { item, _ in
                row(for: item)
            }
        }
        .navigationTitle("Add / Remove / Reorder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    shuffle()
                } label: {
                    Label("Shuffle", systemImage: "shuffle")
                }
                Spacer()
                Button {
                    add()
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
    }

    @ViewBuilder
    private func row(for item: TextItem) -> some View {
        HStack(spacing: 12) {
            Text(item.text)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                moveUp(item)
            } label: {
                Image(systemName: "arrow.up")
            }
            .disabled(items.first?.id == item.id)

            Button {
                moveDown(item)
            } label: {
                Image(systemName: "arrow.down")
            }
            .disabled(items.last?.id == item.id)

            Button(role: .destructive) {
                remove(item)
            } label: {
                Image(systemName: "trash")
            }
        }
        .buttonStyle(.borderless)
        .padding(inset)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func add() {
        let word = Self.words.randomElement()!
        let index = Int.random(in: 0...items.count)
        items.insert(TextItem(text: "New: \(items.count + 1). \(word)"), at: index)
    }

    private func remove(_ item: TextItem) {
        items.removeAll { $0.id == item.id }
    }

    private func moveUp(_ item: TextItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }),
            index > 0
        else { return }
        items.swapAt(index, index - 1)
    }

    private func moveDown(_ item: TextItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }),
            index < items.count - 1
        else { return }
        items.swapAt(index, index + 1)
    }

    private func shuffle() {
        items.shuffle()
    }

    private static func sampleItems() -> [TextItem] {
        words.enumerated().prefix(6).map { index, word in
            TextItem(text: "\(index + 1). \(word)")
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
    NavigationStack {
        EditableListView()
    }
}
