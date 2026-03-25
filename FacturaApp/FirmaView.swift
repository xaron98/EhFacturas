// FirmaView.swift
import SwiftUI
import SwiftData

struct FirmaView: View {
    let factura: Factura
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var lines: [[CGPoint]] = []
    @State private var currentLine: [CGPoint] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Firma del cliente")
                    .font(.headline)
                    .padding()

                // Canvas
                Canvas { context, size in
                    for line in lines + [currentLine] {
                        guard line.count > 1 else { continue }
                        var path = Path()
                        path.addLines(line)
                        context.stroke(path, with: .color(.primary), lineWidth: 2)
                    }
                }
                .frame(height: 200)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            currentLine.append(value.location)
                        }
                        .onEnded { _ in
                            lines.append(currentLine)
                            currentLine = []
                        }
                )
                .padding(.horizontal)

                // Buttons
                HStack(spacing: 20) {
                    Button("Borrar") {
                        lines = []
                        currentLine = []
                    }
                    .foregroundStyle(.red)

                    Spacer()

                    Button("Guardar firma") {
                        guardarFirma()
                    }
                    .fontWeight(.semibold)
                    .disabled(lines.isEmpty)
                }
                .padding()

                // Show existing signature if any
                if let firmaData = factura.firmaClienteData,
                   let img = UIImage(data: firmaData) {
                    VStack {
                        Text("Firma guardada")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 80)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding()
                }

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    private func guardarFirma() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 200))
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: CGSize(width: 400, height: 200)))

            let bezier = UIBezierPath()
            bezier.lineWidth = 2
            UIColor.black.setStroke()

            for line in lines {
                guard let first = line.first else { continue }
                bezier.move(to: first)
                for point in line.dropFirst() {
                    bezier.addLine(to: point)
                }
            }
            bezier.stroke()
        }

        factura.firmaClienteData = image.pngData()
        try? modelContext.save()
        dismiss()
    }
}
