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

nonisolated struct ImageItem: Identifiable, Hashable {
    let id = UUID()
    var url: URL
    var pixelSize: CGSize
    var widthFraction: CGFloat
}

enum ShowcaseTab: Hashable {
    case text
    case images
    case edit
    case scroll
}

struct BenchmarkView: View {
    @State private var selection: ShowcaseTab = .text

    var body: some View {
        TabView(selection: $selection) {
            TextShowcaseView(isActive: selection == .text)
                .tabItem {
                    Label("Text", systemImage: "text.alignleft")
                }
                .tag(ShowcaseTab.text)
            ImageShowcaseView(isActive: selection == .images)
                .tabItem {
                    Label("Images", systemImage: "photo")
                }
                .tag(ShowcaseTab.images)
            NavigationStack {
                EditableListView()
            }
            .tabItem {
                Label("Edit", systemImage: "slider.horizontal.3")
            }
            .tag(ShowcaseTab.edit)
            NavigationStack {
                ScrollToIndexView()
            }
            .tabItem {
                Label("Scroll", systemImage: "scope")
            }
            .tag(ShowcaseTab.scroll)
        }
    }
}

struct TextShowcaseView: View {
    let isActive: Bool

    @State private var items: [TextItem] = []
    @State private var fpsMonitor = FPSMonitor()
    @State private var fpsFontIndex = 1
    private let fpsFontSizes: [Font] = [.caption2, .caption, .footnote, .body, .title3]

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
                reuseIds: Set(["Text"]),
                reuseIdentifier: { _ in "Text" },
                itemSize: { item in
                    await Self.size(for: item.text, width: proxy.size.width)
                }
            ) { item in
                Text(item.text)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(inset)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
            }
			.ignoresSafeArea(.all, edges: .vertical)
        }
        .overlay(alignment: .bottomTrailing) {
            fpsOverlay
        }
        .task(id: isActive) {
            guard isActive else { return }
            await generate()
        }
        .onChange(of: isActive) { _, active in
            if active { fpsMonitor.start() } else { fpsMonitor.stop() }
        }
        .onAppear { fpsMonitor.start() }
        .onDisappear { fpsMonitor.stop() }
    }

    private var fpsOverlay: some View {
        HStack(spacing: 8) {
            Text(
                "\(Int(fpsMonitor.fps.rounded())) / \(fpsMonitor.maximumFPS) fps"
            )
            .foregroundStyle(fpsColor)
            Text("items: \(items.count)")
        }
        .font(fpsFontSizes[fpsFontIndex].monospacedDigit())
        .padding(6)
        .background(.thinMaterial, in: Capsule())
        .padding()
        .onTapGesture {
            fpsFontIndex = (fpsFontIndex + 1) % fpsFontSizes.count
        }
    }

    private var fpsColor: Color {
        let ratio = fpsMonitor.fps / Double(fpsMonitor.maximumFPS)
        if ratio >= 0.9 { return .green }
        if ratio >= 0.75 { return .orange }
        return .red
    }

    private func generate() async {
        items.append(.init(text: Self.words.randomElement()!))

        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(10))
            let word = Self.words.randomElement()!
            if items[items.count - 1].text.count > 3000 {
                items.append(.init(text: word))
            } else {
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

struct ImageShowcaseView: View {
    let isActive: Bool

    @State private var items: [ImageItem] = []
    @State private var fpsMonitor = FPSMonitor()
    @State private var fpsFontIndex = 1
    private let fpsFontSizes: [Font] = [.caption2, .caption, .footnote, .body, .title3]

    var body: some View {
        GeometryReader { proxy in
            SwiftList(
                items: items,
                reuseIds: Set(["Image"]),
                reuseIdentifier: { _ in "Image" },
                itemSize: { item in
                    await Self.size(for: item, width: proxy.size.width)
                }
            ) { item in
                Self.cell(for: item)
            }
			.ignoresSafeArea(.all, edges: .vertical)
        }
        .overlay(alignment: .bottomTrailing) {
            fpsOverlay
        }
        .task(id: isActive) {
            guard isActive else { return }
            await generate()
        }
        .onChange(of: isActive) { _, active in
            if active { fpsMonitor.start() } else { fpsMonitor.stop() }
        }
        .onAppear { fpsMonitor.start() }
        .onDisappear { fpsMonitor.stop() }
    }

    private var fpsOverlay: some View {
        HStack(spacing: 8) {
            Text(
                "\(Int(fpsMonitor.fps.rounded())) / \(fpsMonitor.maximumFPS) fps"
            )
            .foregroundStyle(fpsColor)
            Text("items: \(items.count)")
        }
        .font(fpsFontSizes[fpsFontIndex].monospacedDigit())
        .padding(6)
        .background(.thinMaterial, in: Capsule())
        .padding()
        .onTapGesture {
            fpsFontIndex = (fpsFontIndex + 1) % fpsFontSizes.count
        }
    }

    private var fpsColor: Color {
        let ratio = fpsMonitor.fps / Double(fpsMonitor.maximumFPS)
        if ratio >= 0.9 { return .green }
        if ratio >= 0.75 { return .orange }
        return .red
    }

    private func generate() async {
        while !Task.isCancelled {
            let url = Self.imageURL(for: items.count)
            guard let image = await ImageLoader.load(url) else { continue }
            let item = ImageItem(
                url: url,
                pixelSize: image.size,
                widthFraction: .random(in: 0.28...0.5)
            )
            items.append(item)
        }
    }

    private static let dims: [(Int, Int)] = [
        (800, 800), (1200, 800), (800, 1200), (900, 600), (600, 900),
    ]

    private static func imageURL(for index: Int) -> URL {
        let (w, h) = dims[index % dims.count]
        return URL(string: "https://picsum.photos/seed/\(index)/\(w)/\(h)")!
    }

    @ViewBuilder
    private static func cell(for item: ImageItem) -> some View {
        if let image = ImageLoader.cached(item.url) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Color(.secondarySystemBackground)
        }
    }

    @concurrent
    private static func size(
        for item: ImageItem,
        width: CGFloat
    ) async -> CGSize {
        let cellWidth = max(width * item.widthFraction, 80)
        let ratio = item.pixelSize.height / item.pixelSize.width
        return CGSize(width: cellWidth, height: cellWidth * ratio)
    }
}

#Preview {
    BenchmarkView()
}
