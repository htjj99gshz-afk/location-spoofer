import SwiftUI

enum TipKind: String, Identifiable {
    case activation = "إرشادات التفعيل"
    case deactivation = "إرشادات الإلغاء"
    case removeProxy = "إيقاف بروكسي Wi‑Fi"
    var id: String { rawValue }
}

struct TipSheetView: View {
    let kind: TipKind
    var runtimeMode: ProxyRuntimeMode = .localWiFi
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch kind {
                    case .activation: ActivationTipContent(runtimeMode: runtimeMode, dismiss: { dismiss() })
                    case .deactivation: DeactivationTipContent(runtimeMode: runtimeMode, dismiss: { dismiss() })
                    case .removeProxy: RemoveProxyTipContent(dismiss: { dismiss() })
                    }
                }.padding(16)
            }
            .navigationTitle(kind.rawValue).navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button { dismiss() } label: {
                    Text("حسنًا").font(.body.weight(.medium)).frame(maxWidth: .infinity).padding(.vertical, 12)
                }.buttonStyle(.borderedProminent).tint(.blue).padding(.horizontal, 16).padding(.bottom, 8)
            }
        }
    }
}

@MainActor
private func openSettings(_ destination: SystemSettingsDestination) {
    guard let appSettingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
    // Try the preferred (private) URL scheme first; fall back to reliable app-settings:
    if let preferredURL = destination.preferredURL, preferredURL != appSettingsURL {
        UIApplication.shared.open(preferredURL) { opened in
            if !opened {
                UIApplication.shared.open(appSettingsURL)
            }
        }
    } else {
        UIApplication.shared.open(appSettingsURL)
    }
}

// MARK: - Activation guide

struct ActivationTipContent: View {
    var runtimeMode: ProxyRuntimeMode = .localWiFi
    let dismiss: () -> Void

    var body: some View {
        GroupBox(label: Label("تفعيل الموقع الافتراضي", systemImage: "checklist")) {
            VStack(alignment: .leading, spacing: 10) {
                if runtimeMode == .thirdParty {
                    step(0, "تأكد من تشغيل البروكسي الخارجي", "أبقِ وحدة WLOC وفك تشفير HTTPS واتصال البروكسي أو VPN في التطبيق الخارجي قيد التشغيل.")
                }
                step(1, "تشغيل نمط الطيران", "افتح مركز التحكم وشغّل نمط الطيران بالضغط على رمز الطائرة. قد ينقطع Wi‑Fi تلقائيًا. انتظر ثانيتين.")
                step(2, "إيقاف Wi‑Fi", "من مركز التحكم تأكد أن Wi‑Fi متوقف، ثم انتظر ثانيتين.")
                systemStep(3, "إيقاف خدمات الموقع", "افتح «الإعدادات ← الخصوصية والأمان ← خدمات الموقع»، ثم أوقف المفتاح الرئيسي لخدمات الموقع. انتظر ثانيتين.")
                step(4, "تشغيل Wi‑Fi وبدء الموقع الافتراضي", runtimeMode == .thirdParty ? "شغّل Wi‑Fi من مركز التحكم مع إبقاء نمط الطيران مفعّلًا، وتأكد من اتصال البروكسي الخارجي. الإحداثيات تكون قد تزامنت معه. انتظر ثانيتين." : "شغّل Wi‑Fi من مركز التحكم مع إبقاء نمط الطيران مفعّلًا، ثم ارجع للتطبيق واضغط «بدء الموقع الافتراضي». انتظر ثانيتين.")
                step(5, "إيقاف نمط الطيران", "أوقف نمط الطيران من مركز التحكم، ثم انتظر ثانيتين.")
                systemStep(6, "إعادة تشغيل خدمات الموقع", "ارجع إلى «الإعدادات ← الخصوصية والأمان ← خدمات الموقع» وشغّل المفتاح الرئيسي. بعدها افتح خرائط Apple للتحقق من الموقع.")
            }.padding(.vertical, 4)
        }

        GroupBox(label: Label("ما زال الموقع لا يتغير؟", systemImage: "exclamationmark.triangle")) {
            Text("إذا لم يتغير الموقع، أعد تشغيل الآيفون بعد إتمام الخطوة 3، ثم أكمل من الخطوة 4. يساعد ذلك على مسح بيانات الموقع المخزنة مؤقتًا في النظام.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        }

    }

    private func step(_ n: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(n)").font(.caption2.bold())
                .frame(width: 20, height: 20)
                .background(Color.blue.opacity(0.15), in: Circle()).foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption.weight(.semibold))
                Text(detail).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func systemStep(_ n: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(n)").font(.caption2.bold())
                .frame(width: 20, height: 20)
                .background(Color.orange.opacity(0.18), in: Circle()).foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.caption.weight(.semibold))
                Text(detail).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button { openSettings(.locationServices) } label: {
                    Label("فتح الإعدادات", systemImage: "arrow.up.right.square").font(.caption)
                }.buttonStyle(.bordered).tint(.blue)
            }
        }
    }
}

