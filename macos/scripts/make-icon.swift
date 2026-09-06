import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
    NSGraphicsContext.current?.shouldAntialias = true
    NSColor(calibratedRed: 28 / 255, green: 28 / 255, blue: 30 / 255, alpha: 1).setFill()
    NSBezierPath(rect: rect).fill()

    let inset = size * 0.22
    let field = rect.insetBy(dx: inset, dy: inset)
    let path = NSBezierPath()
    path.move(to: NSPoint(x: field.minX, y: field.minY + field.height * 0.62))
    path.line(to: NSPoint(x: field.maxX, y: field.minY + field.height * 0.62))
    path.line(to: NSPoint(x: field.midX, y: field.minY + field.height * 0.12))
    path.close()
    NSColor(calibratedWhite: 0.96, alpha: 1).setStroke()
    path.lineJoinStyle = .round
    path.lineCapStyle = .round
    path.lineWidth = size * 0.055
    path.stroke()

    let shelf = NSBezierPath()
    shelf.move(to: NSPoint(x: field.minX + field.width * 0.22, y: field.minY))
    shelf.line(to: NSPoint(x: field.maxX - field.width * 0.22, y: field.minY))
    NSColor(calibratedWhite: 0.96, alpha: 1).setStroke()
    shelf.lineCapStyle = .round
    shelf.lineWidth = size * 0.055
    shelf.stroke()
    return true
}

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:])
else {
    fputs("make-icon: png failed\n", stderr)
    exit(1)
}

let out = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "/dev/stdout")
try png.write(to: out)
