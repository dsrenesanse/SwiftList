//
//  KeyboardReporter.swift
//  SwiftList
//
//  Created by Dan on 2026/08/29.
//

import UIKit

@MainActor
class KeyboardReporter: UIView {
    let onSizeChange: (_ value: CGFloat) -> Void

    init(onDiff: @escaping (_ value: CGFloat) -> Void) {
        self.onSizeChange = onDiff
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        start()
    }

    private var link: CADisplayLink!

    func start() {
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link.invalidate()
    }

    isolated deinit {
        stop()
    }

    var prevSize = 0.0
    @objc private func tick(_ link: CADisplayLink) {
        guard var height = layer.presentation()?.bounds.height else { return }
        height = max(height - (superview?.safeAreaInsets.bottom ?? 0.0), 0)

        guard height != prevSize else { return }
        onSizeChange(height)
        prevSize = height
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard let superview = superview else { return }

        if #available(iOS 17.0, *) {
            superview.keyboardLayoutGuide.usesBottomSafeArea = false
        }
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: superview.leadingAnchor),
            widthAnchor.constraint(equalToConstant: 1),
            bottomAnchor.constraint(equalTo: superview.bottomAnchor),
            topAnchor.constraint(equalTo: superview.keyboardLayoutGuide.topAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
