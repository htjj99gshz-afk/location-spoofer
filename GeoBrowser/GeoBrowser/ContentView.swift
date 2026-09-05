import SwiftUI
import WebKit
import CoreLocation

struct ContentView: View {
    @State private var address = "https://www.google.com"
    @State private var currentURL = URL(string: "https://www.google.com")!

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                TextField("URL or search", text: $address)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.go)
                    .font(.system(size: 14))
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .onSubmit { navigate() }

                Button(action: navigate) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)

            GeoWebView(url: currentURL)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.container, edges: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dynamicTypeSize(.xSmall ... .large)
    }

    private func navigate() {
        var value = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.contains("://") {
            if value.contains(".") {
                value = "https://" + value
            } else {
                let q = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                value = "https://www.google.com/search?q=\(q)"
            }
        }
        if let u = URL(string: value) {
            currentURL = u
            address = value
        }
    }
}

struct GeoWebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "geoBridge")
        controller.addUserScript(WKUserScript(source: Coordinator.geolocationJS,
                                              injectionTime: .atDocumentStart,
                                              forMainFrameOnly: false))
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        context.coordinator.webView = webView
        webView.navigationDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.alwaysBounceVertical = false
        webView.pageZoom = 0.92
        webView.isOpaque = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, CLLocationManagerDelegate {
        weak var webView: WKWebView?
        private let locationManager = CLLocationManager()
        private var pendingIDs: [String: Bool] = [:]

        override init() {
            super.init()
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
        }

        static let geolocationJS = #"""
        (function() {
          if (!window.navigator) return;
          const callbacks = {};
          let seq = 0;
          function nextId() { seq += 1; return "geo_" + Date.now() + "_" + seq; }
          function post(type, id, options) {
            window.webkit.messageHandlers.geoBridge.postMessage({type:type,id:id,options:options||{}});
          }
          const geo = {
            getCurrentPosition: function(success, error, options) {
              const id = nextId(); callbacks[id] = {success:success,error:error,watch:false}; post("get",id,options);
            },
            watchPosition: function(success, error, options) {
              const id = nextId(); callbacks[id] = {success:success,error:error,watch:true}; post("watch",id,options); return id;
            },
            clearWatch: function(id) { delete callbacks[id]; post("clear",String(id),{}); }
          };
          try {
            Object.defineProperty(navigator, 'geolocation', {configurable:true, enumerable:true, value:geo});
          } catch (_) { try { navigator.geolocation = geo; } catch (_) {} }
          window.__geoResolve = function(id, payload, isError) {
            const cb = callbacks[id]; if (!cb) return;
            try {
              if (isError) {
                if (cb.error) cb.error(payload);
              } else {
                if (cb.success) cb.success(payload);
              }
            } finally {
              if (!cb.watch) delete callbacks[id];
            }
          };
        })();
        """#

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String,
                  let id = body["id"] as? String else { return }

            switch type {
            case "get":
                pendingIDs[id] = false
                requestLocation()
            case "watch":
                pendingIDs[id] = true
                requestLocation()
            case "clear":
                pendingIDs.removeValue(forKey: id)
                if pendingIDs.isEmpty { locationManager.stopUpdatingLocation() }
            default:
                break
            }
        }

        private func requestLocation() {
            switch locationManager.authorizationStatus {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse:
                locationManager.startUpdatingLocation()
            case .denied, .restricted:
                resolveErrorAll(code: 1, message: "Location permission denied.")
            @unknown default:
                resolveErrorAll(code: 2, message: "Location unavailable.")
            }
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                manager.startUpdatingLocation()
            case .denied, .restricted:
                resolveErrorAll(code: 1, message: "Location permission denied.")
            default:
                break
            }
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let loc = manager.location ?? locations.last else { return }

            for id in Array(pendingIDs.keys) {
                resolveSuccess(id: id, location: loc)
                if pendingIDs[id] == false {
                    pendingIDs.removeValue(forKey: id)
                }
            }

            if pendingIDs.isEmpty {
                manager.stopUpdatingLocation()
            }
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            resolveErrorAll(code: 2, message: error.localizedDescription)
        }

        private func resolveSuccess(id: String, location: CLLocation) {
            let heading: Any = location.course >= 0 ? NSNumber(value: location.course) : NSNull()
            let speed: Any = location.speed >= 0 ? NSNumber(value: location.speed) : NSNull()
            let payload: [String: Any] = [
                "coords": [
                    "latitude": location.coordinate.latitude,
                    "longitude": location.coordinate.longitude,
                    "accuracy": location.horizontalAccuracy,
                    "altitude": location.altitude,
                    "altitudeAccuracy": location.verticalAccuracy,
                    "heading": heading,
                    "speed": speed
                ],
                "timestamp": Int(location.timestamp.timeIntervalSince1970 * 1000)
            ]
            resolve(id: id, payload: payload, isError: false)
        }

        private func resolveErrorAll(code: Int, message: String) {
            for id in Array(pendingIDs.keys) {
                resolve(id: id, payload: ["code": code, "message": message], isError: true)
            }
            pendingIDs.removeAll()
        }

        private func resolve(id: String, payload: [String: Any], isError: Bool) {
            guard let data = try? JSONSerialization.data(withJSONObject: payload),
                  let json = String(data: data, encoding: .utf8) else { return }

            let escapedID = id
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")

            let js = "window.__geoResolve && window.__geoResolve('\(escapedID)', \(json), \(isError ? "true" : "false"));"
            DispatchQueue.main.async { [weak self] in
                self?.webView?.evaluateJavaScript(js)
            }
        }
    }
}
