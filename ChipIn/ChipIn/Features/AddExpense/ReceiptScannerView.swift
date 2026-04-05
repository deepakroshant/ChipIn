import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

struct ReceiptScannerView: View {
    @Binding var parsedReceipt: ParsedReceipt?
    @Environment(\.dismiss) var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showCamera = false
    @State private var cameraImage: UIImage?
    @State private var scanStage = ""
    @State private var lastImage: UIImage?
    private let service = ReceiptService()

    var body: some View {
        NavigationStack {
            ZStack {
                ChipInTheme.background.ignoresSafeArea()

                if isProcessing {
                    processingView
                } else {
                    idleScannerContent
                }
            }
            .navigationTitle("Receipt Scanner")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(ChipInTheme.accent)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker(image: $cameraImage)
                    .ignoresSafeArea()
            }
            .onChange(of: cameraImage) { _, img in
                guard let img else { return }
                Task {
                    await processImage(img)
                    await MainActor.run { cameraImage = nil }
                }
            }
            .onChange(of: selectedItem) { _, item in
                guard let item else { return }
                Task {
                    isProcessing = true
                    defer { isProcessing = false }
                    do {
                        guard let data = try await item.loadTransferable(type: Data.self) else {
                            errorMessage = "Couldn't load that photo."
                            selectedItem = nil
                            return
                        }
                        guard let image = UIImage(data: data) else {
                            errorMessage = "That format couldn't be opened as an image. Pick a JPEG, HEIC, or PNG from Photos."
                            selectedItem = nil
                            return
                        }
                        await processImage(image)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                    selectedItem = nil
                }
            }
        }
    }

    private var processingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(2)
                .tint(ChipInTheme.accent)
            Text(scanStage.isEmpty ? "Scanning…" : scanStage)
                .foregroundStyle(ChipInTheme.secondaryLabel)
                .animation(.default, value: scanStage)
            Text("Gemini AI is reading your receipt")
                .font(.caption)
                .foregroundStyle(ChipInTheme.tertiaryLabel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var idleScannerContent: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "camera.viewfinder")
                .font(.system(size: 72))
                .foregroundStyle(ChipInTheme.accent)

            Text("Scan a Receipt")
                .font(.title2).bold()
                .foregroundStyle(ChipInTheme.label)

            Text("Any photo you pick is converted to JPEG and sent for reading. For best results, use a real paper or email receipt—not a random snapshot.")
                .foregroundStyle(ChipInTheme.secondaryLabel)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            photoTipsCard

            simulatorCameraHint

            actionButtons

#if DEBUG
            debugTestReceiptButton
#endif

            if let error = errorMessage {
                VStack(spacing: 12) {
                    Text(error)
                        .foregroundStyle(ChipInTheme.danger)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    if lastImage != nil {
                        Button {
                            Task {
                                guard let img = lastImage else { return }
                                errorMessage = nil
                                await processImage(img)
                            }
                        } label: {
                            Label("Try Again", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity).padding()
                                .background(ChipInTheme.card)
                                .foregroundStyle(ChipInTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal)
                    }
                    Button("Use Different Photo") { errorMessage = nil; lastImage = nil }
                        .font(.subheadline)
                        .foregroundStyle(ChipInTheme.secondaryLabel)
                }
            }

            Spacer()
        }
    }

    private var photoTipsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Photo tips")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ChipInTheme.label)
            tipRow("Bright, even light—avoid heavy shadow on the text.")
            tipRow("Hold the phone level; keep the whole receipt in frame.")
            tipRow("Lay the receipt flat; tap to focus if text looks soft.")
            tipRow("Portrait or landscape is fine; we fix orientation automatically.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(ChipInTheme.card.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }

    /// Avoid naming this `Group { … }` — `Group` collides with `Models/Group` (Codable).
    @ViewBuilder
    private var simulatorCameraHint: some View {
        if !UIImagePickerController.isSourceTypeAvailable(.camera) {
            Text("Simulator has no camera. Use \u{201C}Choose from Library\u{201D} or run on a real iPhone to use Take Photo.")
                .font(.caption2)
                .foregroundStyle(ChipInTheme.tertiaryLabel)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
    }

#if DEBUG
    private var debugTestReceiptButton: some View {
        VStack(spacing: 8) {
            Text("Debug test receipts")
                .font(.caption2)
                .foregroundStyle(ChipInTheme.tertiaryLabel)
            HStack(spacing: 12) {
                Button {
                    Task { await processTestReceiptImage(style: .cafe) }
                } label: {
                    Text("☕ Café")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ChipInTheme.accent)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(ChipInTheme.card)
                        .clipShape(Capsule())
                }
                Button {
                    Task { await processTestReceiptImage(style: .restaurant) }
                } label: {
                    Text("🍽 Restaurant")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ChipInTheme.accent)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(ChipInTheme.card)
                        .clipShape(Capsule())
                }
                Button {
                    Task { await processTestReceiptImage(style: .grocery) }
                } label: {
                    Text("🛒 Grocery")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ChipInTheme.accent)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(ChipInTheme.card)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.top, 4)
    }
#endif

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    requestCameraAccessAndPresent()
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ChipInTheme.ctaGradient)
                        .foregroundStyle(ChipInTheme.onPrimary)
                        .fontWeight(.semibold)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label("Choose from Library", systemImage: "photo")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ChipInTheme.card)
                    .foregroundStyle(ChipInTheme.label)
                    .fontWeight(.semibold)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 32)
    }

    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(ChipInTheme.accent.opacity(0.9))
            Text(text)
                .font(.caption)
                .foregroundStyle(ChipInTheme.secondaryLabel)
        }
    }

    private func processImage(_ image: UIImage) async {
        lastImage = image
        errorMessage = nil
        isProcessing = true
        scanStage = "Preparing image…"
        defer {
            isProcessing = false
            scanStage = ""
        }
        do {
            scanStage = "Sending to AI…"
            let result = try await service.parseReceipt(image: image)
            scanStage = "Parsing items…"
            try? await Task.sleep(for: .milliseconds(300))
            parsedReceipt = result
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func requestCameraAccessAndPresent() {
        errorMessage = nil
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showCamera = true
                    } else {
                        errorMessage = "Camera access was denied. You can still choose a photo from your library."
                    }
                }
            }
        case .denied, .restricted:
            errorMessage = "Camera is off for ChipIn. Turn it on in Settings → Privacy & Security → Camera → ChipIn."
        @unknown default:
            showCamera = true
        }
    }

