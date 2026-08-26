//
//  SwiftList.swift
//  SwiftListExample
//
//  Created by Dan on 18/07/2026.
//

import SwiftUI
import UIKit
import OrderedCollections

public struct SwiftList<Item: Identifiable & Hashable & Sendable, Cell: View>:
    UIViewRepresentable
where Item.ID: Sendable {

    let items: Array<Item>
    let itemSize: (Item) async -> CGSize
    let reuseIdentifier: (Item) -> String
    let reuseIds: Set<String>
    let keyboardDismissMode: UIScrollView.KeyboardDismissMode
    @Binding var scrollTarget: Item.ID?
    let scrollPosition: UICollectionView.ScrollPosition
    let scrollAnimated: Bool
    @ViewBuilder let cell: (Item) -> Cell

    public init(
        items: Array<Item>,
        reuseIds: Set<String>,
        reuseIdentifier: @escaping (Item) -> String,
        keyboardDismissMode: UIScrollView.KeyboardDismissMode = .none,
        scrollTarget: Binding<Item.ID?> = .constant(nil),
        scrollPosition: UICollectionView.ScrollPosition = .centeredVertically,
        scrollAnimated: Bool = true,
        itemSize: @escaping (Item) async -> CGSize,
        @ViewBuilder cell: @escaping (Item) -> Cell
    ) {
        self.items = items
        self.itemSize = itemSize
        self.reuseIdentifier = reuseIdentifier
        self.reuseIds = reuseIds
        self.keyboardDismissMode = keyboardDismissMode
        self._scrollTarget = scrollTarget
        self.scrollPosition = scrollPosition
        self.scrollAnimated = scrollAnimated
        self.cell = cell
    }

    public func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.estimatedItemSize = .zero
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.keyboardDismissMode = keyboardDismissMode
        collectionView.backgroundColor = .clear
        context.coordinator.makeDataSource(for: collectionView)
        collectionView.delegate = context.coordinator
        for id in reuseIds {
            collectionView.register(
                UICollectionViewCell.self,
                forCellWithReuseIdentifier: id
            )
        }

        return collectionView
    }

    public func updateUIView(
        _ collectionView: UICollectionView,
        context: Context
    ) {
        context.coordinator.parent = self
        context.coordinator.apply(to: collectionView)
    }

    public func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor
    public final class Coordinator: NSObject, UICollectionViewDelegateFlowLayout {

        var parent: SwiftList
        private var dataSource: UICollectionViewDiffableDataSource<Int, Item.ID>!
        private var hashes: Dictionary<Item.ID, Int> = [:]
        private var sizes: Dictionary<Item.ID, CGSize> = [:]

        init(_ parent: SwiftList) {
            self.parent = parent
            super.init()
        }

        func makeDataSource(for collectionView: UICollectionView) {
            dataSource = .init(collectionView: collectionView) { [weak self] cv, indexPath, id in
                guard let self, let item = self.parent.items.first(where: { $0.id == id })
                else { return UICollectionViewCell() }

                let cell = cv.dequeueReusableCell(
                    withReuseIdentifier: self.parent.reuseIdentifier(item),
                    for: indexPath
                )
                cell.contentConfiguration = UIHostingConfiguration {
                    self.parent.cell(item)
                }
                .margins(.all, 0)
                return cell
            }
        }

        private var task: Task<Void, Never>?

        func apply(to collectionView: UICollectionView) {
			Task {
                await performApply(on: collectionView)
            }
        }

        private func performApply(on collectionView: UICollectionView) async {
            let unmeasured = parent.items.filter { sizes[$0.id] == nil }
            let tasks = unmeasured.map { item in
                (id: item.id, task: Task { await parent.itemSize(item) })
            }
            for entry in tasks {
                sizes[entry.id] = await entry.task.value
            }

            let ids = parent.items.map(\.id)
            if ids != dataSource.snapshot().itemIdentifiers {
                var snapshot = NSDiffableDataSourceSnapshot<Int, Item.ID>()
                snapshot.appendSections([0])
                snapshot.appendItems(ids)
                await dataSource.apply(snapshot, animatingDifferences: true)
            }

			let known = Set(dataSource.snapshot().itemIdentifiers)

			var changed: Array<Item> = []
			for item in parent.items
			where known.contains(item.id) && hashes[item.id] != item.hashValue {
				hashes[item.id] = item.hashValue
				changed.append(item)
			}

			if !changed.isEmpty {
				let tasks = changed.map { item in
					(id: item.id, task: Task { await parent.itemSize(item) })
				}
				for entry in tasks {
					sizes[entry.id] = await entry.task.value
				}

				var snapshot = dataSource.snapshot()
				snapshot.reconfigureItems(changed.map(\.id))
				await dataSource.apply(snapshot, animatingDifferences: false)
			}

            flushScroll(on: collectionView)
        }

        private func flushScroll(on collectionView: UICollectionView) {
            guard
                let target = parent.scrollTarget,
                let indexPath = dataSource.indexPath(for: target)
            else { return }
            collectionView.scrollToItem(
                at: indexPath,
                at: parent.scrollPosition,
                animated: parent.scrollAnimated
            )
            parent.scrollTarget = nil
        }

        public func collectionView(
            _ collectionView: UICollectionView,
            layout: UICollectionViewLayout,
            sizeForItemAt indexPath: IndexPath
        ) -> CGSize {
            guard let id = dataSource.itemIdentifier(for: indexPath) else {
                return .zero
            }
            return sizes[id] ?? .zero
        }
    }
}
