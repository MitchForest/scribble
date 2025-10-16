import SwiftUI

struct DiceBearAvatar: View {
    let seed: String
    let size: CGFloat

    private var url: URL? {
        var components = URLComponents(string: "https://api.dicebear.com/7.x/adventurer/png")
        components?.queryItems = [
            URLQueryItem(name: "seed", value: seed),
            URLQueryItem(name: "backgroundColor", value: "ffefd5"),
            URLQueryItem(name: "radius", value: "50"),
            URLQueryItem(name: "size", value: "\(Int(size * 2))")
        ]
        return components?.url
    }

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeInOut)) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: size, height: size)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            case .failure:
                Circle()
                    .fill(Color(red: 0.98, green: 0.9, blue: 0.68))
                    .frame(width: size, height: size)
                    .overlay(
                        Text("😊")
                            .font(.system(size: size * 0.4))
                    )
            @unknown default:
                Circle()
                    .fill(Color(red: 0.98, green: 0.9, blue: 0.68))
                    .frame(width: size, height: size)
            }
        }
    }
}
