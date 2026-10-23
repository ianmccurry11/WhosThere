//
//  NameInputView.swift
//  WhosThereios
//

import SwiftUI

struct NameInputView: View {
    @ObservedObject var authService: AuthService
    @ObservedObject private var firestoreService = FirestoreService.shared

    @State private var name = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.appNavy, Color.appBlue]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 70))
                    .foregroundColor(.white)
                    .accessibilityHidden(true)

                VStack(spacing: 12) {
                    Text("Choose a username")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)

                    Text("This will be your display name in the app")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                }

                TextField("", text: $name, prompt: Text("Enter a username").foregroundColor(.white.opacity(0.5)))
                    .font(.title2)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.white.opacity(0.15))
                    .cornerRadius(14)
                    .padding(.horizontal, 40)
                    .focused($isNameFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { Task { await submit() } }
                    .autocorrectionDisabled()

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Spacer()

                Button(action: { Task { await submit() } }) {
                    Group {
                        if isSubmitting {
                            ProgressView()
                                .tint(.appNavy)
                        } else {
                            Text("Continue")
                                .font(.headline)
                        }
                    }
                    .foregroundColor(.appNavy)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white)
                    .cornerRadius(14)
                }
                .padding(.horizontal, 32)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)

                Spacer()
                    .frame(height: 40)
            }
        }
        .onAppear {
            // Pre-fill with Apple-provided name if it's a real name (not a fallback)
            if let user = firestoreService.currentUser, !user.hasDefaultName {
                name = user.displayName
            }
            isNameFieldFocused = true
        }
    }

    private func submit() async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        let result = await firestoreService.updateDisplayName(trimmed)
        switch result {
        case .success:
            HapticManager.success()
            authService.isNewUser = false
        case .failure(let error):
            HapticManager.error()
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }
}

#Preview {
    NameInputView(authService: AuthService())
}
