//
//  SwiftList.swift
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
        collectionView.dataSource = context.coordinator
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

    public final class Coordinator: NSObject, UICollectionViewDataSource,
        UICollectionViewDelegateFlowLayout
    {
        var parent: SwiftList
        private var sizeCache = Dictionary<Item.ID, CGSize>()
        private var oldHashState = OrderedDictionary<Item.ID, Int>()

        init(_ parent: SwiftList) { self.parent = parent }

        var task: Task<Void, Never>?

        func apply(to collectionView: UICollectionView) {
            let oldTask = task
            task = Task {
                await oldTask?.value
                await performApply(to: collectionView)
                flushScroll(on: collectionView)
            }
        }

        private func flushScroll(on collectionView: UICollectionView) {
            guard
                let target = parent.scrollTarget,
                let index = parent.items.firstIndex(where: { $0.id == target })
            else { return }
            collectionView.scrollToItem(
                at: IndexPath(item: index, section: 0),
                at: parent.scrollPosition,
                animated: parent.scrollAnimated
            )
            parent.scrollTarget = nil
        }

        private func performApply(to collectionView: UICollectionView) async {
            let newIds = OrderedSet(parent.items.lazy.map(\.id))
            let oldIds = oldHashState.keys
            let diff = newIds.difference(from: oldIds).inferringMoves()
            let (deletes, inserts, moves) = identifyChanges(diff: diff)
			
            let consitencyCheckPassed =
			collectionView.numberOfItems(inSection: 0) - deletes.count + inserts.count == parent.items.count
			
            if consitencyCheckPassed {
				if moves.isEmpty {
					if !deletes.isEmpty { collectionView.deleteItems(at: deletes) }
					if !inserts.isEmpty { collectionView.insertItems(at: inserts) }
				} else {
					collectionView.performBatchUpdates {
						collectionView.deleteItems(at: deletes)
						collectionView.insertItems(at: inserts)
						for move in moves { collectionView.moveItem(at: move.from, to: move.to) }
					}
				}
            }

            var reconfigures = Array<IndexPath>()
            for (index, item) in parent.items.enumerated() {
                let oldHash = oldHashState[item.id]
                let newHash = item.hashValue
                if oldHash != newHash {
                    reconfigures.append(IndexPath(item: index, section: 0))
                }
            }
            await calculateAndCacheSizes(indexes: reconfigures)
            UIView.performWithoutAnimation {
                collectionView.reconfigureItems(at: reconfigures)
            }
            oldHashState = OrderedDictionary(
                uniqueKeysWithValues: parent.items.map { ($0.id, $0.hashValue) }
            )
        }

        private func calculateAndCacheSizes(indexes: Array<IndexPath>) async {
            let tasks = indexes.map { index in
                let item = parent.items[index.item]
                return Task { await (id: item.id, size: parent.itemSize(item)) }
            }
            for task in tasks {
                let result = await task.value
                sizeCache[result.id] = result.size
            }
        }
		
		private func identifyChanges(diff: CollectionDifference<Item.ID>) -> (
			Array<IndexPath>,
			Array<IndexPath>,
			Array<(from: IndexPath, to: IndexPath)>,
		) {
			var deletes = Array<IndexPath>()
			var inserts = Array<IndexPath>()
			var moves = Array<(from: IndexPath, to: IndexPath)>()

			for change in diff {
				switch change {
					case .remove(let offset, _, let associatedWith):
						if associatedWith == nil {
							deletes.append(IndexPath(item: offset, section: 0))
						}
					case .insert(let offset, _, let associatedWith):
						if let from = associatedWith {
							moves.append(
								(
									IndexPath(item: from, section: 0),
									IndexPath(item: offset, section: 0)
								)
							)
						} else {
							inserts.append(IndexPath(item: offset, section: 0))
						}
				}
			}

			return (
				deletes,
				inserts,
				moves,
			)
		}

        public func collectionView(
            _ collectionView: UICollectionView,
            numberOfItemsInSection section: Int
        ) -> Int {
            parent.items.count
        }

        public func collectionView(
            _ collectionView: UICollectionView,
            cellForItemAt indexPath: IndexPath
        ) -> UICollectionViewCell {
            let item = parent.items[indexPath.item]
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: parent.reuseIdentifier(item),
                for: indexPath
            )
            cell.contentConfiguration = UIHostingConfiguration {
                self.parent.cell(item)
            }
            .margins(.all, 0)
            return cell
        }

        public func collectionView(
            _ collectionView: UICollectionView,
            layout collectionViewLayout: UICollectionViewLayout,
            sizeForItemAt indexPath: IndexPath
        ) -> CGSize {
            sizeCache[parent.items[indexPath.item].id] ?? .zero
        }
    }
}
