import AppKit

let app = NSApplication.shared

if let idx = CommandLine.arguments.firstIndex(of: "--render-preview"),
   idx + 1 < CommandLine.arguments.count {
    let outPath = CommandLine.arguments[idx + 1]
    let ok = MainActor.assumeIsolated {
        FocusPreviewRenderer.render(to: outPath)
    }
    exit(ok ? 0 : 1)
}

if let idx = CommandLine.arguments.firstIndex(of: "--render-icon"),
   idx + 1 < CommandLine.arguments.count {
    let outPath = CommandLine.arguments[idx + 1]
    let ok = MainActor.assumeIsolated {
        FocusPreviewRenderer.renderIcon(to: outPath)
    }
    exit(ok ? 0 : 1)
}

app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
