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

Widget tests มีภาพอ้างอิงใน `test/goldens/` สำหรับหน้าจอสำคัญ หากตั้งใจปรับดีไซน์ให้ใช้ `flutter test --update-goldens` แล้วตรวจภาพใหม่ก่อนยอมรับ

## โครงสร้างและข้อมูล

- `lib/app`: GoRouter, theme และ design tokens
- `lib/core`: SQLite schema/migrations, formatters, error handling และ reusable widgets
- `lib/features/debt`: debt repository, summary/domain logic, Riverpod providers และหน้าจอ
- `lib/features/payment`: payment repository, ประวัติ และ bottom sheets

จำนวนเงินจัดเก็บและคำนวณเป็น integer satang; `0.01` บาทคือ `1` สตางค์ ไม่มี floating-point ในการรวมยอด ยอดรวม/ยอดคงเหลือคำนวณจากรายการจ่าย ไม่เก็บเป็นค่าที่เปลี่ยนแยกกันได้ การเขียนข้อมูลใช้ transaction และตรวจยอดคงเหลือภายใน transaction เพื่อป้องกันการจ่ายเกินยอด การส่งซ้ำใช้ shared action lock

SQLite schema version 1 เปิด foreign keys และมี index ตามหนี้/วันที่ Data model รองรับหลายหนี้ แต่ repository ป้องกันการสร้างหนี้ที่สองตามขอบเขต MVP Timestamp เป็น UTC และวันที่จ่ายเป็น local date-only (`YYYY-MM-DD`) หน้าจอแสดงวันที่ภาษาไทย/พ.ศ.

ไม่มีแก้ไข/ลบหนี้ แก้ไขรายการจ่าย cloud sync หรือ backup ในรุ่นนี้ Web และ desktop ไม่ใช่เป้าหมายของ MVP นี้

Kanit: SIL Open Font License — ดู `assets/fonts/OFL.txt`
