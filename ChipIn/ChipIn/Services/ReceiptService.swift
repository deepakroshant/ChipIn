import Auth
import Foundation
import Supabase
import UIKit

private struct ParseReceiptBody: Encodable {
    let imageBase64: String
}

struct ParsedReceipt: Equatable {
    struct Item: Equatable {
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
    /// Store / merchant line from Gemini when present.
    var merchant: String? = nil

    /// Default expense title when the user hasn’t typed one (better than a generic “Receipt”).
    var suggestedTitle: String {
        if let m = merchant?.trimmingCharacters(in: .whitespacesAndNewlines), !m.isEmpty {
            return String(m.prefix(80))
        }
        if let first = items.first?.name.trimmingCharacters(in: .whitespacesAndNewlines), !first.isEmpty {
            if items.count > 1 {
                return "\(String(first.prefix(40))) + \(items.count - 1) more"
            }
            return String(first.prefix(80))
        }
        return "Receipt"
    }
}

struct ReceiptService {
    /// POST /functions/v1/parse-receipt with user JWT + anon apikey (same as Dashboard curl).
    private static func postParseReceipt(imageBase64: String, accessToken: String) async throws -> Data {
        let base = Secrets.supabaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: base + "/functions/v1/parse-receipt") else {
            throw ReceiptError.serverError("Invalid Supabase URL in Secrets.")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONEncoder().encode(ParseReceiptBody(imageBase64: imageBase64))

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw ReceiptError.serverError("No HTTP response from receipt service.")
        }
        if http.statusCode == 401 {
            throw ReceiptError.serverError(
                "Couldn’t authorize receipt scan. Sign out and sign back in, then try again."
            )
        }
        if !(200...299).contains(http.statusCode) {
            let msg = String(data: data, encoding: .utf8) ?? "\(http.statusCode)"
            throw ReceiptError.serverError("Receipt scan failed (\(http.statusCode)): \(msg.prefix(900))")
        }
        return data
    }

    func parseReceipt(image: UIImage) async throws -> ParsedReceipt {
        let prepared = image
            .chipInNormalizedOrientation()
            .chipInReceiptPrepared(maxDimension: 1600)
        guard let imageData = prepared.chipInJPEGDataForReceipt(quality: 0.88) else {
            throw ReceiptError.imageConversionFailed
        }
        let base64 = imageData.base64EncodedString()

        let session: Session
        do {
            session = try await supabase.auth.session
        } catch {
            throw ReceiptError.serverError("Sign in to scan receipts.")
        }

        // Use raw URLSession — `functions.invoke` can throw Cocoa’s “isn’t in the correct format”
        // while decoding the HTTP body before we see `Data`.
        let data: Data
        do {
            data = try await Self.postParseReceipt(imageBase64: base64, accessToken: session.accessToken)
        } catch {
            if let re = error as? ReceiptError { throw re }
            throw ReceiptError.serverError(error.localizedDescription)
        }

        return try Self.parseReceiptJSON(data)
    }

