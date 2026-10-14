import SwiftUI

struct ContentView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.35, blue: 0.18),
                         Color(red: 0.02, green: 0.15, blue: 0.30)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.white)

                VStack(spacing: 8) {
                    Text("Pipeline Demo")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    Text("Built headlessly in the cloud.\nNo human opened Xcode.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.85))
                }

                VStack(alignment: .leading, spacing: 10) {
                    InfoRow(label: "Version", value: appVersion)
                    InfoRow(label: "Build", value: buildNumber)
                    InfoRow(label: "iOS", value: UIDevice.current.systemVersion)
                    InfoRow(label: "Device", value: UIDevice.current.model)
                    InfoRow(label: "Compiled by", value: "GitHub Actions (macOS runner)")
                    InfoRow(label: "Delivered by", value: "Fastlane")
                }
                .padding(20)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
            }
            .padding()
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    ContentView()
}
