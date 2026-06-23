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
                        if let logoPath = context.state.shopLogoPath, let uiImage = UIImage(contentsOfFile: logoPath) {
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
                        
                        Text(context.state.statusText ?? "Processing")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let eta = context.state.estimatedTime, !eta.isEmpty {
                        Text(eta)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(primaryGradient)
                            .padding(.trailing, 4)
                    } else {
                        Text("Soon")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(primaryGradient)
                            .padding(.trailing, 4)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            if let riderName = context.state.riderName, !riderName.isEmpty {
                                Image(systemName: "person.crop.circle.fill")
                                    .foregroundColor(.gray)
                                    .font(.title2)
                                Text(riderName)
                                    .font(.system(size: 14, weight: .medium))
                            } else {
                                Image(systemName: "storefront.fill")
                                    .foregroundColor(.gray)
                                    .font(.title2)
                                Text(context.state.shopName ?? "Restaurant")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        
                        ProgressBarView(progress: Int(context.state.progress ?? "0") ?? 0)
                            .padding(.horizontal, 4)
                            .padding(.bottom, 4)
                    }
                }
            } compactLeading: {
                if let logoPath = context.state.shopLogoPath, let uiImage = UIImage(contentsOfFile: logoPath) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 20, height: 20)
                        .clipShape(Circle())
                } else {
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .clipShape(Circle())
                }
            } compactTrailing: {
                if let eta = context.state.estimatedTime, !eta.isEmpty {
                    Text(eta)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(primaryGradient)
                } else {
                    ProgressRingView(progress: Int(context.state.progress ?? "0") ?? 0)
                }
            } minimal: {
                if let logoPath = context.state.shopLogoPath, let uiImage = UIImage(contentsOfFile: logoPath) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 20, height: 20)
                        .clipShape(Circle())
                } else {
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .clipShape(Circle())
                }
            }
        }
    }
}

struct LiveActivityView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        let shopName = context.state.shopName ?? "Restaurant"
        let statusText = context.state.statusText ?? "Processing"
        let progress = Int(context.state.progress ?? "0") ?? 0
        let eta = context.state.estimatedTime ?? ""
        let riderName = context.state.riderName ?? ""
        
        VStack(spacing: 16) {
            // Header Row
            HStack(alignment: .center, spacing: 12) {
                // Logo
                Group {
                    if let logoPath = context.state.shopLogoPath, let uiImage = UIImage(contentsOfFile: logoPath) {
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
                
                Spacer()
                
                // ETA Box
                if !eta.isEmpty {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("ETA")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.gray)
                        Text(eta)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(primaryGradient)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            // Progress Bar
            ProgressBarView(progress: progress)
        }
        .padding(16)
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
            StepIconView(iconName: "box.truck.fill", isActive: progress >= 3)
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
                    .frame(height: 4)
                    .cornerRadius(2)
                
                if isActive {
                    Rectangle()
                        .fill(primaryGradient)
                        .frame(height: 4)
                        .cornerRadius(2)
                } else if isProcessing {
                    Rectangle()
                        .fill(primaryGradient)
                        .frame(width: geometry.size.width * 0.5, height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 32)
        }
        .frame(height: 32)
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
                .stroke(primaryGradient, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            Text("\(progress)/4")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(primaryGradient)
        }
        .frame(width: 24, height: 24)
    }
}
