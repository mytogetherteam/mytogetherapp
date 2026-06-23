import ActivityKit
import WidgetKit
import SwiftUI

struct OrderTrackerWidgetLiveActivity: Widget {
    
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            // Lock screen/banner UI goes here
            LiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here. Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "bag.fill")
                        .foregroundColor(.orange)
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.data["statusText"] ?? "Processing")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(context.state.data["shopName"] ?? "Restaurant")
                            .font(.headline)
                        ProgressBarView(progress: Int(context.state.data["progress"] ?? "0") ?? 0)
                    }
                }
            } compactLeading: {
                Image(systemName: "bag.fill")
                    .foregroundColor(.orange)
            } compactTrailing: {
                ProgressRingView(progress: Int(context.state.data["progress"] ?? "0") ?? 0)
            } minimal: {
                Image(systemName: "bag.fill")
                    .foregroundColor(.orange)
            }
        }
    }
}

struct LiveActivityView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        let shopName = context.state.data["shopName"] ?? "Restaurant"
        let statusText = context.state.data["statusText"] ?? "Processing"
        let progress = Int(context.state.data["progress"] ?? "0") ?? 0
        
        VStack(spacing: 12) {
            // Header Row
            HStack(spacing: 12) {
                // Logo placeholder
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Image(systemName: "storefront.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 18))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(shopName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .lineLimit(1)
                    
                    Text(statusText)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Track badge
                Text("Tracking")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .clipShape(Capsule())
            }
            
            // Progress Bar
            ProgressBarView(progress: progress)
                .padding(.top, 4)
                .padding(.bottom, 6)
        }
        .padding(16)
        .background(colorScheme == .dark ? Color.black : Color.white)
    }
}

struct ProgressBarView: View {
    let progress: Int
    
    var body: some View {
        HStack(spacing: 0) {
            StepIconView(iconName: "building.2.fill", isActive: progress >= 0)
            ConnectorView(isActive: progress >= 2, isProcessing: progress == 0 || progress == 1)
            StepIconView(iconName: "doc.text.fill", isActive: progress >= 2)
            ConnectorView(isActive: progress >= 3, isProcessing: progress == 2)
            StepIconView(iconName: "box.truck.fill", isActive: progress >= 3) // bicycle not available in all SF symbols without .fill sometimes, using box.truck
            ConnectorView(isActive: progress >= 4, isProcessing: progress == 3)
            StepIconView(iconName: "house.fill", isActive: progress >= 4)
        }
    }
}

struct StepIconView: View {
    let iconName: String
    let isActive: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isActive ? Color.orange : Color.gray.opacity(0.2))
                .frame(width: 30, height: 30)
            
            Image(systemName: iconName)
                .font(.system(size: 14))
                .foregroundColor(isActive ? .white : .gray)
        }
    }
}

struct ConnectorView: View {
    let isActive: Bool
    let isProcessing: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 3)
                
                if isActive {
                    Rectangle()
                        .fill(Color.orange)
                        .frame(height: 3)
                } else if isProcessing {
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: geometry.size.width * 0.5, height: 3)
                        // In a real live activity we avoid infinite animations to save battery,
                        // so we just show it half-way to indicate processing.
                }
            }
            .frame(height: 30) // To center vertically with the 30pt height icons
        }
        .frame(height: 30)
        .padding(.horizontal, 4)
    }
}

struct ProgressRingView: View {
    let progress: Int
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 3)
            
            Circle()
                .trim(from: 0, to: CGFloat(progress) / 4.0)
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            Text("\(progress)/4")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.orange)
        }
        .frame(width: 24, height: 24)
    }
}
