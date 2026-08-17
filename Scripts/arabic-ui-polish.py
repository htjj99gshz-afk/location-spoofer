#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

# Final Arabic presentation pass. Runs after apply-arabic-ui.py.
# This pass only touches visible SwiftUI copy and setup-guide rendering.
TEXT_REPLACEMENTS = {
    "وكيل Wi‑Fi": "بروكسي Wi‑Fi",
    "وكيل Wi-Fi": "بروكسي Wi‑Fi",
    "وكيل HTTP": "بروكسي HTTP",
    "الوكيل المحلي": "البروكسي المحلي",
    "من الوكيل أو من الثقة بالشهادة": "من البروكسي أو من الثقة بالشهادة",
    "إعداد وكيل Wi‑Fi": "إعداد بروكسي Wi‑Fi",
    "أولًا: إعداد وكيل Wi‑Fi في النظام": "أولًا: إعداد بروكسي Wi‑Fi في النظام",
}


def replace_visible_terms(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    original = text
    for source, target in TEXT_REPLACEMENTS.items():
        text = text.replace(source, target)
    if text != original:
        path.write_text(text, encoding="utf-8")
        print(f"Arabic polish: terminology updated in {path.relative_to(ROOT)}")


def replace_setup_screenshots() -> None:
    path = ROOT / "App" / "FirstSetupView.swift"
    text = path.read_text(encoding="utf-8")

    pattern = re.compile(
        r"\n\s*@ViewBuilder\n\s*private func setupScreenshot\(.*?\n\s*private func openThirdPartyClient",
        re.S,
    )

    replacement = r'''

    @ViewBuilder
    private func setupScreenshot(
        assetName: String,
        title: String,
        caption: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: arabicGuideIcon(for: assetName))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 34, height: 34)
                    .background(Color.blue.opacity(0.12), in: Circle())
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let detail = arabicGuideDetail(for: assetName) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.secondary.opacity(0.18))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(caption)")
    }

    private func arabicGuideIcon(for assetName: String) -> String {
        switch assetName {
        case "AppModeWiFiProxy": return "wifi"
        case "AppModeCertificateInstall": return "checkmark.shield"
        case "AppModeCertificateTrust": return "checkmark.seal"
        case "ShadowrocketConfigDetails": return "gearshape.2"
        case "ShadowrocketModuleImport": return "square.and.arrow.down"
        case "ShadowrocketHTTPSDecryption": return "lock.open"
        case "ShadowrocketHTTPSCA": return "checkmark.shield.fill"
        default: return "info.circle"
        }
    }

    private func arabicGuideDetail(for assetName: String) -> String? {
        switch assetName {
        case "AppModeWiFiProxy":
            return "في إعدادات شبكة Wi‑Fi الحالية: بروكسي HTTP ← يدوي ← الخادم 127.0.0.1 ← المنفذ 8888. اترك المصادقة متوقفة."
        case "AppModeCertificateInstall":
            return "بعد تنزيل ملف التعريف: الإعدادات ← عام ← VPN وإدارة الجهاز ← Location Spoofer CA ← تثبيت."
        case "AppModeCertificateTrust":
            return "بعد التثبيت: الإعدادات ← عام ← حول ← إعدادات الثقة بالشهادات ← فعّل الثقة الكاملة لـ Location Spoofer CA."
        case "ShadowrocketConfigDetails":
            return "في Shadowrocket افتح «التكوين» ثم «الوحدات» أو تفاصيل ملف التكوين المحلي المستخدم حاليًا."
        case "ShadowrocketModuleImport":
            return "أضف رابط اشتراك الوحدة الذي نسخته من التطبيق، ثم تأكد أن الوحدة مفعلة."
        case "ShadowrocketHTTPSDecryption":
            return "فعّل فك HTTPS وأضف النطاقين gs-loc.apple.com و gs-loc-cn.apple.com إلى قائمة MITM."
        case "ShadowrocketHTTPSCA":
            return "أنشئ شهادة Shadowrocket واتبع تعليمات iOS لتثبيتها ومنحها الثقة الكاملة قبل تشغيل البروكسي."
        default:
            return nil
        }
    }

    private func openThirdPartyClient'''

    new_text, count = pattern.subn(replacement, text, count=1)
    if count != 1:
        raise SystemExit("Could not replace setupScreenshot block")

    path.write_text(new_text, encoding="utf-8")
    print("Arabic polish: replaced Chinese screenshot assets with native Arabic guide cards")


def validate_visible_han() -> None:
    # Do not fail on internal diagnostics/logging. Catch common SwiftUI literals only.
    patterns = [
        re.compile(r'(?:Text|Label|Button|Section|GroupBox|TextField)\(\s*"[^"\n]*[\u3400-\u9fff]'),
        re.compile(r'\.navigationTitle\(\s*"[^"\n]*[\u3400-\u9fff]'),
        re.compile(r'\.alert\(\s*"[^"\n]*[\u3400-\u9fff]'),
    ]
    offenders = []
    for path in sorted((ROOT / "App").glob("*.swift")):
        text = path.read_text(encoding="utf-8")
        for lineno, line in enumerate(text.splitlines(), start=1):
            if any(p.search(line) for p in patterns):
                offenders.append(f"{path.relative_to(ROOT)}:{lineno}: {line.strip()}")
    if offenders:
        print("Arabic polish warning: possible untranslated visible Chinese literals:")
        for item in offenders[:50]:
            print("  " + item)
    else:
        print("Arabic polish: no obvious Chinese literals remain in common SwiftUI controls")


def main() -> None:
    for path in sorted((ROOT / "App").glob("*.swift")):
        replace_visible_terms(path)
    replace_setup_screenshots()
    validate_visible_han()


if __name__ == "__main__":
    main()
