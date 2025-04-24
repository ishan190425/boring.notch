//
//  LockUnlockAnimation.swift
//  boringNotch
//
//  Created on 4/23/2025.
//

import SwiftUI

struct LockShape: Shape {
    var progress: Double // 0 = locked, 1 = unlocked
    
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Draw the lock body
        let lockBodyRect = CGRect(
            x: rect.width * 0.25,
            y: rect.height * (0.4 + progress * 0.1), // Move down slightly as it unlocks
            width: rect.width * 0.5,
            height: rect.height * 0.5
        )
        path.addRoundedRect(in: lockBodyRect, cornerSize: CGSize(width: 10, height: 10))
        
        // Draw the lock shackle (the top part)
        let shackleWidth = rect.width * 0.3
        let shackleHeight = rect.height * 0.3
        let shackleX = rect.width * 0.35
        let shackleY = rect.height * (0.2 - progress * 0.15) // Move up as it unlocks
        
        // Left vertical line of shackle
        path.move(to: CGPoint(x: shackleX, y: lockBodyRect.minY))
        path.addLine(to: CGPoint(x: shackleX, y: shackleY + shackleHeight * progress))
        
        // Top horizontal line of shackle
        path.addLine(to: CGPoint(x: shackleX + shackleWidth, y: shackleY + shackleHeight * progress))
        
        // Right vertical line of shackle
        path.addLine(to: CGPoint(x: shackleX + shackleWidth, y: lockBodyRect.minY))
        
        return path
    }
}

struct LockUnlockAnimation: View {
    @State private var progress: Double = 0.0
    @State private var glowOpacity: Double = 0.0
    @State private var rotation: Double = 0.0
    
    var body: some View {
        ZStack {
            // Glow effect
            LockShape(progress: progress)
                .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .foregroundStyle(.white)
                .blur(radius: 6)
                .opacity(glowOpacity)
            
            // Main lock shape
            LockShape(progress: progress)
                .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(rotation))
        }
        .onAppear {
            // First make the lock glow
            withAnimation(.easeIn(duration: 0.3)) {
                glowOpacity = 1.0
            }
            
            // Then animate the unlock
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    progress = 1.0
                }
                
                // Add a slight rotation for more dynamic effect
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.1)) {
                    rotation = 5
                }
                
                // Fade out the animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        glowOpacity = 0.0
                    }
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black
        LockUnlockAnimation()
    }
}