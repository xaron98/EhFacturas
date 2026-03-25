// FotosFacturaView.swift
import SwiftUI
import PhotosUI
import SwiftData

struct FotosFacturaView: View {
    let factura: Factura
    @Environment(\.modelContext) private var modelContext
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var images: [UIImage] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    // Existing photos
                    ForEach(images.indices, id: \.self) { index in
                        Image(uiImage: images[index])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Add photo button
                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 5, matching: .images) {
                        VStack {
                            Image(systemName: "plus.circle")
                                .font(.title)
                            Text("Añadir")
                                .font(.caption)
                        }
                        .frame(width: 100, height: 100)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()
            }
            .navigationTitle("Fotos del trabajo")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedPhotos) { _, items in
                Task {
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            // Resize to max 800px
                            let resized = resizeImage(image, maxDimension: 800)
                            if let jpegData = resized.jpegData(compressionQuality: 0.7) {
                                var fotos = factura.fotosData ?? []
                                fotos.append(jpegData)
                                factura.fotosData = fotos
                            }
                        }
                    }
                    try? modelContext.save()
                    loadImages()
                    selectedPhotos = []
                }
            }
            .onAppear { loadImages() }
        }
    }

    private func loadImages() {
        images = (factura.fotosData ?? []).compactMap { UIImage(data: $0) }
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
