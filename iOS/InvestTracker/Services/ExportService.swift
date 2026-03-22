import Foundation
import UIKit

// MARK: - Export Service
class ExportService {
    static let shared = ExportService()

    private init() {}

    // MARK: - Generate PDF Report
    func generatePortfolioReport(summary: PortfolioSummary, transactions: [Transaction]) -> URL? {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        let title = "تقرير المحفظة الاستثمارية"
        let date = DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .short)

        let pdfURL = getTempURL(filename: "portfolio_report_\(Date().timeIntervalSince1970).pdf")

        do {
            try renderer.writePDF(to: pdfURL) { context in
                context.beginPage()
                let pageRect = context.pdfContextBounds

                // Background
                UIColor(red: 0.05, green: 0.1, blue: 0.2, alpha: 1).setFill()
                UIRectFill(CGRect(x: 0, y: 0, width: pageRect.width, height: 80))

                // Title
                let titleAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 20),
                    .foregroundColor: UIColor.white
                ]
                let titleStr = NSAttributedString(string: title, attributes: titleAttrs)
                titleStr.draw(at: CGPoint(x: 20, y: 25))

                // Date
                let dateAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12),
                    .foregroundColor: UIColor.lightGray
                ]
                let dateStr = NSAttributedString(string: date, attributes: dateAttrs)
                dateStr.draw(at: CGPoint(x: 20, y: 55))

                var yPos: CGFloat = 100

                // Summary Section
                yPos = drawSection(title: "ملخص المحفظة", context: context, yPos: yPos)
                yPos = drawRow(label: "إجمالي القيمة الحالية", value: formatSAR(summary.totalCurrentValue), yPos: yPos)
                yPos = drawRow(label: "إجمالي الإيداعات", value: formatSAR(summary.totalDeposits), yPos: yPos)
                yPos = drawRow(label: "إجمالي السحوبات", value: formatSAR(summary.totalWithdrawals), yPos: yPos)
                yPos = drawRow(label: "الربح المحقق", value: formatSAR(summary.realizedPnL), yPos: yPos, color: summary.realizedPnL >= 0 ? .systemGreen : .systemRed)
                yPos = drawRow(label: "الربح غير المحقق", value: formatSAR(summary.unrealizedPnL), yPos: yPos, color: summary.unrealizedPnL >= 0 ? .systemGreen : .systemRed)
                yPos = drawRow(label: "العائد الإجمالي %", value: "\(summary.returnPercentage.formatted())%", yPos: yPos)

                yPos += 20
                yPos = drawSection(title: "آخر العمليات", context: context, yPos: yPos)

                let recentTxns = transactions.prefix(15)
                for txn in recentTxns {
                    if yPos > 780 {
                        context.beginPage()
                        yPos = 40
                    }
                    let dateStr = DateFormatter.localizedString(from: txn.date, dateStyle: .short, timeStyle: .none)
                    let label = "\(txn.type.displayName) - \(txn.assetSymbol ?? "")"
                    let value = formatSAR(txn.amountSAR)
                    yPos = drawRow(label: "\(dateStr) | \(label)", value: value, yPos: yPos)
                }

                // Footer
                drawFooter(context: context, pageRect: pageRect)
            }
            return pdfURL
        } catch {
            print("PDF generation error: \(error)")
            return nil
        }
    }

    // MARK: - Generate Zakat Report PDF
    func generateZakatReport(calculations: [ZakatCalculation]) -> URL? {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        let pdfURL = getTempURL(filename: "zakat_report_\(Date().timeIntervalSince1970).pdf")

        do {
            try renderer.writePDF(to: pdfURL) { context in
                context.beginPage()
                let pageRect = context.pdfContextBounds

                // Header
                UIColor(red: 0.1, green: 0.4, blue: 0.2, alpha: 1).setFill()
                UIRectFill(CGRect(x: 0, y: 0, width: pageRect.width, height: 80))

                let titleAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 22),
                    .foregroundColor: UIColor.white
                ]
                NSAttributedString(string: "تقرير الزكاة", attributes: titleAttrs).draw(at: CGPoint(x: 20, y: 28))

                var yPos: CGFloat = 100

                for calc in calculations {
                    if yPos > 720 {
                        context.beginPage()
                        yPos = 40
                    }

                    let dateStr = DateFormatter.localizedString(from: calc.calculationDate, dateStyle: .long, timeStyle: .none)
                    yPos = drawSection(title: "حساب زكاة - \(dateStr)", context: context, yPos: yPos)
                    yPos = drawRow(label: "وعاء الزكاة", value: formatSAR(calc.totalZakatBase), yPos: yPos)
                    yPos = drawRow(label: "النصاب", value: formatSAR(calc.nisabAmountSAR), yPos: yPos)
                    yPos = drawRow(label: "الزكاة المستحقة (2.5%)", value: formatSAR(calc.zakatDue), yPos: yPos, color: .systemGreen)
                    yPos = drawRow(label: "الحالة", value: calc.status.displayName, yPos: yPos)

                    if let breakdown = calc.memberBreakdown {
                        yPos += 10
                        yPos = drawSection(title: "توزيع أعضاء الصندوق", context: context, yPos: yPos)
                        for share in breakdown {
                            yPos = drawRow(label: "\(share.memberName) (\(share.units) وحدة)",
                                          value: formatSAR(share.zakatDue), yPos: yPos)
                        }
                    }
                    yPos += 20
                }

                drawFooter(context: context, pageRect: pageRect)
            }
            return pdfURL
        } catch {
            return nil
        }
    }

    // MARK: - Generate Excel/CSV
    func generateCSV(transactions: [Transaction], filename: String) -> URL {
        var csv = "التاريخ,النوع,الرمز,الكمية,السعر,المبلغ,العملة,المبلغ بالريال,الرسوم,ملاحظات\n"

        for txn in transactions {
            let date = DateFormatter.localizedString(from: txn.date, dateStyle: .short, timeStyle: .none)
            let row = [
                date,
                txn.type.displayName,
                txn.assetSymbol ?? "",
                "\(txn.quantity)",
                "\(txn.price)",
                "\(txn.amount)",
                txn.currency.rawValue,
                "\(txn.amountSAR)",
                "\(txn.fees)",
                txn.notes ?? ""
            ].joined(separator: ",")
            csv += row + "\n"
        }

        let url = getTempURL(filename: filename + ".csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Share via WhatsApp/Other
    func shareFile(url: URL, from viewController: UIViewController) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = viewController.view
        viewController.present(activityVC, animated: true)
    }

    // MARK: - Drawing Helpers
    private func drawSection(title: String, context: UIGraphicsPDFRendererContext, yPos: CGFloat) -> CGFloat {
        let rect = CGRect(x: 15, y: yPos, width: 565, height: 28)
        UIColor(red: 0.9, green: 0.9, blue: 0.95, alpha: 1).setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 4).fill()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 13),
            .foregroundColor: UIColor.darkGray
        ]
        NSAttributedString(string: title, attributes: attrs).draw(at: CGPoint(x: 20, y: yPos + 7))
        return yPos + 35
    }

    private func drawRow(label: String, value: String, yPos: CGFloat, color: UIColor = .darkText) -> CGFloat {
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.darkGray
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: color
        ]

        NSAttributedString(string: label, attributes: labelAttrs).draw(at: CGPoint(x: 20, y: yPos))
        NSAttributedString(string: value, attributes: valueAttrs).draw(at: CGPoint(x: 420, y: yPos))

        // Separator
        UIColor.lightGray.withAlphaComponent(0.3).setStroke()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 15, y: yPos + 18))
        path.addLine(to: CGPoint(x: 580, y: yPos + 18))
        path.lineWidth = 0.5
        path.stroke()

        return yPos + 22
    }

    private func drawFooter(context: UIGraphicsPDFRendererContext, pageRect: CGRect) {
        let footer = "تم الإنشاء بواسطة نظام تتبع الاستثمارات والزكاة | \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.lightGray
        ]
        NSAttributedString(string: footer, attributes: attrs).draw(at: CGPoint(x: 15, y: pageRect.height - 20))
    }

    // MARK: - Helpers
    private func formatSAR(_ amount: Decimal) -> String {
        let nsAmount = NSDecimalNumber(decimal: amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return (formatter.string(from: nsAmount) ?? "0.00") + " ر.س"
    }

    private func getTempURL(filename: String) -> URL {
        return FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }
}

extension Decimal {
    func formatted() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "0.00"
    }
}
