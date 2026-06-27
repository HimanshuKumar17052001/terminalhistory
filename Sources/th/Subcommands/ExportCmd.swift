import Foundation
import THCore

extension Subcommands {
    public enum ExportCmd {
        public static func run(_ p: ArgumentParser) -> Int32 {
            guard let id = p.positional.first,
                  let format = p.flags["format"].flatMap({ ExportFormat(rawValue: $0) }),
                  let out = p.flags["out"] else {
                FileHandle.standardError.write(Data("export: usage: th export <id> --format cast|txt --out <path>\n".utf8))
                return 2
            }
            let store = List.openStore()
            do {
                let url = URL(fileURLWithPath: (out as NSString).expandingTildeInPath)
                switch format {
                case .cast: try Export(store: store).cast(sessionID: id, to: url)
                case .txt:  try Export(store: store).text(sessionID: id, to: url)
                }
                store.close()
                print("wrote \(url.path)"); return 0
            } catch {
                FileHandle.standardError.write(Data("export: \(error)\n".utf8)); return 1
            }
        }
    }
}