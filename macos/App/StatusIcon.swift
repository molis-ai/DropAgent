import AppKit

enum StatusIcon {
    static func image() -> NSImage {
        let point = NSSize(width: 18, height: 18)
        let image = NSImage(size: point)
        for scale in [1, 2] {
            let pixels = 18 * scale
            guard let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: pixels,
                pixelsHigh: pixels,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ) else { continue }
            NSGraphicsContext.saveGraphicsState()
            if let ctx = NSGraphicsContext(bitmapImageRep: rep) {
                NSGraphicsContext.current = ctx
                ctx.shouldAntialias = true
                ctx.cgContext.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
                draw()
            }
            NSGraphicsContext.restoreGraphicsState()
            rep.size = point
            image.addRepresentation(rep)
        }
        image.isTemplate = true
        return image
    }

    private static func draw() {
        NSColor.black.setFill()
        NSColor.black.setStroke()

        let hopper = NSBezierPath()
        hopper.move(to: NSPoint(x: 3.55, y: 12.45))
        hopper.line(to: NSPoint(x: 14.45, y: 12.45))
        hopper.line(to: NSPoint(x: 9, y: 5.45))
        hopper.close()
        hopper.lineJoinStyle = .round
        hopper.lineCapStyle = .round
        hopper.lineWidth = 1.45
        hopper.fill()
        hopper.stroke()

        NSBezierPath(
            roundedRect: NSRect(x: 4.9, y: 1.95, width: 8.2, height: 1.65),
            xRadius: 0.825,
            yRadius: 0.825
        ).fill()
    }
}
