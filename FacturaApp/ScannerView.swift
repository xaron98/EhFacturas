// ScannerView.swift
// FacturaApp — Escaner OCR de tickets usando VisionKit DataScanner

import SwiftUI
import VisionKit

struct ScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var textoEscaneado = ""

    let onTextoEscaneado: (String) -> Void

    var body: some View {
        NavigationStack {
            Group {
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                DataScannerRepresentable(textoReconocido: $textoEscaneado)
                    .ignoresSafeArea()
                    .overlay(alignment: .bottom) {
                        if !textoEscaneado.isEmpty {
                            VStack(spacing: 12) {
                                Text(textoEscaneado)
                                    .font(.caption)
                                    .padding(12)
                                    .background(.thinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                Button("Usar este texto") {
                                    onTextoEscaneado(textoEscaneado)
                                    dismiss()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding()
                        }
                    }
            } else {
                ContentUnavailableView {
                    Label("Escaner no disponible", systemImage: "camera")
                } description: {
                    Text("Este dispositivo no soporta escaneo de texto.")
                }
            }
            }
            .navigationTitle("Escanear")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}

struct DataScannerRepresentable: UIViewControllerRepresentable {
    @Binding var textoReconocido: String

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let parent: DataScannerRepresentable

        init(parent: DataScannerRepresentable) { self.parent = parent }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            if case .text(let text) = item {
                Task { @MainActor in
                    parent.textoReconocido = text.transcript
                }
            }
        }
    }
}
