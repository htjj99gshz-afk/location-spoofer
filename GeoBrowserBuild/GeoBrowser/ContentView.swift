import SwiftUI
import WebKit
import CoreLocation

struct ContentView: View {
    @State private var address = "https://www.google.com"
    @State private var currentURL = URL(string: "https://www.google.com")!

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("URL or search", text: $address)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { navigate() }
                Button("Go") { navigate() }
            }
            .padding(8)

            GeoWebView(url: currentURL)
        }
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
        if let url = URL(string: value) {
            currentURL = url
        }
    }
}

struct GeoWebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let content = WKUserContentController()
        content.add(context.coordinator, name: "geoBridge")
        content.addUserScript(WKUserScript(source: Coordinator.geolocationJS,
                                           injectionTime: .atDocumentStart,
                                           forMainFrameOnly: false))
        config.userContentController = content

        let webView = WKWebView(frame: .zero, configuration: config)
        context.coordinator.webView = webView
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url?.absoluteString != url.absoluteString {
            webView.load(URLRequest(url: url))
        }
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, CLLocationManagerDelegate {
        weak var webView: WKWebView?
        private let locationManager = CLLocationManager()
        private var pending: [String: Bool] = [:]

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
          function nextId(){ seq += 1; return 'geo_' + Date.now() + '_' + seq; }
          function post(type,id,options){
            window.webkit.messageHandlers.geoBridge.postMessage({type:type,id:id,options:options||{}});
          }
          const proxy = {
            getCurrentPosition: function(success,error,options){
              const id=nextId(); callbacks[id]={success:success,error:error,watch:false}; post('get',id,options);
            },
            watchPosition: function(success,error,options){
              const id=nextId(); callbacks[id]={success:success,error:error,watch:true}; post('watch',id,options); return id;
            },
            clearWatch: function(id){ delete callbacks[id]; post('clear',String(id),{}); }
          };
          try {
            Object.defineProperty(navigator,'geolocation',{configurable:true,enumerable:true,value:proxy});
          } catch(e) {
            try {
              navigator.geolocation.getCurrentPosition = proxy.getCurrentPosition;
              navigator.geolocation.watchPosition = proxy.watchPosition;
              navigator.geolocation.clearWatch = proxy.clearWatch;
            } catch(_) {}
          }
          window.__geoResolve = function(id,payload,isError){
            const cb=callbacks[id]; if(!cb) return;
            try { if(isError){ if(cb.error) cb.error(payload); } else { if(cb.success) cb.success(payload); } }
            finally { if(!cb.watch) delete callbacks[id]; }
          };
        })();
        """#

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String,
                  let id = body["id"] as? String else { return }

            switch type {
            case "get":
                pending[id] = false
                requestLocation()
            case "watch":
                pending[id] = true
                requestLocation()
            case "clear":
                pending.removeValue(forKey: id)
                if pending.isEmpty { locationManager.stopUpdatingLocation() }
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
            guard let location = locations.last else { return }
            let ids = Array(pending.keys)
            for id in ids {
                resolveSuccess(id: id, location: location)
                if pending[id] == false { pending.removeValue(forKey: id) }
            }
            if pending.isEmpty { manager.stopUpdatingLocation() }
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            resolveErrorAll(code: 2, message: error.localizedDescription)
        }

        private func resolveSuccess(id: String, location: CLLocation) {
            var coords: [String: Any] = [
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "accuracy": location.horizontalAccuracy,
                "altitude": location.altitude,
                "altitudeAccuracy": location.verticalAccuracy
            ]
            coords["heading"] = location.course >= 0 ? location.course : NSNull()
            coords["speed"] = location.speed >= 0 ? location.speed : NSNull()
            let payload: [String: Any] = [
                "coords": coords,
                "timestamp": Int(location.timestamp.timeIntervalSince1970 * 1000)
            ]
            resolve(id: id, payload: payload, isError: false)
        }

        private func resolveErrorAll(code: Int, message: String) {
            let ids = Array(pending.keys)
            for id in ids {
                resolve(id: id, payload: ["code": code, "message": message], isError: true)
            }
            pending.removeAll()
        }

        private func resolve(id: String, payload: [String: Any], isError: Bool) {
            guard let data = try? JSONSerialization.data(withJSONObject: payload),
                  let json = String(data: data, encoding: .utf8) else { return }
            let safeID = id.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
            let js = "window.__geoResolve && window.__geoResolve('\(safeID)', \(json), \(isError ? "true" : "false"));"
            DispatchQueue.main.async { [weak self] in
                self?.webView?.evaluateJavaScript(js, completionHandler: nil)
            }
        }
    }
}
