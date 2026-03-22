import SwiftUI
import PhotosUI

struct AddTransactionView: View {
    @Binding var isPresented: Bool
    var onSave: () -> Void

    @State private var selectedMethod: InputMethod = .manual
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isProcessingOCR = false
    @State private var parsedData: ParsedTransactionData?
    @State private var showReviewSheet = false

    // Form fields
    @State private var transactionType: TransactionType = .buy
    @State private var date = Date()
    @State private var symbol = ""
    @State private var assetName = ""
    @State private var quantity = ""
    @State private var price = ""
    @State private var fees = ""
    @State private var taxes = ""
    @State private var notes = ""
    @State private var currency: Currency = .sar

    enum InputMethod: String, CaseIterable {
        case manual = "يدوي"
        case image = "صورة"
        case excel = "Excel"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Input method selector
                    Picker("طريقة الإدخال", selection: $selectedMethod) {
                        ForEach(InputMethod.allCases, id: \.self) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)

                    switch selectedMethod {
                    case .manual:
                        ManualTransactionForm(
                            transactionType: $transactionType,
                            date: $date,
                            symbol: $symbol,
                            assetName: $assetName,
                            quantity: $quantity,
                            price: $price,
                            fees: $fees,
                            taxes: $taxes,
                            notes: $notes,
                            currency: $currency
                        )

                    case .image:
                        ImageInputView(
                            selectedImage: $selectedImage,
                            isProcessing: $isProcessingOCR,
                            onImageSelected: processImage
                        )

                    case .excel:
                        ExcelImportView(onImport: { url in
                            importFromExcel(url: url)
                        })
                    }
                }
                .padding(.vertical)
            }
            .background(Color.appDarkBlue.ignoresSafeArea())
            .navigationTitle("إضافة عملية")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إلغاء") { isPresented = false }
                        .foregroundColor(.appGold)
                }

                if selectedMethod == .manual {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("حفظ") {
                            saveTransaction()
                        }
                        .foregroundColor(.appGold)
                        .bold()
                    }
                }
            }
            .sheet(isPresented: $showReviewSheet) {
                if let parsed = parsedData {
                    OCRReviewView(parsedData: parsed, isPresented: $showReviewSheet) { confirmed in
                        saveConfirmedTransaction(confirmed)
                    }
                }
            }
        }
    }

    private func processImage(_ image: UIImage) {
        isProcessingOCR = true
        Task {
            do {
                let text = try await OCRService.shared.extractText(from: image)
                let parsed = OCRService.shared.parseTransaction(from: text)
                var withRaw = parsed
                withRaw.rawText = text

                await MainActor.run {
                    self.parsedData = withRaw
                    self.isProcessingOCR = false
                    self.showReviewSheet = true
                }
            } catch {
                await MainActor.run {
                    self.isProcessingOCR = false
                }
            }
        }
    }

    private func saveTransaction() {
        let db = DatabaseManager.shared
        let priceService = PriceService.shared
        let usdSarRate = priceService.getUSDSARRate()

        guard let qty = Decimal(string: quantity),
              let prc = Decimal(string: price) else { return }

        let feesVal = Decimal(string: fees) ?? 0
        let taxesVal = Decimal(string: taxes) ?? 0
        let amount = qty * prc
        let amountSAR = currency == .usd ? amount * usdSarRate : amount

        let now = ISO8601DateFormatter().string(from: Date())
        let dateStr = ISO8601DateFormatter().string(from: date)
        let txnId = UUID().uuidString

        // Find or create asset
        var assetId = ""
        let existingAsset = db.query("SELECT id FROM assets WHERE symbol = ?", params: [symbol.uppercased()])
        if let existing = existingAsset.first, let id = existing["id"] as? String {
            assetId = id
        } else if !symbol.isEmpty {
            assetId = UUID().uuidString
            db.execute("""
                INSERT INTO assets (id, symbol, name, type, currency, current_price, is_active, created_at)
                VALUES ('\(assetId)', '\(symbol.uppercased())', '\(assetName.isEmpty ? symbol : assetName)',
                '\(AssetType.saStock.rawValue)', '\(currency.rawValue)', \(prc), 1, '\(now)');
            """)
        }

        // Insert transaction
        db.execute("""
            INSERT INTO transactions (id, type, date, asset_id, asset_symbol, quantity, price, amount,
            currency, exchange_rate, amount_sar, fees, taxes, notes, status, created_at, updated_at)
            VALUES ('\(txnId)', '\(transactionType.rawValue)', '\(dateStr)',
            \(assetId.isEmpty ? "NULL" : "'\(assetId)'"),
            \(symbol.isEmpty ? "NULL" : "'\(symbol.uppercased())'"),
            \(qty), \(prc), \(amount), '\(currency.rawValue)',
            \(usdSarRate), \(amountSAR), \(feesVal), \(taxesVal),
            \(notes.isEmpty ? "NULL" : "'\(notes)'"),
            'CONFIRMED', '\(now)', '\(now)');
        """)

        // If BUY, create holding
        if transactionType == .buy && !assetId.isEmpty {
            let holdingId = UUID().uuidString
            db.execute("""
                INSERT INTO holdings (id, asset_id, purchase_date, shares_original, shares_remaining,
                purchase_price, purchase_currency, fees, taxes)
                VALUES ('\(holdingId)', '\(assetId)', '\(dateStr)', \(qty), \(qty),
                \(prc), '\(currency.rawValue)', \(feesVal), \(taxesVal));
            """)
        }

        onSave()
        isPresented = false
    }

    private func saveConfirmedTransaction(_ data: ParsedTransactionData) {
        if let type = data.transactionType { transactionType = type }
        if let date = data.date { self.date = date }
        if let sym = data.symbol { symbol = sym }
        if let qty = data.quantity { quantity = "\(qty)" }
        if let prc = data.price { price = "\(prc)" }
        if let fee = data.fees { fees = "\(fee)" }
        selectedMethod = .manual
        showReviewSheet = false
    }

    private func importFromExcel(url: URL) {
        // Excel import logic
    }
}

