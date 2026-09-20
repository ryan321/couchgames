import AppKit

final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

enum StudioStyle {
    static func color(_ hex: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
    static let background = color(0x101722)
    static let panel = color(0x192331)
    static let border = color(0x2d3b4b)
    static let text = color(0xf2f5f8)
    static let muted = color(0xa0afbf)
    static let mint = color(0x8ce8be)
    static let amber = color(0xf3c77d)
    static let blue = color(0x9abef7)
    static func label(_ text: String, size: CGFloat = 14, weight: NSFont.Weight = .regular, color: NSColor = StudioStyle.text) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        return field
    }
    static func box(_ color: NSColor, radius: CGFloat = 12) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = color.cgColor
        view.layer?.cornerRadius = radius
        return view
    }
}

enum StudioBrand {
    static func image(_ resource: String) -> NSImage? {
        Bundle.main.image(forResource: resource)
    }
    static func applyAppIcon() {
        NSApp.applicationIconImage = image("AppIcon") ?? image("mark")
    }
    static func markView(size: CGFloat) -> NSImageView {
        let view = NSImageView()
        view.image = image("mark")
        view.imageScaling = .scaleProportionallyUpOrDown
        view.setAccessibilityLabel("Giga Couch")
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: size),
            view.heightAnchor.constraint(equalToConstant: size)
        ])
        return view
    }
}

final class StudioButton: NSButton {
    var primary = false { didSet { invalidateIntrinsicContentSize(); needsDisplay = true } }
    private var hovering = false
    override var intrinsicContentSize: NSSize {
        let width = (title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: primary ? 14 : 12, weight: .semibold)]).width
        return NSSize(width: width + (primary ? 40 : 28), height: primary ? 46 : 34)
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self))
    }
    override func mouseEntered(with event: NSEvent) { hovering = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovering = false; needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 9, yRadius: 9)
        let base = primary ? StudioStyle.mint : StudioStyle.border
        (isEnabled ? base.withAlphaComponent(isHighlighted ? 0.65 : hovering ? 1 : 0.90) : StudioStyle.border.withAlphaComponent(0.4)).setFill()
        shape.fill()
        if window?.firstResponder === self {
            StudioStyle.mint.setStroke(); shape.lineWidth = 2; shape.stroke()
        }
        let foreground = !isEnabled ? StudioStyle.muted.withAlphaComponent(0.45) : primary ? StudioStyle.background : StudioStyle.text
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: primary ? 14 : 12, weight: .semibold), .foregroundColor: foreground]
        let size = (title as NSString).size(withAttributes: attributes)
        (title as NSString).draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2), withAttributes: attributes)
    }
}

final class StatusPill: NSView {
    private let text = StudioStyle.label("CHECKING", size: 10, weight: .bold)
    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 12
        text.translatesAutoresizingMaskIntoConstraints = false
        addSubview(text)
        NSLayoutConstraint.activate([
            text.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 11),
            text.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -11),
            text.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 25)
        ])
        set("CHECKING", color: StudioStyle.muted)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func set(_ value: String, color: NSColor) {
        text.stringValue = value
        text.textColor = color
        layer?.backgroundColor = color.withAlphaComponent(0.12).cgColor
        setAccessibilityLabel(value)
    }
}

final class StudioRail: NSView {
    private let markView = NSImageView()
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        markView.image = StudioBrand.image("mark")
        markView.imageScaling = .scaleProportionallyUpOrDown
        markView.setAccessibilityLabel("Giga Couch")
        addSubview(markView)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() {
        super.layout()
        markView.frame = NSRect(x: 30, y: bounds.height - 118, width: 64, height: 64)
    }
    override func draw(_ dirtyRect: NSRect) {
        let bounds = self.bounds
        NSGradient(colors: [StudioStyle.color(0x213d3c), StudioStyle.color(0x16272d), StudioStyle.color(0x111d2a)])!.draw(in: bounds, angle: -90)
        func text(_ string: String, _ point: NSPoint, size: CGFloat, color: NSColor, weight: NSFont.Weight = .regular) {
            (string as NSString).draw(at: point, withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
        }
        text("GIGA", NSPoint(x: 104, y: bounds.height - 78), size: 16, color: StudioStyle.text, weight: .heavy)
        text("COUCH", NSPoint(x: 104, y: bounds.height - 98), size: 16, color: StudioStyle.text, weight: .heavy)
        text("GAME DEVELOPMENT KIT", NSPoint(x: 30, y: bounds.height - 148), size: 9, color: StudioStyle.mint, weight: .semibold)
        // Original vector illustration: stacked game worlds, drawn natively at any scale.
        NSGraphicsContext.saveGraphicsState()
        let origin = NSPoint(x: 130, y: bounds.height - 290)
        for index in stride(from: 2, through: 0, by: -1) {
            let y = origin.y - CGFloat(index) * 24
            let diamond = NSBezierPath()
            diamond.move(to: NSPoint(x: origin.x, y: y + 50))
            diamond.line(to: NSPoint(x: origin.x + 86, y: y))
            diamond.line(to: NSPoint(x: origin.x, y: y - 50))
            diamond.line(to: NSPoint(x: origin.x - 86, y: y))
            diamond.close()
            (index == 0 ? StudioStyle.mint.withAlphaComponent(0.19) : StudioStyle.blue.withAlphaComponent(0.06)).setFill()
            diamond.fill()
            (index == 0 ? StudioStyle.mint : StudioStyle.blue.withAlphaComponent(0.35)).setStroke()
            diamond.lineWidth = 1; diamond.stroke()
        }
        let line = NSBezierPath()
        line.move(to: NSPoint(x: 130, y: origin.y - 14))
        line.line(to: NSPoint(x: 130, y: origin.y + 64))
        StudioStyle.mint.setStroke(); line.lineWidth = 2; line.stroke()
        let flag = NSBezierPath()
        flag.move(to: NSPoint(x: 130, y: origin.y + 62)); flag.line(to: NSPoint(x: 159, y: origin.y + 54)); flag.line(to: NSPoint(x: 130, y: origin.y + 43)); flag.close()
        StudioStyle.mint.setFill(); flag.fill()
        for point in [NSPoint(x: 65, y: origin.y + 73), NSPoint(x: 199, y: origin.y + 25), NSPoint(x: 191, y: origin.y - 80)] {
            StudioStyle.mint.withAlphaComponent(0.7).setFill()
            NSBezierPath(ovalIn: NSRect(x: point.x, y: point.y, width: 4, height: 4)).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        let steps = [("01", "Connect your editor"), ("02", "Set up your kit"), ("03", "Choose your AI assistant"), ("04", "Make your first game")]
        for (index, step) in steps.enumerated() {
            let y = bounds.height - 427 - CGFloat(index) * 42
            text(step.0, NSPoint(x: 30, y: y), size: 11, color: StudioStyle.mint, weight: .semibold)
            text(step.1, NSPoint(x: 61, y: y - 1), size: 12, color: StudioStyle.text)
        }
        text("YOUR IDEAS. YOUR GAMES.", NSPoint(x: 30, y: 64), size: 9, color: StudioStyle.mint, weight: .semibold)
        text("Built for playing together.", NSPoint(x: 30, y: 42), size: 12, color: StudioStyle.muted)
    }
}
