//
//  SwiftList.swift
//  SwiftListExample
//
//  Created by Dan on 18/07/2026.
//

import SwiftUI
import UIKit

public struct SwiftList<Item: Identifiable & Hashable & Sendable, Cell: View>:
    UIViewRepresentable
where Item.ID: Sendable {

    @Binding var items: [Item]
    var itemSize: @Sendable (Item) async -> CGSize
    @ViewBuilder var cell: (Item) -> Cell

    public init(
        items: Binding<[Item]>,
        itemSize: @escaping @Sendable (Item) async -> CGSize,
        @ViewBuilder cell: @escaping (Item) -> Cell
    ) {
        self._items = items
        self.itemSize = itemSize
        self.cell = cell
    }

    public func makeCoordinator() -> Coordinator { Coordinator(self) }

    public func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.estimatedItemSize = .zero
        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )
        collectionView.backgroundColor = .clear
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.register(
            UICollectionViewCell.self,
            forCellWithReuseIdentifier: "cell"
        )
        return collectionView
    }

    public func updateUIView(_ collectionView: UICollectionView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.apply(to: collectionView)
    }

    public final class Coordinator: NSObject, UICollectionViewDataSource,
        UICollectionViewDelegateFlowLayout
    {
        var parent: SwiftList

        private var currentItems: [Item] = []
        private var sizeCache: [Item.ID: CGSize] = [:]
        private var applyTask: Task<Void, Never>?

        init(_ parent: SwiftList) { self.parent = parent }

        func apply(to collectionView: UICollectionView) {
            let previousTask = applyTask
            previousTask?.cancel()
            applyTask = Task { @MainActor [weak self] in
                await previousTask?.value
                guard !Task.isCancelled else { return }
                await self?.performApply(to: collectionView)
            }
        }

        @MainActor
        private func performApply(to collectionView: UICollectionView) async {
            let newItems = parent.items
            let newIDs = newItems.map(\.id)
            let oldIDs = currentItems.map(\.id)
            let oldHashes = Dictionary(
                uniqueKeysWithValues: currentItems.map { ($0.id, $0.hashValue) }
            )

            let diff = newIDs.difference(from: oldIDs).inferringMoves()
            var deletes: [IndexPath] = []
            var inserts: [IndexPath] = []
            var moves: [(from: IndexPath, to: IndexPath)] = []

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

            var reconfigures: [IndexPath] = []
            for (index, item) in newItems.enumerated() {
                if let oldHash = oldHashes[item.id], oldHash != item.hashValue {
                    reconfigures.append(IndexPath(item: index, section: 0))
                }
            }

            guard
                !deletes.isEmpty || !inserts.isEmpty || !moves.isEmpty
                    || !reconfigures.isEmpty
            else { return }

            let removedIDs = deletes.map { oldIDs[$0.item] }

            let itemSize = parent.itemSize
            let itemsToSize = (inserts + reconfigures).map { newItems[$0.item] }
            let sizes = await withTaskGroup(of: (Item.ID, CGSize).self) {
                group in
                for item in itemsToSize {
                    group.addTask { (item.id, await itemSize(item)) }
                }
                var result: [Item.ID: CGSize] = [:]
                for await (id, size) in group {
                    result[id] = size
                }
                return result
            }

            guard !Task.isCancelled else { return }

            for (id, size) in sizes {
                sizeCache[id] = size
            }
            removedIDs.forEach { sizeCache[$0] = nil }

            if !deletes.isEmpty || !inserts.isEmpty || !moves.isEmpty {
                collectionView.performBatchUpdates {
                    self.currentItems = newItems
                    collectionView.deleteItems(at: deletes)
                    collectionView.insertItems(at: inserts)
                    moves.forEach {
                        collectionView.moveItem(at: $0.from, to: $0.to)
                    }
                }
            } else {
                currentItems = newItems
            }

            if !reconfigures.isEmpty {
                UIView.performWithoutAnimation {
                    collectionView.reconfigureItems(at: reconfigures)
                    //                        let invalidation =
                    //                            UICollectionViewFlowLayoutInvalidationContext()
                    //                        invalidation.invalidateItems(at: reconfigures)
                    //                        collectionView.collectionViewLayout.invalidateLayout(
                    //                            with: invalidation
                    //                        )
                }
            }
        }

        public func collectionView(
            _ collectionView: UICollectionView,
            numberOfItemsInSection section: Int
        ) -> Int {
            currentItems.count
        }

        public func collectionView(
            _ collectionView: UICollectionView,
            cellForItemAt indexPath: IndexPath
        ) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "cell",
                for: indexPath
            )
            let item = currentItems[indexPath.item]
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
            sizeCache[currentItems[indexPath.item].id] ?? .zero
        }
    }
}