// MARK: - Manual Form
struct ManualTransactionForm: View {
    @Binding var transactionType: TransactionType
    @Binding var date: Date
    @Binding var symbol: String
    @Binding var assetName: String
    @Binding var quantity: String
    @Binding var price: String
    @Binding var fees: String
    @Binding var taxes: String
    @Binding var notes: String
    @Binding var currency: Currency

    var body: some View {
        VStack(spacing: 16) {
            // Transaction Type
            VStack(alignment: .leading, spacing: 8) {
                Text("نوع العملية")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(TransactionType.allCases, id: \.self) { type in
                            Button {
                                transactionType = type
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: type.icon)
                                    Text(type.displayName)
                                }
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(transactionType == type ? Color.appGold : Color.white.opacity(0.1))
                                .foregroundColor(transactionType == type ? .appDarkBlue : .white)
                                .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // Form Fields
            VStack(spacing: 12) {
                if [.buy, .sell, .dividend].contains(transactionType) {
                    FormField(label: "رمز السهم", placeholder: "مثال: 2222 أو AAPL", text: $symbol)
                        .textInputAutocapitalization(.characters)
                    FormField(label: "اسم الأصل", placeholder: "اسم الشركة", text: $assetName)
                }

                DatePicker("التاريخ", selection: $date, displayedComponents: .date)
                    .padding()
                    .background(Color.appCardBg)
                    .cornerRadius(12)
                    .foregroundColor(.white)
                    .padding(.horizontal)

                Picker("العملة", selection: $currency) {
                    ForEach(Currency.allCases, id: \.self) { c in
                        Text(c.displayName).tag(c)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)

                if [.buy, .sell].contains(transactionType) {
                    FormField(label: "الكمية", placeholder: "عدد الوحدات", text: $quantity)
                        .keyboardType(.decimalPad)
                    FormField(label: "السعر", placeholder: "سعر الوحدة", text: $price)
                        .keyboardType(.decimalPad)
                }

                if [.deposit, .withdraw, .dividend, .fee, .tax].contains(transactionType) {
                    FormField(label: "المبلغ", placeholder: "المبلغ الكلي", text: $price)
                        .keyboardType(.decimalPad)
                }

                FormField(label: "الرسوم", placeholder: "0.00", text: $fees)
                    .keyboardType(.decimalPad)
                FormField(label: "الضريبة", placeholder: "0.00", text: $taxes)
                    .keyboardType(.decimalPad)

                // Notes
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                        .padding(8)
                        .background(Color.appCardBg)
                        .cornerRadius(12)
                        .foregroundColor(.white)
                    if notes.isEmpty {
                        Text("ملاحظات (اختياري)")
                            .foregroundColor(.white.opacity(0.3))
                            .padding(14)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Form Field
struct FormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            TextField(placeholder, text: $text)
                .padding()
                .background(Color.appCardBg)
                .cornerRadius(12)
                .foregroundColor(.white)
                .tint(.appGold)
        }
        .padding(.horizontal)
    }
}

// MARK: - Image Input View
struct ImageInputView: View {
    @Binding var selectedImage: UIImage?
    @Binding var isProcessing: Bool
    let onImageSelected: (UIImage) -> Void

    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var photoPickerItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 20) {
            if isProcessing {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.appGold)
                    Text("جاري معالجة الصورة...")
                        .foregroundColor(.white)
                }
                .padding(40)
            } else if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(12)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 60))
                        .foregroundColor(.appGold.opacity(0.7))

