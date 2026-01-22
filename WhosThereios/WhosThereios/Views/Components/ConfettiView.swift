//
//  ConfettiView.swift
//  WhosThereios
//
//  Created by Claude on 1/18/26.
//

import SwiftUI

struct ConfettiPiece: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let color: Color
    let rotation: Double
    let scale: CGFloat
    let shape: ConfettiShape

    enum ConfettiShape: CaseIterable {
        case circle, square, triangle, star
    }
}

struct ConfettiView: View {
    @Binding var isActive: Bool
    let duration: Double

    @State private var pieces: [ConfettiPiece] = []
    @State private var animationProgress: CGFloat = 0

    private let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
    private let pieceCount = 50

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(pieces) { piece in
                    ConfettiPieceView(piece: piece)
                        .offset(
                            x: piece.x + CGFloat(sin(Double(animationProgress) * .pi * 2 + piece.rotation)) * 30,
                            y: piece.y + animationProgress * geometry.size.height * 1.5
                        )
                        .rotationEffect(.degrees(piece.rotation + Double(animationProgress) * 360 * (piece.rotation > 180 ? 1 : -1)))
                        .opacity(Double(1 - animationProgress * 0.8))
                        .scaleEffect(piece.scale * (1 - animationProgress * 0.5))
                }
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    startConfetti(in: geometry.size)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func startConfetti(in size: CGSize) {
        // Generate confetti pieces
        pieces = (0..<pieceCount).map { _ in
            ConfettiPiece(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: -100...(-50)),
                color: colors.randomElement()!,
                rotation: Double.random(in: 0...360),
                scale: CGFloat.random(in: 0.5...1.0),
                shape: ConfettiPiece.ConfettiShape.allCases.randomElement()!
            )
        }

        // Reset and animate
        animationProgress = 0
        withAnimation(.easeOut(duration: duration)) {
            animationProgress = 1
        }

        // Clean up after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            isActive = false
            pieces = []
        }
    }
}

struct ConfettiPieceView: View {
    let piece: ConfettiPiece

    var body: some View {
        Group {
            switch piece.shape {
            case .circle:
                Circle()
                    .fill(piece.color)
                    .frame(width: 10, height: 10)
            case .square:
                Rectangle()
                    .fill(piece.color)
                    .frame(width: 8, height: 8)
            case .triangle:
                Triangle()
                    .fill(piece.color)
                    .frame(width: 10, height: 10)
            case .star:
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundColor(piece.color)
            }
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Confetti Modifier

struct ConfettiModifier: ViewModifier {
    @Binding var isActive: Bool
    var duration: Double = 2.0

    func body(content: Content) -> some View {
        ZStack {
            content
            ConfettiView(isActive: $isActive, duration: duration)
        }
    }
}

extension View {
    func confetti(isActive: Binding<Bool>, duration: Double = 2.0) -> some View {
        modifier(ConfettiModifier(isActive: isActive, duration: duration))
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var showConfetti = false

        var body: some View {
            VStack {
                Button("Celebrate!") {
                    showConfetti = true
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .confetti(isActive: $showConfetti)
        }
    }

    return PreviewWrapper()
}