    /// Parses `{ items, subtotal, tax, tip, total }` or `{ error, detail }` using flexible number types.
    private static func parseReceiptJSON(_ data: Data) throws -> ParsedReceipt {
        let obj: Any
        do {
            obj = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            let snippet = String(data: data.prefix(200), encoding: .utf8) ?? ""
            throw ReceiptError.serverError("Bad response from server. \(snippet)")
        }

        guard let dict = obj as? [String: Any] else {
            throw ReceiptError.parseFailed
        }

        if let err = dict["error"] as? String {
            let detail = dict["detail"] as? String
            let msg = [err, detail].compactMap { $0 }.joined(separator: " — ")
            throw ReceiptError.serverError(msg.isEmpty ? err : msg)
        }

        guard let rawItems = dict["items"] as? [[String: Any]], !rawItems.isEmpty else {
            throw ReceiptError.serverError(
                "No items found in this image. Use a photo of a printed store receipt with prices visible."
            )
        }

        var parsedItems: [ParsedReceipt.Item] = []
        for row in rawItems {
            guard let name = row["name"] as? String else { continue }
            guard let price = doubleFromJSON(row["price"]) else { continue }
            parsedItems.append(ParsedReceipt.Item(name: name, price: Decimal(price), taxPortion: 0))
        }

        if parsedItems.isEmpty {
            throw ReceiptError.serverError("Couldn’t read line items from the model response.")
        }

        let subtotal = doubleFromJSON(dict["subtotal"]) ?? parsedItems.reduce(0) { $0 + (Double(truncating: NSDecimalNumber(decimal: $1.price))) }
        let tax = doubleFromJSON(dict["tax"]) ?? 0
        let tip = doubleFromJSON(dict["tip"]) ?? 0
        let total = doubleFromJSON(dict["total"]) ?? (subtotal + tax + tip)

        let taxRate = subtotal > 0 ? tax / subtotal : 0
        var itemsWithTax = parsedItems.map { item -> ParsedReceipt.Item in
            let p = Double(truncating: NSDecimalNumber(decimal: item.price))
            let portion = Decimal(p * taxRate)
            return ParsedReceipt.Item(name: item.name, price: item.price, taxPortion: portion)
        }

        // Fix rounding drift so sum(line tax) == receipt tax (last line absorbs remainder).
        let taxDecimal = Decimal(tax)
        let sumPortions = itemsWithTax.reduce(Decimal(0)) { $0 + $1.taxPortion }
        let drift = taxDecimal - sumPortions
        if drift != 0, let last = itemsWithTax.indices.last {
            itemsWithTax[last].taxPortion += drift
        }

        let merchantRaw = dict["merchant"] as? String ?? dict["store"] as? String
        let merchantTrimmed = merchantRaw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let merchant: String? = merchantTrimmed.isEmpty ? nil : merchantTrimmed

        return ParsedReceipt(
            items: itemsWithTax,
            subtotal: Decimal(subtotal),
            tax: Decimal(tax),
            tip: Decimal(tip),
            total: Decimal(total),
            merchant: merchant
        )
    }

    private static func doubleFromJSON(_ any: Any?) -> Double? {
        switch any {
        case let d as Double: return d
        case let i as Int: return Double(i)
        case let i as Int64: return Double(i)
        case let n as NSNumber: return n.doubleValue
        case let s as String: return Double(s)
        default: return nil
        }
    }
}

enum ReceiptError: LocalizedError {
    case imageConversionFailed
    case parseFailed
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Couldn’t convert this photo to JPEG. Try another image or take a new photo with the camera."
        case .parseFailed:
            return "Couldn’t read receipt data from the server. Try a clearer photo of a printed receipt."
        case .serverError(let s): return s
        }
    }
}

extension UIImage {
    /// Renders upright pixels so camera/library EXIF orientation doesn’t confuse OCR.
    func chipInNormalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Downscales large photos so Gemini gets a sharp, smaller JPEG (better than huge noisy images).
    func chipInReceiptPrepared(maxDimension: CGFloat) -> UIImage {
        let w = size.width
        let h = size.height
        let maxSide = max(w, h)
        guard maxSide > maxDimension else { return self }
        let ratio = maxDimension / maxSide
        let newSize = CGSize(width: floor(w * ratio), height: floor(h * ratio))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// SwiftUI `ImageRenderer` / wide-color images sometimes fail `jpegData`; redraw to an opaque bitmap first.
    func chipInJPEGDataForReceipt(quality: CGFloat) -> Data? {
        if let d = jpegData(compressionQuality: quality) { return d }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = min(max(scale, 1), 3)
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let flattened = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
        return flattened.jpegData(compressionQuality: quality)
    }

    /// Removes alpha to avoid “AlphaPremulLast” / oversized saves when rendering debug receipts.
    func chipInOpaqueOnWhite() -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
