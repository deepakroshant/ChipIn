import Foundation

struct CurrencyService {
    func convert(amount: Decimal, from currency: String, to target: String = "CAD") async throws -> Decimal {
        guard currency != target else { return amount }
        let url = URL(string: "https://api.frankfurter.app/latest?from=\(currency)&to=\(target)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(FrankfurterResponse.self, from: data)
        guard let rate = response.rates[target] else { throw CurrencyError.rateNotFound }
        return amount * Decimal(rate)
    }
}

private struct FrankfurterResponse: Decodable {
    let rates: [String: Double]
}

enum CurrencyError: Error {
    case rateNotFound
}
