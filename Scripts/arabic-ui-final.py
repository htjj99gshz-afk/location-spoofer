#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
CJK = re.compile(r'[\u3400-\u9fff]')

# Final cleanup for strings that combine interpolation or were only partially
# translated by the broad presentation-layer pass.
REPLACEMENTS = {
    '第 1 步：导入 \\(client.name) 模块': 'الخطوة 1: استيراد وحدة \\(client.name)',
    '打开 \\(client.name)': 'فتح \\(client.name)',
    '打开 \\(thirdPartyClient.selectedClient.name)': 'فتح \\(thirdPartyClient.selectedClient.name)',
    '第 2 步：تم \\(client.name) 配置': 'الخطوة 2: إكمال إعداد \\(client.name)',
    '请在 \\(client.name) 中تم相应配置。': 'أكمل الإعداد المطلوب داخل \\(client.name).',
    '配置时请使用 gs-loc.apple.com 和 gs-loc-cn.apple.com 两个域名。': 'استخدم النطاقين gs-loc.apple.com و gs-loc-cn.apple.com أثناء الإعداد.',
    '第 2 步：إعداد فك تشفير HTTPS': 'الخطوة 2: إعداد فك تشفير HTTPS',
    '不再提示': 'عدم الإظهار مجددًا',
    '当前الموقع الافتراضي和本地代理将停止。App 会删除钥匙串中的设备 CA、立即生成新الشهادة，并打开安装与信任引导。你还需要前往 iOS「الإعدادات → 通用 → VPN 与设备管理」手动删除旧الشهادة，然后重新下载安装并完全信任新الشهادة。': 'سيتم إيقاف الموقع الافتراضي والبروكسي المحلي. سيحذف التطبيق شهادة CA الخاصة بالجهاز من Keychain وينشئ شهادة جديدة ويفتح إرشادات التثبيت والثقة. بعد ذلك انتقل في iOS إلى «الإعدادات ← عام ← VPN وإدارة الجهاز» واحذف الشهادة القديمة يدويًا، ثم نزّل الشهادة الجديدة وثبّتها وامنحها الثقة الكاملة.',
    '当前الإصدار \\(currentVersion)，远程最新الإصدار \\(latestVersion)。': 'الإصدار الحالي \\(currentVersion)، وأحدث إصدار متاح \\(latestVersion).',
    '当前模块الإصدار较旧，基础坐标功能仍可继续使用。重新导入最新模块后可使用الإصدار检测和محاكاة حالة الحركة。': 'إصدار الوحدة الحالي قديم. يمكنك الاستمرار في استخدام الإحداثيات الأساسية، وبعد إعادة استيراد أحدث وحدة ستتوفر ميزة فحص الإصدار ومحاكاة حالة الحركة.',
    'Egern 直接使用 Surge 的 .sgmodule 模块。': 'يستخدم Egern وحدة Surge بصيغة .sgmodule مباشرة.',
    'Stash 直接订阅 .stoverride，不要通过 Script Hub 转换。': 'في Stash اشترك بملف .stoverride مباشرة ولا تحوّله عبر Script Hub.',
    'نسخ رابط اشتراك الوحدة后，在对应代理العميل中添加模块/重写订阅，并为 gs-loc.apple.com 和 gs-loc-cn.apple.com 启用 MITM。第三方العميلحفظ坐标后，即使إغلاق本 App，坐标仍由代理العميل持久化并继续生效。': 'بعد نسخ رابط اشتراك الوحدة، أضفه في عميل البروكسي المناسب كوحدة أو اشتراك إعادة كتابة، وفعّل MITM للنطاقين gs-loc.apple.com و gs-loc-cn.apple.com. بعد حفظ الإحداثيات في العميل الخارجي ستبقى محفوظة وفعالة حتى عند إغلاق هذا التطبيق.',
}


def apply(path: Path) -> None:
    text = path.read_text(encoding='utf-8')
    original = text
    for source, target in REPLACEMENTS.items():
        text = text.replace(source, target)
    if text != original:
        path.write_text(text, encoding='utf-8')
        print(f'Arabic final: updated {path.relative_to(ROOT)}')


def swift_string_literals(text: str):
    # Covers ordinary and multiline Swift string literals well enough for UI
    # validation. The goal is to catch any remaining Chinese copy regardless of
    # whether it is passed directly to Text/Label or through helper functions.
    pattern = re.compile(r'"""[\s\S]*?"""|"(?:\\.|[^"\\])*"')
    yield from pattern.finditer(text)


def validate_swift_file(path: Path, offenders: list[str]) -> None:
    text = path.read_text(encoding='utf-8')
    for match in swift_string_literals(text):
        literal = match.group(0)
        if CJK.search(literal):
            line = text.count('\n', 0, match.start()) + 1
            compact = ' '.join(literal.split())
            offenders.append(f'{path.relative_to(ROOT)}:{line}: {compact[:220]}')


def validate_plist(offenders: list[str]) -> None:
    path = ROOT / 'Resources' / 'Info.plist'
    if not path.exists():
        return
    text = path.read_text(encoding='utf-8')
    for match in re.finditer(r'<string>([\s\S]*?)</string>', text):
        value = match.group(1)
        if CJK.search(value):
            line = text.count('\n', 0, match.start()) + 1
            offenders.append(f'{path.relative_to(ROOT)}:{line}: {value.strip()}')


def validate() -> None:
    offenders: list[str] = []
    for directory in ['App', 'Shared']:
        for path in sorted((ROOT / directory).glob('*.swift')):
            validate_swift_file(path, offenders)
    validate_plist(offenders)

    if offenders:
        print('Arabic UI validation failed. Chinese text remains in string literals:')
        for item in offenders[:200]:
            print('  ' + item)
        raise SystemExit(f'Arabic UI validation failed: {len(offenders)} untranslated string literals remain')

    print('Arabic UI validation: zero Chinese string literals in App/, Shared/, and Info.plist')


def main() -> None:
    for directory in ['App', 'Shared']:
        for path in sorted((ROOT / directory).glob('*.swift')):
            apply(path)
    validate()


if __name__ == '__main__':
    main()