// MARK: - Deactivation guide

struct DeactivationTipContent: View {
    var runtimeMode: ProxyRuntimeMode = .localWiFi
    let dismiss: () -> Void

    var body: some View {
        GroupBox(label: Label("إلغاء الموقع الافتراضي", systemImage: "arrow.uturn.backward.circle")) {
            VStack(alignment: .leading, spacing: 10) {
                step(1, "تشغيل نمط الطيران", "شغّل نمط الطيران من مركز التحكم، ثم انتظر ثانيتين.")
                step(2, "إيقاف Wi‑Fi", "من مركز التحكم تأكد أن Wi‑Fi متوقف، ثم انتظر ثانيتين.")
                systemStep(3, "إيقاف خدمات الموقع", "افتح «الإعدادات ← الخصوصية والأمان ← خدمات الموقع» وأوقف المفتاح الرئيسي، ثم انتظر ثانيتين.")
                if runtimeMode == .thirdParty {
                    step(4, "التأكد من مسح الإحداثيات", "أرسل التطبيق أمر مسح الموقع الافتراضي إلى البروكسي الخارجي. أبقِ الشبكة متاحة وانتظر ثانيتين حتى يعيد النظام جلب موقعك الحقيقي.")
                } else {
                    systemStep(4, "تشغيل Wi‑Fi وإيقاف البروكسي", "شغّل Wi‑Fi، ثم افتح تفاصيل الشبكة الحالية واضبط «بروكسي HTTP» على «إيقاف». انتظر ثانيتين.")
                }
                step(5, "إيقاف نمط الطيران", "أوقف نمط الطيران من مركز التحكم، ثم انتظر ثانيتين.")
                systemStep(6, "إعادة تشغيل خدمات الموقع", "ارجع إلى «الإعدادات ← الخصوصية والأمان ← خدمات الموقع» وشغّل المفتاح الرئيسي، ثم افتح خرائط Apple للتأكد من عودة موقعك الحقيقي.")
            }.padding(.vertical, 4)
        }

        GroupBox(label: Label("ما زال الموقع الافتراضي ظاهرًا؟", systemImage: "exclamationmark.triangle")) {
            Text("أعد تشغيل الآيفون بعد إتمام الخطوة 3، ثم أكمل من الخطوة 4.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        }

    }

    private func step(_ n: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(n)").font(.caption2.bold())
                .frame(width: 20, height: 20)
                .background(Color.blue.opacity(0.15), in: Circle()).foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption.weight(.semibold))
                Text(detail).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func systemStep(_ n: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(n)").font(.caption2.bold())
                .frame(width: 20, height: 20)
                .background(Color.orange.opacity(0.18), in: Circle()).foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.caption.weight(.semibold))
                Text(detail).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button { openSettings(.locationServices) } label: {
                    Label("فتح الإعدادات", systemImage: "arrow.up.right.square").font(.caption)
                }.buttonStyle(.bordered).tint(.blue)
            }
        }
    }
}

// MARK: - Remove Wi-Fi proxy

struct RemoveProxyTipContent: View {
    let dismiss: () -> Void

    var body: some View {
        GroupBox(label: Label("إيقاف بروكسي Wi‑Fi", systemImage: "wifi.slash")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("بعد إيقاف الموقع الافتراضي، أوقف إعداد بروكسي Wi‑Fi يدويًا حتى لا يتأثر اتصال الإنترنت.\n\n1. افتح «الإعدادات ← Wi‑Fi»\n2. اضغط زر (i) بجانب الشبكة الحالية\n3. افتح «تكوين البروكسي» أو «بروكسي HTTP»\n4. اختر «إيقاف»\n5. اضغط «حفظ»")
                    .font(.caption).foregroundStyle(.primary)
                Button { openSettings(.wifi) } label: {
                    Label("فتح إعدادات Wi‑Fi", systemImage: "arrow.up.right.square").font(.caption)
                }.buttonStyle(.bordered).tint(.blue)
            }.padding(.vertical, 4)
        }
    }
}
