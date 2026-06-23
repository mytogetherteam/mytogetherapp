import ActivityKit
import WidgetKit
import SwiftUI

struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState 
    
    // Dynamic data passed from Flutter using live_activities package
    public struct ContentState: Codable, Hashable {
        var data: [String: String] 
    }
    
    var id = UUID()
}
