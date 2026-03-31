import SwiftUI
import PhotosUI

struct ReceiptScannerView: View {
    @Binding var parsedReceipt: ParsedReceipt?
    @Environment(\.dismiss) var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    private let service = ReceiptService()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0A0A0A").ignoresSafeArea()

                if isProcessing {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(Color(hex: "#F97316"))
                        Text("Reading receipt...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 20) {
                        Spacer()

                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 72))
                            .foregroundStyle(Color(hex: "#F97316"))

                        Text("Scan a Receipt")
                            .font(.title2).bold().foregroundStyle(.white)

                        Text("AI reads all items, prices, and tax automatically.\nTax is split proportionally per person.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Label("Choose Photo", systemImage: "photo")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(hex: "#F97316"))
                                .foregroundStyle(.black)
                                .fontWeight(.semibold)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 32)

                        if let error = errorMessage {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }

                        Spacer()
                    }
                }
            }
            .navigationTitle("Receipt Scanner")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color(hex: "#F97316"))
                }
            }
            .onChange(of: selectedItem) { _, item in
                guard let item else { return }
                Task {
                    isProcessing = true
                    defer { isProcessing = false }
                    do {
                        if let data = try await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            parsedReceipt = try await service.parseReceipt(image: image)
                            dismiss()
                        }
                    } catch {
                        errorMessage = "Couldn't read receipt. Try a clearer photo."
                    }
                }
            }
        }
    }
}
