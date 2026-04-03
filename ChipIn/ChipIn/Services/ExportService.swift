import Foundation
import UniformTypeIdentifiers

struct ExportService {
    func generateCSV(expenses: [Expense]) -> URL {
        var csv = "Date,Title,Category,Amount,Currency,Paid By\n"
        let df = ISO8601DateFormatter()
        for e in expenses {
            let row = [
                df.string(from: e.createdAt),
                "\"\(e.title.replacingOccurrences(of: "\"", with: "\"\""))\"",
                e.category,
                "\(e.totalAmount)",
                e.currency,
                e.paidBy.uuidString
            ].joined(separator: ",")
            csv += row + "\n"
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("chipin-export-\(Date().timeIntervalSince1970).csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
