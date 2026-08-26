//
//  ScrollToIndexView.swift
//  SwiftListExample
//
//  Demonstrates scrolling a SwiftList to a specific item by index.
//

import SwiftList
import SwiftUI
import UIKit

struct ScrollToIndexView: View {
   @State private var items: [TextItem] = ScrollToIndexView.sampleItems()
   @State private var scrollTarget: TextItem.ID?
   @State private var indexText = "0"

   var body: some View {
      GeometryReader { proxy in
         SwiftList(
            items: items,
            reuseIds: Set(["TextView"]),
            reuseIdentifier: { _ in "TextView" },
            scrollTarget: $scrollTarget,
            scrollPosition: .centeredVertically,
            scrollAnimated: true,
         ) { item in
            await Self.size(for: item.text, width: proxy.size.width)
         } cell: { item in
            row(for: item)
         }
      }
      .navigationTitle("Scroll to Index")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
         ToolbarItemGroup(placement: .bottomBar) {
            Button {
               scrollToTop()
            } label: {
               Label("Top", systemImage: "arrow.up.to.line")
            }

            TextField("Index", text: $indexText)
               .keyboardType(.numberPad)
               .frame(width: 60)
               .textFieldStyle(.roundedBorder)

            Button {
               scrollToEnteredIndex()
            } label: {
               Label("Go", systemImage: "scope")
            }

            Spacer()

            Button {
               scrollToRandom()
            } label: {
               Label("Random", systemImage: "dice")
            }
         }
      }
   }

   @ViewBuilder
   private func row(for item: TextItem) -> some View {
      Text(item.text)
         .font(.body)
         .frame(maxWidth: .infinity, alignment: .leading)
         .padding(inset)
         .background(
            RoundedRectangle(cornerRadius: 12)
               .fill(Color(.secondarySystemBackground))
         )
   }

   private func scrollToTop() {
      scrollTarget = items.first?.id
   }

   private func scrollToEnteredIndex() {
      guard let index = Int(indexText), items.indices.contains(index) else {
         return
      }
      scrollTarget = items[index].id
   }

   private func scrollToRandom() {
      guard items.count > 1 else { return }
      let index = Int.random(in: 0..<items.count)
      indexText = "\(index)"
      scrollTarget = items[index].id
   }

   private static func sampleItems() -> [TextItem] {
      (1...500).map { index in
         TextItem(text: "\(index). Item #\(index)")
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
      ScrollToIndexView()
   }
}
