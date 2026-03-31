import Supabase
import Foundation
import UIKit

struct ParsedReceipt {
    struct Item {
        var name: String
        var price: Decimal
        var taxPortion: Decimal = 0
        var assignedTo: UUID?
    }
    var items: [Item]
    var subtotal: Decimal
    var tax: Decimal
    var tip: Decimal
    var total: Decimal
}

struct ReceiptService {
    func parseReceipt(image: UIImage) async throws -> ParsedReceipt {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw ReceiptError.imageConversionFailed
        }
        let base64 = imageData.base64EncodedString()

        struct ParseReceiptBody: Encodable {
            let imageBase64: String
        }

        let data: Data = try await supabase.functions.invoke(
            "parse-receipt",
            options: .init(body: ParseReceiptBody(imageBase64: base64))
        )

        let result = try JSONDecoder().decode(ReceiptAPIResponse.self, from: data)

        let taxRate = result.subtotal > 0 ? Decimal(result.tax) / Decimal(result.subtotal) : 0
        let items = result.items.map { item -> ParsedReceipt.Item in
            let taxPortion = Decimal(item.price) * taxRate
            return ParsedReceipt.Item(
                name: item.name,
                price: Decimal(item.price),
                taxPortion: taxPortion
            )
        }

        return ParsedReceipt(
            items: items,
            subtotal: Decimal(result.subtotal),
            tax: Decimal(result.tax),
            tip: Decimal(result.tip),
            total: Decimal(result.total)
        )
    }
}

private struct ReceiptAPIResponse: Decodable {
    struct Item: Decodable { let name: String; let price: Double }
    let items: [Item]
    let subtotal: Double
    let tax: Double
    let tip: Double
    let total: Double
}

enum ReceiptError: Error {
    case imageConversionFailed
    case parseFailed
}
