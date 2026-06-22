import AppKit

let outputPaths = CommandLine.arguments.dropFirst()
guard !outputPaths.isEmpty else {
    fatalError("Pass one or more output PNG paths.")
}

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()

let rect = NSRect(origin: .zero, size: size)

let backgroundGradient = NSGradient(colors: [
    NSColor(red: 0.08, green: 0.50, blue: 1.0, alpha: 1),
    NSColor(red: 0.56, green: 0.30, blue: 1.0, alpha: 1),
    NSColor(red: 1.0, green: 0.22, blue: 0.62, alpha: 1)
])!
backgroundGradient.draw(in: rect, angle: 32)

func ribbon(points: [CGPoint], color: NSColor, width: CGFloat) {
    let path = NSBezierPath()
    guard let first = points.first else { return }
    path.move(to: first)
    var index = 1
    while index + 2 < points.count {
        path.curve(to: points[index + 2], controlPoint1: points[index], controlPoint2: points[index + 1])
        index += 3
    }
    color.setStroke()
    path.lineWidth = width
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.stroke()
}

ribbon(
    points: [
        CGPoint(x: -110, y: 260),
        CGPoint(x: 190, y: 430),
        CGPoint(x: 336, y: 164),
        CGPoint(x: 626, y: 298),
        CGPoint(x: 782, y: 368),
        CGPoint(x: 866, y: 170),
        CGPoint(x: 1_140, y: 324)
    ],
    color: NSColor.white.withAlphaComponent(0.18),
    width: 114
)

ribbon(
    points: [
        CGPoint(x: -120, y: 792),
        CGPoint(x: 146, y: 642),
        CGPoint(x: 370, y: 900),
        CGPoint(x: 586, y: 704),
        CGPoint(x: 802, y: 520),
        CGPoint(x: 912, y: 756),
        CGPoint(x: 1_132, y: 612)
    ],
    color: NSColor(red: 0.00, green: 0.88, blue: 1.0, alpha: 0.30),
    width: 132
)

ribbon(
    points: [
        CGPoint(x: 70, y: -80),
        CGPoint(x: 232, y: 168),
        CGPoint(x: 86, y: 306),
        CGPoint(x: 318, y: 512),
        CGPoint(x: 524, y: 692),
        CGPoint(x: 700, y: 472),
        CGPoint(x: 1_010, y: 660)
    ],
    color: NSColor(red: 1.0, green: 0.86, blue: 0.98, alpha: 0.20),
    width: 80
)

let glass = NSBezierPath(roundedRect: rect.insetBy(dx: 86, dy: 120), xRadius: 184, yRadius: 184)
NSColor(red: 0.05, green: 0.06, blue: 0.18, alpha: 0.30).setFill()
glass.fill()
NSColor.white.withAlphaComponent(0.22).setStroke()
glass.lineWidth = 7
glass.stroke()

let text = "L!V!N"
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let font = NSFont.systemFont(ofSize: 178, weight: .black)
let textAttributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .paragraphStyle: paragraph,
    .foregroundColor: NSColor.white,
    .kern: 1
]
let shadowAttributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .paragraphStyle: paragraph,
    .foregroundColor: NSColor.black.withAlphaComponent(0.24),
    .kern: 1
]
text.draw(in: NSRect(x: 96, y: 408, width: 840, height: 224).offsetBy(dx: 0, dy: -12), withAttributes: shadowAttributes)
text.draw(in: NSRect(x: 92, y: 408, width: 840, height: 224), withAttributes: textAttributes)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let representation = NSBitmapImageRep(data: tiff),
      let png = representation.representation(using: .png, properties: [:]) else {
    fatalError("Could not render icon PNG.")
}

for outputPath in outputPaths {
    try png.write(to: URL(fileURLWithPath: String(outputPath)))
}
