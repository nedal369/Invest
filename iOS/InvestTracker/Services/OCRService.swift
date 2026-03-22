import Foundation
import Vision
import UIKit

// MARK: - OCR Service
class OCRService {
    static let shared = OCRService()

    private init() {}

    // MARK: - Extract Text from Image
    func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations.compactMap { obs in
                    obs.topCandidates(1).first?.string
                }.joined(separator: "\n")

                continuation.resume(returning: text)
            }

            request.recognitionLanguages = ["ar", "en"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Parse Transaction from OCR Text
    func parseTransaction(from text: String) -> ParsedTransactionData {
        var parsed = ParsedTransactionData()

        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }

        for line in lines {
            // Extract amount (Arabic numerals or Western)
            if let amount = extractAmount(from: line) {
                if parsed.amount == nil { parsed.amount = amount }
            }

            // Extract date
            if let date = extractDate(from: line) {
                if parsed.date == nil { parsed.date = date }
            }

            // Detect transaction type
            if parsed.transactionType == nil {
                parsed.transactionType = detectTransactionType(from: line)
            }

            // Extract symbol
            if let symbol = extractSymbol(from: line) {
                if parsed.symbol == nil { parsed.symbol = symbol }
            }

            // Extract quantity
            if let qty = extractQuantity(from: line) {
                if parsed.quantity == nil { parsed.quantity = qty }
            }

            // Extract fees
            if let fee = extractFee(from: line) {
                if parsed.fees == nil { parsed.fees = fee }
            }
        }

        return parsed
    }

    // MARK: - Amount Extraction
    private func extractAmount(from text: String) -> Decimal? {
        // Pattern: numbers with optional decimal point
        // Support both Arabic-Indic and Western digits
        let normalizedText = normalizeDigits(text)

        let patterns = [
            #"(?:المبلغ|الإجمالي|القيمة|total|amount)[:\s]+([0-9,]+\.?[0-9]*)"#,
            #"([0-9,]+\.?[0-9]*)\s*(?:ريال|SAR|ر\.س)"#,
            #"([0-9,]+\.[0-9]{2})"#
        ]

        for pattern in patterns {
            if let match = normalizedText.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let matched = String(normalizedText[match])
                let cleaned = matched.replacingOccurrences(of: ",", with: "")
                    .components(separatedBy: CharacterSet.decimalDigits.inverted.union(CharacterSet(charactersIn: ".")))
                    .joined()
                if let value = Decimal(string: cleaned), value > 0 {
                    return value
                }
            }
        }
        return nil
    }

    // MARK: - Date Extraction
    private func extractDate(from text: String) -> Date? {
        let normalizedText = normalizeDigits(text)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar_SA")

        // Try various date formats
        let formats = [
            "dd/MM/yyyy", "yyyy-MM-dd", "dd-MM-yyyy",
            "dd MMM yyyy", "MM/dd/yyyy"
        ]

        let pattern = #"(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})"#
        if let match = normalizedText.range(of: pattern, options: .regularExpression) {
            let dateStr = String(normalizedText[match])
            for format in formats {
                formatter.dateFormat = format
                if let date = formatter.date(from: dateStr) {
                    return date
                }
            }
        }
        return nil
    }

    // MARK: - Transaction Type Detection
    private func detectTransactionType(from text: String) -> TransactionType? {
        let lowerText = text.lowercased()
        let arabicText = text

        if arabicText.contains("شراء") || lowerText.contains("buy") || lowerText.contains("purchase") {
            return .buy
        } else if arabicText.contains("بيع") || lowerText.contains("sell") {
            return .sell
        } else if arabicText.contains("إيداع") || arabicText.contains("ايداع") || lowerText.contains("deposit") {
            return .deposit
        } else if arabicText.contains("سحب") || lowerText.contains("withdraw") {
            return .withdraw
        } else if arabicText.contains("توزيع") || arabicText.contains("ربح") || lowerText.contains("dividend") {
            return .dividend
        } else if arabicText.contains("رسوم") || lowerText.contains("fee") || lowerText.contains("commission") {
            return .fee
        }
        return nil
    }

    // MARK: - Symbol Extraction
    private func extractSymbol(from text: String) -> String? {
        // Saudi symbols: 4-digit numbers (like 2222 for Aramco)
        // US symbols: 1-5 uppercase letters
        let patterns = [
            #"(?:رمز|symbol)[:\s]+([A-Z0-9]{2,6})"#,
            #"\b([0-9]{4})\b"#,  // Saudi
            #"\b([A-Z]{2,5})\b"#  // US
        ]

        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                return String(text[match]).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    // MARK: - Quantity Extraction
    private func extractQuantity(from text: String) -> Decimal? {
        let normalizedText = normalizeDigits(text)
        let patterns = [
            #"(?:كمية|عدد|quantity|shares)[:\s]+([0-9,]+\.?[0-9]*)"#,
            #"([0-9,]+)\s*(?:سهم|وحدة|unit|share)"#
        ]

        for pattern in patterns {
            if let match = normalizedText.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let matched = String(normalizedText[match])
                let cleaned = matched.components(separatedBy: CharacterSet.decimalDigits.inverted.union(CharacterSet(charactersIn: "."))).joined()
                if let value = Decimal(string: cleaned), value > 0 {
                    return value
                }
            }
        }
        return nil
    }

    // MARK: - Fee Extraction
    private func extractFee(from text: String) -> Decimal? {
        let normalizedText = normalizeDigits(text)
        let patterns = [
            #"(?:رسوم|عمولة|fee|commission)[:\s]+([0-9,]+\.?[0-9]*)"#
        ]

        for pattern in patterns {
            if let match = normalizedText.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let matched = String(normalizedText[match])
                let cleaned = matched.components(separatedBy: CharacterSet.decimalDigits.inverted.union(CharacterSet(charactersIn: "."))).joined()
                if let value = Decimal(string: cleaned), value > 0 {
                    return value
                }
            }
        }
        return nil
    }

    // MARK: - Normalize Arabic-Indic Digits
    private func normalizeDigits(_ text: String) -> String {
        var result = text
        let arabicIndicDigits = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"]
        for (index, digit) in arabicIndicDigits.enumerated() {
            result = result.replacingOccurrences(of: digit, with: String(index))
        }
        return result
    }
}

// MARK: - Parsed Transaction Data
struct ParsedTransactionData {
    var transactionType: TransactionType?
    var date: Date?
    var symbol: String?
    var quantity: Decimal?
    var price: Decimal?
    var amount: Decimal?
    var fees: Decimal?
    var currency: Currency?
    var notes: String?
    var rawText: String?
    var confidence: Double = 0.0

    var isComplete: Bool {
        return transactionType != nil && amount != nil
    }
}

// MARK: - OCR Error
enum OCRError: LocalizedError {
    case invalidImage
    case noTextFound
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "صورة غير صالحة"
        case .noTextFound: return "لم يتم العثور على نص في الصورة"
        case .parseError(let msg): return "خطأ في تحليل البيانات: \(msg)"
        }
    }
}
