# iPhone Security Checker

تطبيق Flutter لفحص مؤشرات اختراق/تجسس على iPhone بشكل محلي.

## الميزات

- فحص مؤشرات كسر الحماية (Jailbreak) متعدد الطبقات.
- تحليل الشبكة: VPN, Proxy, DNS, SSID heuristics.
- فحص صلاحيات حساسة + Config Profiles + حالة MDM.
- تقرير PDF قابل للمشاركة.
- مراقبة دورية تلقائية (Quick Scan) مع حفظ آخر نتيجة.

## تشغيل محلي

```bash
flutter pub get
flutter run
```

## بناء iOS عبر Codemagic

الملف الصحيح للتثبيت هو:

- `iphone_security_checker_unsigned.ipa`

مهم: لا تستخدم `Runner.app.zip` على ويندوز ثم تعيد ضغطه يدوياً إلى IPA، لأن ذلك قد يفسد صلاحيات التنفيذ داخل الحزمة ويسبب كراش عند فتح التطبيق.