                    Text("ارفع صورة إيصال أو رسالة بنكية")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(40)
            }

            HStack(spacing: 16) {
                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    Label("اختر من المكتبة", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appCardBg)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button {
                    showCamera = true
                } label: {
                    Label("الكاميرا", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appGold)
                        .foregroundColor(.appDarkBlue)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)
        }
        .onChange(of: photoPickerItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                    onImageSelected(image)
                }
            }
        }
    }
}

// MARK: - OCR Review View
struct OCRReviewView: View {
    let parsedData: ParsedTransactionData
    @Binding var isPresented: Bool
    let onConfirm: (ParsedTransactionData) -> Void

    @State private var editedData: ParsedTransactionData

    init(parsedData: ParsedTransactionData, isPresented: Binding<Bool>, onConfirm: @escaping (ParsedTransactionData) -> Void) {
        self.parsedData = parsedData
        self._isPresented = isPresented
        self.onConfirm = onConfirm
        self._editedData = State(initialValue: parsedData)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Raw text preview
                    if let rawText = parsedData.rawText {
                        VStack(alignment: .leading) {
                            Text("النص المستخرج")
                                .font(.caption.bold())
                                .foregroundColor(.appGold)
                            ScrollView {
                                Text(rawText)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(height: 100)
                        }
                        .padding()
                        .background(Color.appCardBg)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    Text("مراجعة البيانات المستخرجة")
                        .font(.headline)
                        .foregroundColor(.white)

                    VStack(spacing: 12) {
                        ReviewField(label: "نوع العملية",
                                   value: editedData.transactionType?.displayName ?? "غير محدد")
                        ReviewField(label: "المبلغ",
                                   value: editedData.amount.map { "\($0)" } ?? "غير محدد")
                        ReviewField(label: "الكمية",
                                   value: editedData.quantity.map { "\($0)" } ?? "غير محدد")
                        ReviewField(label: "الرمز",
                                   value: editedData.symbol ?? "غير محدد")
                        ReviewField(label: "الرسوم",
                                   value: editedData.fees.map { "\($0)" } ?? "0")
                    }

                    HStack(spacing: 16) {
                        Button {
                            isPresented = false
                        } label: {
                            Text("إعادة المحاولة")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.appCardBg)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }

                        Button {
                            onConfirm(editedData)
                        } label: {
                            Text("تأكيد وحفظ")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.appGold)
                                .foregroundColor(.appDarkBlue)
                                .cornerRadius(12)
                                .bold()
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color.appDarkBlue.ignoresSafeArea())
            .navigationTitle("مراجعة OCR")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ReviewField: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.appCardBg)
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

// MARK: - Excel Import View
struct ExcelImportView: View {
    let onImport: (URL) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "tablecells")
                .font(.system(size: 60))
                .foregroundColor(.appGold.opacity(0.7))

            Text("استيراد من Excel")
                .font(.headline)
                .foregroundColor(.white)

            Text("قم بتنزيل القالب، أدخل بياناتك، ثم ارفع الملف")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            Button {
                downloadTemplate()
            } label: {
                Label("تنزيل القالب", systemImage: "arrow.down.circle")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.appCardBg)
                    .foregroundColor(.appGold)
                    .cornerRadius(12)
            }

            Button {} label: {
                Label("رفع ملف Excel", systemImage: "arrow.up.doc")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.appGold)
                    .foregroundColor(.appDarkBlue)
                    .cornerRadius(12)
                    .bold()
            }
        }
        .padding(40)
    }

    private func downloadTemplate() {
        let csv = "النوع,التاريخ,الرمز,الكمية,السعر,العملة,الرسوم,الضريبة,ملاحظات\nBUY,2024-01-01,2222,100,35.5,SAR,0,0,\n"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("investment_template.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
    }
}
