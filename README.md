# เงินบิล — NgenBills 🌱

แอป Flutter สำหรับติดตามหนี้หนึ่งก้อน ใช้งานออฟไลน์ ไม่มีบัญชีผู้ใช้หรือ backend ข้อมูลหนี้และรายการจ่ายเก็บใน SQLite ภายในอุปกรณ์ ฟอนต์ Kanit รวมไว้ในแอปแล้ว

MVP Phase 1–3: เพิ่มหนี้ ดูยอดคงเหลือและกราฟครึ่งวงกลม บันทึกการจ่ายพร้อมวันที่และหมายเหตุ ดูประวัติ/รายละเอียด ลบหลังยืนยัน และแสดงสถานะชำระครบ 100% รองรับ Android และ iOS ภาษาไทย

## เริ่มใช้งาน

ต้องติดตั้ง Flutter stable ที่รองรับ Dart 3.13.5 หรือใหม่กว่า พร้อม Android SDK หรือ Xcode

```sh
flutter pub get
flutter run -d <device-id>
```

Android application ID และ iOS bundle identifier: `com.gasnontachai.ngenbills`

## ตรวจสอบ

```sh
flutter analyze
flutter test
flutter build apk --debug
flutter test integration_test/app_flow_test.dart -d <android-device-id>
```

Integration test ใช้ฐานข้อมูลทดสอบแยกไฟล์และลบหลังจบ ไม่แก้ข้อมูลจริงของแอป ทดสอบสร้างหนี้ จ่ายบางส่วน เปิด SQLite และสร้าง app state ใหม่ ลบรายการ จ่ายครบ และลบเพื่อกลับสู่สถานะยังมีหนี้

Widget tests มีภาพอ้างอิงใน `test/goldens/` สำหรับหน้าจอสำคัญ หากตั้งใจปรับดีไซน์ให้ใช้ `flutter test --update-goldens` แล้วตรวจภาพใหม่ก่อนยอมรับ ภาพ baseline ของ macOS อยู่ใน `test/goldens/` และของ Linux runner อยู่ใน `test/goldens/linux/` เพื่อเปรียบเทียบกับ renderer ของระบบเดียวกัน

## โครงสร้างและข้อมูล

- `lib/app`: GoRouter, theme และ design tokens
- `lib/core`: SQLite schema, formatters, error handling และ reusable widgets
- `lib/features/debt`: debt repository, summary/domain logic, Riverpod providers และหน้าจอ
- `lib/features/payment`: payment repository, ประวัติ และ bottom sheets

จำนวนเงินจัดเก็บและคำนวณเป็น integer satang; `0.01` บาทคือ `1` สตางค์ ไม่มี floating-point ในการรวมยอด ยอดรวม/ยอดคงเหลือคำนวณจากรายการจ่าย ไม่เก็บเป็นค่าที่เปลี่ยนแยกกันได้ การเขียนข้อมูลใช้ transaction และตรวจยอดคงเหลือภายใน transaction เพื่อป้องกันการจ่ายเกินยอด การส่งซ้ำใช้ shared action lock

SQLite schema version 1 รวมตารางหนี้ รายการจ่าย และการแจ้งเตือนใน schema เริ่มต้นเดียว เปิด foreign keys และมี index ตามหนี้/วันที่ Data model รองรับหลายหนี้ แต่ repository ป้องกันการสร้างหนี้ที่สองตามขอบเขต MVP Timestamp เป็น UTC และวันที่จ่ายเป็น local date-only (`YYYY-MM-DD`) หน้าจอแสดงวันที่ภาษาไทย/พ.ศ.

ช่วงก่อนขึ้น production นี้ใช้ฐานข้อมูลเริ่มต้นใหม่ ไม่มี migration จาก build ทดลองก่อนหน้า หากเคยติดตั้ง build เดิม ต้องล้างข้อมูลแอปหรือติดตั้งใหม่โดยลบข้อมูลเดิมก่อน (ข้อมูลหนี้และรายการจ่ายบนเครื่องนั้นจะถูกลบ) เมื่อเริ่ม release ที่มีผู้ใช้จริง ให้เพิ่ม migration เมื่อเปลี่ยน schema

ไม่มีแก้ไข/ลบหนี้ แก้ไขรายการจ่าย cloud sync หรือ backup ในรุ่นนี้ Web และ desktop ไม่ใช่เป้าหมายของ MVP นี้

Kanit: SIL Open Font License — ดู `assets/fonts/OFL.txt`


## Android signing และ GitHub CI/CD

- `ci.yml`: เมื่อ push หรือเปิด PR เข้า `main`/`dev` จะตรวจ release tooling, `flutter analyze` และ `flutter test`
- `android-release.yml`: เมื่อ push tag `vMAJOR.MINOR.PATCH` ที่อยู่บน `main` จะทดสอบ สร้าง signed release APK ตรวจลายเซ็น และเผยแพร่ GitHub Release พร้อม SHA256 checksum
- เวอร์ชัน release มาจาก tag; build number มาจาก workflow run number + repository variable `ANDROID_BUILD_NUMBER_OFFSET` (ค่าเริ่มต้น `1`)

Signing ใช้ release key ของ NgenBills โดยเฉพาะ ไม่มี fallback ไปใช้ debug key หากตั้งค่าไม่ครบ release build จะหยุด

Local signing ใช้ `android/key.properties` และ `android/keystores/ngenbills-release.jks` ซึ่งถูก ignore ไว้ และจำกัดสิทธิ์การอ่านเฉพาะเจ้าของ ดูรูปแบบค่าได้ใน `android/key.properties.example` **สำรองไฟล์จริงทั้งสองไว้ในที่เก็บที่ปลอดภัย และใช้ key เดิมสำหรับอัปเดตแอป** ห้าม commit ไฟล์จริงหรือใส่รหัสผ่านใน workflow

GitHub repository ต้องมี encrypted Actions secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

สร้าง signed APK ในเครื่อง:

```sh
flutter build apk --release
```

เมื่อต้องการเผยแพร่ release หลัง CI ผ่าน:

```sh
git tag v1.0.0
git push origin v1.0.0
```

เปลี่ยน tag ตามเวอร์ชันใหม่ที่จะเผยแพร่ ไม่ใช้ tag เดิมซ้ำ Pipeline นี้รองรับ Android; iOS/TestFlight signing ยังไม่ได้ตั้งค่า
