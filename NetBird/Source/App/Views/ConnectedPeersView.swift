//
//  ConnectedPeersView.swift
//  NetBird
//

import SwiftUI

#if os(iOS)

// MARK: - UIKit-backed search field (iOS 14+)
struct SearchField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.placeholder = placeholder
        field.font = .systemFont(ofSize: 15)
        field.returnKeyType = .search
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        @objc func textChanged(_ sender: UITextField) {
            text = sender.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}

struct ConnectedPeersView: View {
    @EnvironmentObject var viewModel: ViewModel
    @State private var searchText = ""

    private var peers: [PeerInfo] {
        let allPeers = viewModel.peerViewModel.peerInfo
        if searchText.isEmpty {
            return allPeers
        }
        return allPeers.filter {
            $0.fqdn.localizedCaseInsensitiveContains(searchText) ||
            $0.ip.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func statusColor(for status: String) -> Color {
        switch status {
        case "Connected": return .green
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                SearchField(text: $searchText, placeholder: "Search machines")
                    .frame(height: 50)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Peers list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(peers.enumerated()), id: \.element.id) { index, peer in
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(statusColor(for: peer.connStatus))
                                        .frame(width: 10, height: 10)
                                    Text(peer.fqdn)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(Color(.label))
                                        .lineLimit(1)
                                }
                                Text(peer.ip)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(Color("TextSecondary"))
                            }
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)

                        if index < peers.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
            }
        }
        .background(Color("BgNavigationBar"))
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

#endif
