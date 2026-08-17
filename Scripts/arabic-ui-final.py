#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

REPLACEMENTS = {
    '第 1 步：导入 \\(client.name) 模块': 'الخطوة 1: استيراد وحدة \\(client.name)',
    '打开 \\(client.name)': 'فتح \\(client.name)',
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
    '操作到第 3 步时关机重启，开机后从第 4 步继续。这样能彻底清除系统缓存的定位数据。': 'إذا لم يعمل التغيير، أعد تشغيل الآيفون بعد الخطوة 3 ثم أكمل من الخطوة 4. يساعد ذلك على مسح بيانات الموقع المخزنة مؤقتًا في النظام.',
    '操作到第 3 步时关机重启，开机后从第 4 步继续。': 'إذا لم يتم الإلغاء، أعد تشغيل الآيفون بعد الخطوة 3 ثم أكمل من الخطوة 4.',
    'إيقاف الموقع الافتراضي后，需要手动移除 WiFi 代理配置，否则可能无法上网。\\n\\n1. 打开「الإعدادات → 无线局域网」\\n2. 点击当前 WiFi 右侧 (i) 图标\\n3. 找到「HTTP 代理」\\n4. 选择「إغلاق」\\n5. 点右上角「存储」': 'بعد إيقاف الموقع الافتراضي، أزل إعداد بروكسي Wi‑Fi يدويًا حتى لا يتأثر الاتصال بالإنترنت.\\n\\n1. افتح «الإعدادات ← Wi‑Fi»\\n2. اضغط زر (i) بجانب الشبكة الحالية\\n3. افتح «بروكسي HTTP»\\n4. اختر «إيقاف»\\n5. احفظ التغيير',
}


def apply(path: Path) -> None:
    text = path.read_text(encoding='utf-8')
    original = text
    for source, target in REPLACEMENTS.items():
        text = text.replace(source, target)
    if text != original:
        path.write_text(text, encoding='utf-8')
        print(f'Arabic final: updated {path.relative_to(ROOT)}')


def validate() -> None:
    patterns = [
        re.compile(r'(?:Text|Label|Button|Section|GroupBox|TextField)\(\s*"[^"\n]*[\u3400-\u9fff]'),
        re.compile(r'\.navigationTitle\(\s*"[^"\n]*[\u3400-\u9fff]'),
        re.compile(r'\.alert\(\s*"[^"\n]*[\u3400-\u9fff]'),
        re.compile(r'message:\s*Text\(\s*"[^"\n]*[\u3400-\u9fff]'),
    ]
    offenders = []
    for path in sorted((ROOT / 'App').glob('*.swift')):
        for lineno, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
            if any(p.search(line) for p in patterns):
                offenders.append(f'{path.relative_to(ROOT)}:{lineno}: {line.strip()}')
    if offenders:
        print('Arabic final: visible Chinese literals still remain:')
        for item in offenders[:100]:
            print('  ' + item)
        raise SystemExit(f'Arabic UI validation failed: {len(offenders)} visible Chinese literals remain')
    print('Arabic final: zero obvious Chinese literals in common SwiftUI controls')


def main() -> None:
    for path in sorted((ROOT / 'App').glob('*.swift')):
        apply(path)
    validate()


if __name__ == '__main__':
    main()