#if DEBUG
    enum TestReceiptStyle { case cafe, restaurant, grocery }

    @MainActor
    private func processTestReceiptImage(style: TestReceiptStyle = .cafe) async {
        let height: CGFloat = style == .grocery ? 600 : 480
        let content: AnyView
        switch style {
        case .cafe:
            content = AnyView(ReceiptSyntheticTestView())
        case .restaurant:
            content = AnyView(RestaurantReceiptTestView())
        case .grocery:
            content = AnyView(GroceryReceiptTestView())
        }
        let sized = content.frame(width: 340, height: height).background(Color.white)
        let renderer = ImageRenderer(content: sized)
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: 340, height: height)
        guard let uiImage = renderer.uiImage else {
            errorMessage = "Debug: couldn't render test receipt image."
            return
        }
        await processImage(uiImage.chipInOpaqueOnWhite())
    }
#endif
}

#if DEBUG
/// Café receipt — simple 2-item receipt used as the baseline test.
private struct ReceiptSyntheticTestView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CHIPIN TEST MART")
                .font(.title2.bold())
            Text("123 Demo Street")
                .font(.caption)
            Divider()
            HStack {
                Text("Coffee"); Spacer(); Text("$4.50")
            }
            .font(.body)
            HStack {
                Text("Sandwich"); Spacer(); Text("$8.25")
            }
            .font(.body)
            Divider()
            HStack {
                Text("Subtotal"); Spacer(); Text("$12.75")
            }
            .font(.body)
            HStack {
                Text("Tax"); Spacer(); Text("$0.64")
            }
            .font(.caption)
            HStack {
                Text("TOTAL"); Spacer(); Text("$13.39")
            }
            .font(.headline)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(.black)
        .background(Color.white)
    }
}

/// Restaurant receipt — multiple items, tip, quantity line.
private struct RestaurantReceiptTestView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THE GOLDEN FORK").font(.title2.bold())
            Text("45 King St W, Toronto ON").font(.caption)
            Text("Table 12  Server: Alex  Guests: 4").font(.caption)
            Divider()
            HStack { Text("2x Pasta Carbonara"); Spacer(); Text("$34.00") }.font(.body)
            HStack { Text("Margherita Pizza"); Spacer(); Text("$19.50") }.font(.body)
            HStack { Text("Caesar Salad"); Spacer(); Text("$12.00") }.font(.body)
            HStack { Text("1x Sparkling Water"); Spacer(); Text("$4.00") }.font(.body)
            HStack { Text("House Red Wine"); Spacer(); Text("$28.00") }.font(.body)
            HStack { Text("Tiramisu"); Spacer(); Text("$9.75") }.font(.body)
            Divider()
            HStack { Text("Subtotal"); Spacer(); Text("$107.25") }.font(.body)
            HStack { Text("HST (13%)"); Spacer(); Text("$13.94") }.font(.caption)
            HStack { Text("Tip (18%)"); Spacer(); Text("$19.31") }.font(.caption)
            Divider()
            HStack { Text("TOTAL"); Spacer(); Text("$140.50") }.font(.headline)
            Text("Thank you for dining with us!").font(.caption2).frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(.black)
        .background(Color.white)
    }
}

/// Grocery receipt — many items, quantity × price format, no tip.
private struct GroceryReceiptTestView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("FRESHMART GROCERY").font(.title2.bold())
            Text("290 Bloor St, Toronto ON").font(.caption)
            Text("Cashier: 04  Receipt #88412").font(.caption)
            Divider()
            HStack { Text("Whole Milk 2L"); Spacer(); Text("$4.29") }.font(.body)
            HStack { Text("2x Greek Yogurt"); Spacer(); Text("$7.98") }.font(.body)
            HStack { Text("Sourdough Bread"); Spacer(); Text("$5.49") }.font(.body)
            HStack { Text("3x Banana"); Spacer(); Text("$1.47") }.font(.body)
            HStack { Text("Chicken Breast 1.2kg"); Spacer(); Text("$13.68") }.font(.body)
            HStack { Text("Pasta 500g"); Spacer(); Text("$2.99") }.font(.body)
            HStack { Text("Tomato Sauce"); Spacer(); Text("$3.49") }.font(.body)
            HStack { Text("Cheddar Cheese"); Spacer(); Text("$6.79") }.font(.body)
            HStack { Text("Orange Juice 1L"); Spacer(); Text("$4.99") }.font(.body)
            HStack { Text("2x Sparkling Water"); Spacer(); Text("$3.98") }.font(.body)
            Divider()
            HStack { Text("Subtotal"); Spacer(); Text("$55.15") }.font(.body)
            HStack { Text("Tax"); Spacer(); Text("$0.00") }.font(.caption)
            Divider()
            HStack { Text("TOTAL"); Spacer(); Text("$55.15") }.font(.headline)
            Text("Points earned: 55").font(.caption2).frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(.black)
        .background(Color.white)
    }
}
#endif
