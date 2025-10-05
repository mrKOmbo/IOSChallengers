//
//  SearchBarView.swift
//  AcessNet
//
//  Barra de búsqueda refactorizada con soporte para focus y callbacks
//

import SwiftUI

// MARK: - Search Bar View

struct SearchBarView: View {
    @Binding var searchText: String
    @FocusState.Binding var isFocused: Bool

    let placeholder: String
    let onSubmit: () -> Void
    let onClear: () -> Void

    init(
        searchText: Binding<String>,
        isFocused: FocusState<Bool>.Binding,
        placeholder: String = "Where to?",
        onSubmit: @escaping () -> Void = {},
        onClear: @escaping () -> Void = {}
    ) {
        self._searchText = searchText
        self._isFocused = isFocused
        self.placeholder = placeholder
        self.onSubmit = onSubmit
        self.onClear = onClear
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Icono de búsqueda
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundColor(isFocused ? .blue : .gray)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)

                // Campo de texto
                TextField(placeholder, text: $searchText)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .focused($isFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        onSubmit()
                    }
                    .autocorrectionDisabled()

                // Botón de limpiar
                if !searchText.isEmpty {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            searchText = ""
                            onClear()
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 18))
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                // Botón de cancelar cuando está enfocado
                if isFocused {
                    Button("Cancel") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            searchText = ""
                            isFocused = false
                            onClear()
                        }
                    }
                    .font(.body)
                    .foregroundStyle(.blue)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .strokeBorder(
                                isFocused ? Color.blue.opacity(0.3) : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
            .shadow(color: .black.opacity(isFocused ? 0.2 : 0.15), radius: isFocused ? 20 : 15, x: 0, y: 5)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFocused)
    }
}

// MARK: - Compact Search Bar (para cuando hay poco espacio)

struct CompactSearchBar: View {
    @Binding var searchText: String
    @FocusState.Binding var isFocused: Bool

    let onTap: () -> Void

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                onTap()
                isFocused = true
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)

                Text(searchText.isEmpty ? "Search" : searchText)
                    .font(.system(size: 15))
                    .foregroundColor(searchText.isEmpty ? .secondary : .primary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 3)
        }
    }
}

// MARK: - Search Bar with Voice (futuro)

struct SearchBarWithVoice: View {
    @Binding var searchText: String
    @FocusState.Binding var isFocused: Bool

    let placeholder: String
    let onVoiceSearch: () -> Void
    let onSubmit: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icono de búsqueda
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18))
                .foregroundColor(isFocused ? .blue : .gray)

            // Campo de texto
            TextField(placeholder, text: $searchText)
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .focused($isFocused)
                .submitLabel(.search)
                .onSubmit(onSubmit)

            // Botón de limpiar o micrófono
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    onClear()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .transition(.scale)
            } else {
                Button(action: onVoiceSearch) {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.blue)
                }
                .transition(.scale)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 25))
        .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 5)
    }
}

// MARK: - Preview

#Preview("Standard Search Bar") {
    struct PreviewWrapper: View {
        @State private var searchText = ""
        @FocusState private var isFocused: Bool

        var body: some View {
            VStack(spacing: 20) {
                SearchBarView(
                    searchText: $searchText,
                    isFocused: $isFocused,
                    placeholder: "Where to?",
                    onSubmit: {
                        print("Submit: \(searchText)")
                    },
                    onClear: {
                        print("Cleared")
                    }
                )
                .padding()

                Text("Focused: \(isFocused ? "Yes" : "No")")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Toggle Focus") {
                    isFocused.toggle()
                }

                Spacer()
            }
        }
    }

    return PreviewWrapper()
}

#Preview("Compact Search Bar") {
    struct PreviewWrapper: View {
        @State private var searchText = ""
        @FocusState private var isFocused: Bool

        var body: some View {
            VStack {
                CompactSearchBar(
                    searchText: $searchText,
                    isFocused: $isFocused,
                    onTap: {
                        print("Tapped")
                    }
                )
                .padding()

                Spacer()
            }
        }
    }

    return PreviewWrapper()
}

#Preview("With Voice") {
    struct PreviewWrapper: View {
        @State private var searchText = "Starbucks"
        @FocusState private var isFocused: Bool

        var body: some View {
            VStack {
                SearchBarWithVoice(
                    searchText: $searchText,
                    isFocused: $isFocused,
                    placeholder: "Search places...",
                    onVoiceSearch: {
                        print("Voice search")
                    },
                    onSubmit: {
                        print("Submit: \(searchText)")
                    },
                    onClear: {
                        print("Cleared")
                    }
                )
                .padding()

                Spacer()
            }
        }
    }

    return PreviewWrapper()
}
