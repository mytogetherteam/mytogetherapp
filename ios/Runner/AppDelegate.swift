import Flutter
import UIKit
import GoogleMaps
import PushKit
import CallKit
import AVFAudio
import flutter_callkit_incoming

@main
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate {
  private var voipRegistry: PKPushRegistry?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let apiKey = Bundle.main.infoDictionary?["GOOGLE_MAPS_API_KEY"] as? String {
      GMSServices.provideAPIKey(apiKey)
    }
    GeneratedPluginRegistrant.register(with: self)

    // Register Apple PushKit for incoming VoIP calls in background/terminated states
    let voipRegistry = PKPushRegistry(queue: .main)
    voipRegistry.delegate = self
    voipRegistry.desiredPushTypes = [.voIP]
    self.voipRegistry = voipRegistry

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didUpdate pushCredentials: PKPushCredentials,
    for type: PKPushType
  ) {
    guard type == .voIP else { return }
    let deviceToken = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(deviceToken)
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didInvalidatePushTokenFor type: PKPushType
  ) {
    guard type == .voIP else { return }
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType,
    completion: @escaping () -> Void
  ) {
    guard type == .voIP else {
      completion()
      return
    }

    let dict = payload.dictionaryPayload
    let rawId = (dict["callId"] as? String) ?? (dict["id"] as? String) ?? UUID().uuidString
    let callUUID = UUID(uuidString: rawId)?.uuidString.lowercased() ?? UUID().uuidString.lowercased()
    let callerName = (dict["callerName"] as? String)
      ?? (dict["nameCaller"] as? String)
      ?? "Shop"
    let handle = (dict["handle"] as? String) ?? callerName

    let data = flutter_callkit_incoming.Data(
      id: callUUID,
      nameCaller: callerName,
      handle: handle,
      type: 0
    )
    data.appName = "MyTogether"
    data.duration = 60000
    data.supportsVideo = false
    data.maximumCallGroups = 1
    data.maximumCallsPerCallGroup = 1
    data.audioSessionMode = "voiceChat"
    data.audioSessionActive = true
    data.iconName = "AppIcon"
    data.extra = [
      "callId": rawId,
      "callerName": callerName,
      "shopId": (dict["shopId"] as? String) ?? "",
      "direction": (dict["direction"] as? String) ?? "shop-to-user"
    ] as NSDictionary

    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(
      data,
      fromPushKit: true
    ) {
      completion()
    }
  }
}
