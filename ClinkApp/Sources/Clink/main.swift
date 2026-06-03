import AppKit
import ClinkCore

let args = CommandLine.arguments

if args.contains("--demo") {
    do {
        let code = try DemoRunner.run(bundle: .module)
        exit(code)
    } catch {
        fputs("Clink demo error: \(error)\n", stderr)
        exit(2)
    }
}

ClinkApp.main()
