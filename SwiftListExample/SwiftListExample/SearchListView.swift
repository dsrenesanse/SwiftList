//
//  SearchListView.swift
//  SwiftListExample
//
//  Demonstrates a SwiftList with a search text field in the toolbar.
//

import SwiftList
import SwiftUI
import UIKit

struct SearchListView: View {
    @State private var allItems: [TextItem] = SearchListView.sampleItems()
    @State private var searchText = ""
    @State var inputSize = 28.0

    private var filteredItems: [TextItem] {
        if searchText.isEmpty {
            return allItems
        }
        return allItems.filter {
            $0.text.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            SwiftList(
                items: filteredItems,
                reuseIds: Set(["TextView"]),
                reuseIdentifier: { _ in "TextView" },
                keyboardDismissMode: .interactive,
                bottomInset: $inputSize
            ) { item in
                await Self.size(for: item.text, width: proxy.size.width)
            } cell: { item in
                row(for: item)
            }
            .ignoresSafeArea(.keyboard)
            .ignoresSafeArea(.all, edges: .vertical)
        }
        //		.toolbarVisibility(.hidden, for: .tabBar)
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Games, Apps, Stories and More"
        )
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

    private static func sampleItems() -> [TextItem] {
        (1...50).map { index in
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
            width: width,
            height: .greatestFiniteMagnitude
        )
        let rect = (text as NSString).boundingRect(
            with: target,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return CGSize(width: width, height: ceil(rect.height))
    }
}

#Preview {
    NavigationStack {
        SearchListView()
    }
}
