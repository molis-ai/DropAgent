import AppKit
import DropAgentIngest
import QuartzCore

final class EdgeDropView: NSView {
    var onPick: ((WheelAction, NSPasteboard) -> Bool)?
    var onReleased: (() -> Void)?
    private var slices: [WheelSlice] = WheelLayout.slices(hasAgent: true, hasRecipe: true)
    private var hotIndex: Int?
    private var tiles: [WheelSliceView] = []

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: EdgePlacement.windowSize, height: EdgePlacement.windowSize))
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        for _ in 0..<EdgePlacement.sliceCount {
            let tile = WheelSliceView()
            tiles.append(tile)
            addSubview(tile)
        }
        registerForDraggedTypes(IncomingDrop.draggedTypes)
        setAccessibilityRole(.group)
        setAccessibilityLabel(Copy.t("DropAgent 轮盘", "DropAgent wheel"))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isOpaque: Bool { false }

    override func layout() {
        super.layout()
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        for (index, tile) in tiles.enumerated() {
            let slice = slices.indices.contains(index) ? slices[index] : slices[0]
            tile.place(
                path: EdgePlacement.tilePath(index: index, center: center),
                slice: slice,
                in: bounds
            )
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let index = EdgePlacement.sliceIndex(point: point, in: bounds) else { return nil }
        guard slices.indices.contains(index), slices[index].enabled else { return nil }
        return self
    }

    func apply(slices: [WheelSlice], hot: Int?) {
        let next = hot.flatMap { slices.indices.contains($0) && slices[$0].enabled ? $0 : nil }
        let slicesChanged = self.slices != slices
        self.slices = slices
        if slicesChanged { needsLayout = true }
        setHot(next)
    }

    func setHot(_ hot: Int?) {
        let next = hot.flatMap { slices.indices.contains($0) && slices[$0].enabled ? $0 : nil }
        guard hotIndex != next else { return }
        hotIndex = next
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        for (index, tile) in tiles.enumerated() {
            tile.setHot(index == next, animated: reduce == false)
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        highlight(sender)
        return currentOperation(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        highlight(sender)
        return currentOperation(sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        setHot(nil)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        currentOperation(sender) == .copy
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        onReleased?()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let point = dropPoint(sender)
        guard let index = EdgePlacement.sliceIndex(point: point, in: bounds),
              slices.indices.contains(index),
              slices[index].enabled
        else { return false }
        return onPick?(slices[index].action, sender.draggingPasteboard) ?? false
    }

    private func dropPoint(_ sender: NSDraggingInfo) -> NSPoint {
        let fromWindow = convert(sender.draggingLocation, from: nil)
        if EdgePlacement.sliceIndex(point: fromWindow, in: bounds) != nil {
            return fromWindow
        }
        guard let window else { return fromWindow }
        return convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
    }

    private func highlight(_ sender: NSDraggingInfo) {
        setHot(EdgePlacement.sliceIndex(point: dropPoint(sender), in: bounds))
    }

    private func currentOperation(_ sender: NSDraggingInfo) -> NSDragOperation {
        let point = dropPoint(sender)
        guard let index = EdgePlacement.sliceIndex(point: point, in: bounds),
              slices.indices.contains(index),
              slices[index].enabled
        else { return [] }
        return .copy
    }
}

private final class WheelSliceView: NSView {
    private let frost = NSVisualEffectView()
    private let chrome = SliceChromeView()
    private let maskLayer = CAShapeLayer()
    private var localPath = NSBezierPath()
    private var slice = WheelLayout.slices(hasAgent: true, hasRecipe: true)[0]
    private var hot = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        frost.material = .popover
        frost.blendingMode = .behindWindow
        frost.state = .active
        frost.wantsLayer = true
        frost.layer?.mask = maskLayer
        maskLayer.fillColor = NSColor.black.cgColor
        chrome.owner = self
        chrome.wantsLayer = true
        chrome.layer?.backgroundColor = NSColor.clear.cgColor
        addSubview(frost)
        addSubview(chrome)
        frost.appearance = NSAppearance(named: Palette.isDark ? .vibrantDark : .vibrantLight)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func place(path: NSBezierPath, slice: WheelSlice, in wheel: NSRect) {
        self.slice = slice
        let pad: CGFloat = 14
        let box = path.bounds.insetBy(dx: -pad, dy: -pad)
        if box.isNull || box.isEmpty {
            isHidden = true
            return
        }
        isHidden = false
        frame = box
        let local = path.copy() as? NSBezierPath ?? path
        let shift = AffineTransform(translationByX: -box.minX, byY: -box.minY)
        local.transform(using: shift)
        localPath = local
        frost.appearance = NSAppearance(named: Palette.isDark ? .vibrantDark : .vibrantLight)
        frost.frame = bounds
        chrome.frame = bounds
        maskLayer.frame = bounds
        maskLayer.path = local.cgPath
        layer?.shadowPath = local.cgPath
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOffset = CGSize(width: 0, height: -5)
        layer?.shadowRadius = hot ? 12 : 7
        layer?.shadowOpacity = slice.enabled ? (hot ? 0.24 : 0.14) : 0.08
        chrome.needsDisplay = true
    }

    func setHot(_ hot: Bool, animated: Bool) {
        let changed = self.hot != hot
        self.hot = hot
        layer?.shadowRadius = hot ? 12 : 7
        layer?.shadowOpacity = slice.enabled ? (hot ? 0.24 : 0.14) : 0.08
        layer?.shadowColor = NSColor.black.cgColor
        chrome.needsDisplay = true
        guard changed else { return }
        let scale: CGFloat = hot && slice.enabled ? EdgePlacement.bounceScale : 1
        if animated {
            let spring = CASpringAnimation(keyPath: "transform.scale")
            let current = (layer?.presentation()?.value(forKeyPath: "transform.scale") as? NSNumber)?.doubleValue ?? 1
            spring.fromValue = current
            spring.toValue = scale
            spring.mass = 0.45
            spring.stiffness = 420
            spring.damping = 22
            spring.duration = min(spring.settlingDuration, EdgePlacement.bounceDuration)
            layer?.add(spring, forKey: "bounce")
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.setValue(scale, forKeyPath: "transform.scale")
        CATransaction.commit()
    }

    fileprivate func drawChrome() {
        let tone: NSColor
        switch slice.action {
        case .shelf: tone = Palette.current(light: 0xA7803E, dark: 0xC9A566)
        case .send: tone = Palette.current(light: 0x9270B1, dark: 0xBC9ADA)
        case .recipe(let recipe):
            switch recipe {
            case .summarize: tone = Palette.current(light: 0x647DB5, dark: 0x91A8DC)
            case .extract: tone = Palette.current(light: 0x5684AA, dark: 0x8AB2D5)
            case .translate: tone = Palette.current(light: 0x5684AA, dark: 0x8AB2D5)
            default: tone = Palette.current(light: 0x9270B1, dark: 0xBC9ADA)
            }
        }
        Palette.paperNS.withAlphaComponent(0.96).setFill()
        localPath.fill()
        if hot && slice.enabled {
            tone.withAlphaComponent(Palette.isDark ? 0.18 : 0.10).setFill()
            localPath.fill()
        }
        (hot ? tone.withAlphaComponent(0.7) : Palette.current(light: 0xE8E8E6, dark: 0x2B2B2F)).setStroke()
        localPath.lineWidth = hot ? 1.4 : 0.8
        localPath.stroke()
        let ink = slice.enabled ? Palette.textNS : Palette.mutedNS.withAlphaComponent(0.5)
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        drawSymbol(slice.symbol, at: NSPoint(x: center.x, y: center.y + 10), color: slice.enabled ? tone : ink)
        drawLabel(slice.title, at: NSPoint(x: center.x, y: center.y - 13), color: ink)
    }

    private func drawSymbol(_ name: String, at point: NSPoint, color: NSColor) {
        guard let raw = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return }
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        guard let image = raw.withSymbolConfiguration(config) else { return }
        let size = image.size
        image.draw(
            in: NSRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height),
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: nil
        )
    }

    private func drawLabel(_ title: String, at point: NSPoint, color: NSColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10.5, weight: .medium),
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
        let label = title.replacingOccurrences(of: "转为 Markdown", with: "转为\nMarkdown")
        let size = NSSize(width: 72, height: 28)
        let text = NSAttributedString(string: label, attributes: attrs)
        let height = text.boundingRect(with: size, options: [.usesLineFragmentOrigin]).height
        text.draw(in: NSRect(x: point.x - size.width / 2, y: point.y - height / 2, width: size.width, height: height))

    }
}

private final class SliceChromeView: NSView {
    weak var owner: WheelSliceView?

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        owner?.drawChrome()
    }
}
