//
//  StatusView.swift
//  NetBird
//

import SwiftUI
import NetworkExtension

#if os(iOS)

// MARK: - Internet Connection Status
struct InternetStatusView: View {
    @EnvironmentObject var viewModel: ViewModel

    private var isInternetConnected: Bool {
        viewModel.isInternetConnected
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isInternetConnected ? Color.green : Color.red)
                .frame(width: 10, height: 10)

            Text(isInternetConnected ? "Connected" : "Disconnected")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color("TextSecondary"))

            Spacer()
        }
    }
}

// MARK: - VPN Connection Toggle
struct VPNConnectionView: View {
    @EnvironmentObject var viewModel: ViewModel

    private var isVPNEnabled: Bool {
        viewModel.extensionState == .connected || viewModel.extensionState == .connecting
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Exit node")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color("TextSecondary"))
                let text = viewModel.fqdn.replacingOccurrences(of: ".netbird.cloud", with: "")
                Text(text)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color(.label))
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isVPNEnabled },
                set: { newValue in
                    guard !viewModel.buttonLock else { return }
                    if newValue {
                        viewModel.connect()
                    } else {
                        viewModel.close()
                    }
                }
            ))
            .labelsHidden()
            .disabled(viewModel.buttonLock)
        }
        .padding()
        .background(Color("BgNavigationBar"))
        .cornerRadius(12)
    }
}

#endif
