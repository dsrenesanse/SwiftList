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
    @Binding var bottomInset: Double
    let handleKeyboard: Bool
    @ViewBuilder let cell: (Item) -> Cell

    public init(
        items: Array<Item>,
        reuseIds: Set<String>,
        reuseIdentifier: @escaping (Item) -> String,
        keyboardDismissMode: UIScrollView.KeyboardDismissMode = .none,
        scrollTarget: Binding<Item.ID?> = .constant(nil),
        scrollPosition: UICollectionView.ScrollPosition = .centeredVertically,
        bottomInset: Binding<Double> = .constant(0.0),
        handleKeyboard: Bool = true,
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
        self._bottomInset = bottomInset
        self.handleKeyboard = handleKeyboard
        self.cell = cell
    }

    public func makeUIView(context: Context) -> UIView {
        let view = UIView()
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

        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.heightAnchor.constraint(equalTo: view.heightAnchor).isActive = true
        collectionView.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
        collectionView.contentInset.bottom += bottomInset
        if handleKeyboard {
            var prevSize = 0.0
            let keyboardReporter = KeyboardReporter { size in
                let bottomInset = context.coordinator.bottomInset
                let diff = size - prevSize
                if !collectionView.isTracking {
                    collectionView.contentOffset.y += diff
                }
                collectionView.contentInset.bottom = size + bottomInset
                collectionView.scrollIndicatorInsets.bottom = size + bottomInset
                prevSize = size
                // flaky bug workaround
                //			let offsetBefore = collectionView.contentOffset
                //			collectionView.contentInset.bottom = size
                //			collectionView.contentOffset = offsetBefore
            }
            view.addSubview(keyboardReporter)
        }
        return view
    }

    public func updateUIView(
        _ view: UIView,
        context: Context
    ) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard
            let collectionView = view.subviews.first(where: { view in
                view as? UICollectionView != nil
            })
        else { return }
        coordinator.apply(to: collectionView as! UICollectionView)
        coordinator.bottomInset = bottomInset
    }

    public func makeCoordinator() -> Coordinator { Coordinator(self) }

    public final class Coordinator: NSObject, UICollectionViewDataSource,
        UICollectionViewDelegateFlowLayout
    {
        var parent: SwiftList
        var bottomInset = 0.0
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
                animated: true
            )
            parent.scrollTarget = nil
        }

        private func performApply(to collectionView: UICollectionView) async {

            let newIds = OrderedSet(parent.items.lazy.map(\.id))
            let oldIds = oldHashState.keys
            let diff = newIds.difference(from: oldIds).inferringMoves()
            let (deletes, inserts, moves) = identifyChanges(diff: diff)

            let consitencyCheckPassed =
                collectionView.numberOfItems(inSection: 0) - deletes.count + inserts.count
                == parent.items.count

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
            }.margins(.all, 0)
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
