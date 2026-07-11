import ActivityKit
import WidgetKit
import SwiftUI

let primaryGradient = LinearGradient(
    colors: [
        Color(red: 237/255, green: 57/255, blue: 115/255),
        Color(red: 249/255, green: 98/255, blue: 50/255)
    ],
    startPoint: .leading,
    endPoint: .trailing
)


let sharedDefault = UserDefaults(suiteName: "group.com.mytogetherorg.mytogether")!

func getString(context: ActivityViewContext<LiveActivitiesAppAttributes>, key: String) -> String? {
    return sharedDefault.string(forKey: context.attributes.prefixedKey(key))
}

struct OrderTrackerWidgetLiveActivity: Widget {
    
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            // Lock screen/banner UI goes here
            LiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        if let logoPath = getString(context: context, key: "shopLogoPath"), let uiImage = UIImage(contentsOfFile: logoPath) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 24, height: 24)
                                .clipShape(Circle())
                        } else {
                            Image("AppLogo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .clipShape(Circle())
                        }
                        
                        Text(getString(context: context, key: "statusText") ?? "Processing")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Spacer(minLength: 0)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            if let riderName = getString(context: context, key: "riderName"), !riderName.isEmpty {
                                Image(systemName: "person.crop.circle.fill")
                                    .foregroundColor(.gray)
                                    .font(.title2)
                                Text(riderName)
                                    .font(.system(size: 14, weight: .medium))
                            } else {
                                Image(systemName: "storefront.fill")
                                    .foregroundColor(.gray)
                                    .font(.title2)
                                Text(getString(context: context, key: "shopName") ?? "Restaurant")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        
                        let isPickup = (getString(context: context, key: "isPickup") ?? "0") == "1"
                        ProgressBarView(
                            progress: Int(getString(context: context, key: "progress") ?? "0") ?? 0,
                            isPickup: isPickup
                        )
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)
                    }
                }
            } compactLeading: {
                // Always show MyTogether AppLogo on the left
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .clipShape(Circle())
                    .padding(.leading, 2)
            } compactTrailing: {
                // Always show ETA on the right; fallback to progress ring
                if let eta = getString(context: context, key: "estimatedTime"), !eta.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(primaryGradient)
                        Text(eta)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(primaryGradient)
                            .lineLimit(1)
                    }
                    .padding(.trailing, 2)
                } else {
                    ProgressRingView(progress: Int(getString(context: context, key: "progress") ?? "0") ?? 0)
                        .padding(.trailing, 2)
                }
            } minimal: {
                // Minimal (two activities): show MyTogether AppLogo
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())
            }
        }
    }
}

struct LiveActivityView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        let shopName = getString(context: context, key: "shopName") ?? "Restaurant"
        let statusText = getString(context: context, key: "statusText") ?? "Processing"
        let progress = Int(getString(context: context, key: "progress") ?? "0") ?? 0
        let eta = getString(context: context, key: "estimatedTime") ?? ""
        let riderName = getString(context: context, key: "riderName") ?? ""
        
        VStack(spacing: 16) {
            // Header Row
            HStack(alignment: .center, spacing: 12) {
                // Logo
                Group {
                    if let logoPath = getString(context: context, key: "shopLogoPath"), let uiImage = UIImage(contentsOfFile: logoPath) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Image("AppLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusText)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .lineLimit(1)
                    
                    if !riderName.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            Text(riderName)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "storefront.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            Text(shopName)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer(minLength: 0)
                
                // ETA badge (right side)
                if !eta.isEmpty {
                    VStack(spacing: 2) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(primaryGradient)
                        Text(eta)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(primaryGradient)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 237/255, green: 57/255, blue: 115/255).opacity(0.1))
                    )
                }
            }
            
            // Progress Bar — real-time animated
            let isPickup = (getString(context: context, key: "isPickup") ?? "0") == "1"
            ProgressBarView(progress: progress, isPickup: isPickup)
        }
        .padding(16)
    }
}

// MARK: - Progress Bar (Step-based, animated)

struct ProgressBarView: View {
    let progress: Int
    let isPickup: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            StepIconView(iconName: "building.2.fill", isActive: progress >= 0)
            AnimatedConnectorView(isActive: progress >= 2, isProcessing: progress == 0 || progress == 1)
            StepIconView(iconName: "doc.text.fill", isActive: progress >= 2)
            AnimatedConnectorView(isActive: progress >= 3, isProcessing: progress == 2)
            // Pickup: show shippingbox.fill; Delivery: show bicycle
            StepIconView(iconName: isPickup ? "shippingbox.fill" : "bicycle", isActive: progress >= 3)
            AnimatedConnectorView(isActive: progress >= 4, isProcessing: progress == 3)
            // Pickup: show bag.fill; Delivery: show house.fill
            StepIconView(iconName: isPickup ? "bag.fill" : "house.fill", isActive: progress >= 4)
        }
    }
}

// MARK: - Step Icon

struct StepIconView: View {
    let iconName: String
    let isActive: Bool
    
    var body: some View {
        ZStack {
            if isActive {
                Circle()
                    .fill(primaryGradient)
                    .frame(width: 32, height: 32)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 32, height: 32)
            }
            
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isActive ? .white : .gray)
        }
        // Pulse animation on the active step icon (real-time feel)
        .scaleEffect(isActive ? 1.0 : 1.0)
        .animation(.easeInOut(duration: 0.4), value: isActive)
    }
}

// MARK: - Animated Connector (real-time shimmer when processing)

struct AnimatedConnectorView: View {
    let isActive: Bool
    let isProcessing: Bool
    
    // Shimmer animation state — drives the moving highlight
    @State private var shimmerOffset: CGFloat = -1.0

    var body: some View {
        GeometryReader { geometry in
            let w = max(geometry.size.width, 1)
            
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 4)

                if isActive {
                    // Fully filled — order passed this step
                    RoundedRectangle(cornerRadius: 2)
                        .fill(primaryGradient)
                        .frame(height: 4)
                        .animation(.easeInOut(duration: 0.5), value: isActive)

                } else if isProcessing {
                    // Half-filled with animated shimmer to convey "in progress"
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(primaryGradient)
                            .frame(width: w * 0.5, height: 4)

                        // Shimmer overlay
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0),
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0),
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: w * 0.3, height: 4)
                            .offset(x: shimmerOffset * w)
                            .clipped()
                            .onAppear {
                                withAnimation(
                                    Animation.linear(duration: 1.4)
                                        .repeatForever(autoreverses: false)
                                ) {
                                    shimmerOffset = 0.5
                                }
                            }
                            .onDisappear {
                                shimmerOffset = -1.0
                            }
                    }
                    .frame(width: w * 0.5)
                    .clipped()
                }
            }
            .frame(height: 32, alignment: .center)
        }
        .frame(height: 32)
        .padding(.horizontal, 4)
    }
}

// MARK: - Compact Ring View

struct ProgressRingView: View {
    let progress: Int
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 3)
            
            Circle()
                .trim(from: 0, to: CGFloat(progress) / 4.0)
                .stroke(primaryGradient, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
            
            Text("\(progress)/4")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(primaryGradient)
        }
        .frame(width: 24, height: 24)
    }
}
