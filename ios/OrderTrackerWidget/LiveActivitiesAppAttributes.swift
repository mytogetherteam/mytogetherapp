import ActivityKit
import WidgetKit
import SwiftUI

struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState 
    
    // Dynamic data passed from Flutter using live_activities package
    public struct ContentState: Codable, Hashable {
        var shopName: String?
        var statusText: String?
        var progress: String?
        var estimatedTime: String?
        var riderName: String?
        var shopLogoPath: String?
    }
    
    var id = UUID()
}
