# ZARI002 — Implementation Phases

ทำทีละ phase — จบ phase แล้ว push → ฝั่ง SAP pull + activate → verify → ค่อยขึ้น phase ถัดไป

สัญลักษณ์: `⬜` ยังไม่ทำ · `🟨` กำลังทำ / ส่ง code ให้แล้วรอ activate · `✅` เสร็จ

---

## Phase 0 — Repository & environment setup

| # | งาน | ฝั่ง | Status |
|---|-----|------|--------|
| 0.1 | สร้าง local repo + `docs/` + `README` + `CLAUDE.md` | Claude | ✅ |
| 0.2 | Push ขึ้น GitHub | Claude | ✅ |
| 0.3 | ผูก abapGit repo กับ package `ZARI002` บน tenant | ผู้ใช้ | ✅ |
| 0.4 | เอา `.abapgit.xml` + `src/` ที่เขียนมือออกจาก repo เพื่อให้ SAP serialize เองเป็น baseline | Claude | ✅ |
| 0.5 | abapGit push `ZTAR_I002_PYMT`, `ZTAR_I002_ITEM`, `ZD_STATUS`, `ZE_STATUS` + `.abapgit.xml` + `package.devc.xml` ตัวจริงขึ้นมา | ผู้ใช้ | ✅ |
| 0.6 | Claude ตรวจ baseline ว่าตรงกับที่ออกแบบ แล้วอัปเดตเอกสาร | Claude | ✅ |

**Exit criteria**: pull/push ระหว่าง GitHub ↔ tenant ผ่านทั้ง 2 ทาง และเห็น table/domain/data element เป็นไฟล์ใน repo ✅

ผลตรวจ baseline (commit `c065712`): field ครบถูกต้องทั้ง 2 table — header 25 field
(input 16 ตัวตาม requirement ครบ) · item 20 field · CURR ทุกตัว reference `currency`
ในตารางตัวเองถูก · `status` ผูก `ZE_STATUS` ทั้งคู่ · `ZD_STATUS` มี fixed value ครบ 4 ค่า
· ยังไม่มี secondary index — ถูกต้อง เป็นงาน Phase 2.1

### ⚠️ Gotcha ที่เจอจริงตอน link (2026-08-27)

การ link ผ่าน ADT ขึ้น **`POST /sap/bc/adt/abapgit/repos` failed: HTTP/1.1 500 Internal Server Error**
ที่หน้า *Folder Logic selection* — แต่ **กด ignore ผ่านไปแล้ว link สำเร็จจริง** ใช้งานได้ปกติ

สาเหตุยังไม่ได้สืบถึงราก (ต้องดู short dump ทาง ADT Feed Reader → ABAP Runtime Errors)
ถ้า RICEFW ถัดไปเจออีก ให้ลองผ่านไปก่อนแล้วเช็คว่า link ติดจริงไหม อย่าเพิ่งรื้อ config

บทเรียนอีกข้อ: **อย่าเขียน `.abapgit.xml` / `package.devc.xml` เองล่วงหน้า** — ปล่อยให้ tenant
serialize ขึ้นมา แล้วค่อยเอาเอกสารวางทับ จะไม่มีปัญหา folder logic ไม่ตรงกัน

---

## Phase 1 — Spec freeze + master data verification

| # | งาน | Status |
|---|-----|--------|
| 1.1 | ยืนยัน mandatory field list ใน `04_field_mapping.md` | ✅ |
| 1.2 | **Verify release state** ของ `I_CompanyCode`, `I_GLAccountInCompanyCode`, `I_Currency`, `I_PaymentMethod`, `I_Customer`, `I_Bank_2` | ✅ ผ่านครบ ชื่อ field ตรงหมด |
| 1.3 | ถ้า view ตัวไหนไม่ released → หาตัวแทน หรือถอด validation ข้อนั้นออก | ✅ ไม่ต้องใช้ |
| 1.4 | ยืนยัน format/ความหมายของ field กับฝั่ง Salesforce | ✅ ปิดหมด ยกเว้น `cheque_bankbranch` (`04_field_mapping.md` §7.2) และรายการคำ payment method ทั้งชุด (§7.7) |
| 1.5 | Draft `docs/05_api_spec.md` ให้ทีม Salesforce เริ่มเขียน client ได้ | ✅ |

**Exit criteria**: field mapping + validation list นิ่ง และรู้แน่ว่า master data view ตัวไหนใช้ได้ ✅

### ของที่ต้องส่งต่อทีมอื่น (ไม่บล็อก Phase 2)

| # | เรื่อง | ส่งให้ใคร |
|---|---|---|
| 1.6 | `IsPaymentMethodForIncomingPayments` ติ๊กไว้แค่ `M` `N` `E` ไม่รวม `A`/`T` ที่ใช้จริง — ZARI002 ไม่เช็ค flag นี้ แต่ **ZARE002 จะ post ไม่ผ่านถ้า config ถูกต้องจริง** | ทีม FI |
| 1.7 | `I_Customer` บน tenant มีแค่ 3 ราย แต่ sample อ้างถึงอย่างน้อย 8 ราย — **บล็อก Phase 7** | ทีม FI / ผู้ดูแล tenant |
| 1.8 | โครงสร้างจริงของ `cheque_bankbranch` (bank 3 + branch 4?) | Salesforce / FI |
| 1.9 | รายการคำ payment method ทั้งชุดที่ Salesforce จะส่ง | Salesforce |

---

## Phase 2 — Data model foundation

| # | Object | Status |
|---|--------|--------|
| 2.1 | ~~Unique secondary index `ZTAR_I002_PYMT~SFI`~~ — **ต้องลบ (2026-08-28)** `salesforce_id` ซ้ำได้แล้ว | 🔴 |
| 2.2 | Message class `ZARI002` — 34 messages (`0xx` โครงสร้าง · `1xx` mandatory · `2xx` master data · `900` technical) | ✅ |
| 2.3 | Exception class `ZCX_ZARI002_ERROR` | ✅ |

> ไม่มี data element/domain เพิ่มแล้ว — `ZD_STATUS` / `ZE_STATUS` ทำใน Phase 0
> field อื่นใช้ built-in type ตรง ๆ label ไปอยู่ที่ `@EndUserText.label` ใน CDS

**Exit criteria**: activate ผ่านทุก object ✅

---

## Phase 3 — Core logic

| # | Object | Status |
|---|--------|--------|
| 3.1 | `ZIF_ZARI002_MASTER_DATA` + `ZCL_ZARI002_MASTER_DATA` | ✅ |
| 3.2 | `ZCL_ZARI002_VALIDATOR` — เปลี่ยน signature เป็น `ztar_i002_pymt` / `ztar_i002_item` · logic เดิมทั้งหมด · **31 unit test เขียวครบ** | ✅ |
| 3.3 | `ZCL_ZARI002_JSON` — parse payload + แปลงชื่อ 2 ทางด้วย `xco_cp_json` transformation · **9 unit test เขียว** | ✅ |
| 3.4 | `ZCL_ZARI002_SFDC_NOTIFY` — **draft เท่านั้น ยังไม่มี unit test** · รอ API ตัวจริงจาก SFDC (OQ-17) แล้วค่อยกลับมาทำให้จบ | 🟨 |
| 3.5 | `ZCL_ZARI002_PROCESSOR` — flow 5 ขั้น: parse → normalize → validate → save → callback | ✅ |
| 3.6 | ABAP Unit — validator 31 · json 9 · processor 9 = **49 test เขียวทั้งหมด** (notify เป็น draft ไม่มี test ตามที่ตกลง) | ✅ |

**Exit criteria**: unit test เขียวทั้งหมด ✅ — `ltc_processor` พิสูจน์ flow ทั้งเส้นแล้วโดยไม่ต้องมี console class:
บันทึกลง 2 table · `batch_id`/`currency`/`status` ถูกเติม (`sap_payment_method` ตัดออก 2026-09-18) · `gl_account` ถูก pad ·
reject แล้วไม่เหลือ row · duplicate ถูกจับ · callback ได้ 1 บรรทัดต่อ 1 item ทั้งกรณี S และ E

---

## Phase 4 — HTTP service

| # | Object | Status |
|---|--------|--------|
| 4.1 | `ZCL_ZARI002_HTTP` — handler ที่ implement `IF_HTTP_SERVICE_EXTENSION` · บางที่สุด | ✅ |
| 4.2 | HTTP Service repository object `ZARI002_INCOMING_PYMT` ผูกกับ handler + publish | ✅ |
| 4.3 | Smoke test — เปิด URL ด้วย browser (GET) **ต้องได้ `405`** พิสูจน์ว่า routing + handler ต่อกันถูก · POST จริงย้ายไป 5.4 เพราะต้องมี comm arrangement ก่อน | ✅ |
| 4.4 | บันทึก path ลง `05_api_spec.md` §2 · host + client ยังรอ Phase 5.3 (OQ-06 ยังเปิด) | ✅ |

**Exit criteria**: service ตอบสนองที่ URL ของตัวเอง ✅ (`405` จาก GET = handler ถูกเรียกจริง)
· การยิง POST จริงต้องรอ Phase 5.4 เพราะ S/4HANA Cloud เข้าถึง HTTP service จากภายนอก
ผ่าน communication arrangement เท่านั้น

---

## Phase 5 — Security & connectivity

| # | งาน | ฝั่ง | Status |
|---|-----|------|--------|
| 5.1 | Communication Scenario **inbound** `ZCS_INCOMING_PYMT` ผูก inbound service `ZARI002_INCOMING_PYMT_HTTP` | ผู้ใช้ | ✅ |
| 5.2 | Communication Scenario **outbound** `ZCS_PAYMENT_RESULT` + Outbound Service `ZARI002_PAYMENT_RESULT_REST` — OAuth 2.0 client credentials | ผู้ใช้ (ADT) | ✅ 2026-09-17 |
| 5.3 | Communication System `SBPA_DEV` / User `SBPA_DEV` / Arrangement `ZCS_INCOMING_PYMT` บน **IA5/100** | ผู้ใช้ (Fiori) | ✅ |
| 5.4 | ~~Business role ให้ `SBPA_DEV`~~ — **แก้ด้วยวิธีอื่นแล้ว 2026-09-04** ใช้ `WITH PRIVILEGED ACCESS` ใน `ZCL_ZARI002_MASTER_DATA` ข้าม DCL ไปเลย ไม่ต้องขอ role · เหตุผล: มีแต่ SBPA เรียก ไม่ใช่ user จริง | — | ✅ |
| 5.5 | ทดสอบ inbound จาก Postman นอก tenant | ร่วมกัน | 🟨 ยิงถึงแล้ว รอ 5.4 |
| 5.6 | ทดสอบยิงผลกลับไป SFDC — auth ✅ · data API ✅ ยิงจริงได้ `201` ผล ลง HDRLOG | ร่วมกัน | ✅ 2026-09-17 |

### ผลทดสอบครั้งแรกจาก Postman — 2026-08-31

`400` พร้อม error 3 ข้อ · **ทุกชั้นทำงานถูกหมด** — auth, routing, parse, validation,
serialize response (`Field` / `Item` / ข้อความจาก message class)

| Error | ความหมาย |
|---|---|
| `010` | ✅ **ถูกต้อง** — เจอ row จาก `ZCL_ZARI002_SPIKE_EML` ที่ค้างอยู่บน client 100 (`1000000001` / `0090000000`) |
| `201` `205` | 🔴 **สิทธิ์ของ `SBPA_DEV`** ไม่ใช่ข้อมูลไม่มี — spike ยืนยันแล้วว่าทั้งคู่มีจริงบน client 100 |

**หลักฐานว่าเป็นเรื่องสิทธิ์**: ไม่มี error `200` แปลว่า `I_CompanyCode` อ่านได้ (currency ถูก derive)
แต่ `I_GLAccountInCompanyCode` กับ `I_Customer` คืนค่าว่าง — ถ้าเป็นปัญหา client หรือการเชื่อมต่อ
ทั้ง 3 view จะพังพร้อมกัน

⚠️ **งานนี้มี 2 ทิศทาง** ต่างจากตอนเป็น OData ที่มีแค่ขาเข้า — outbound ต้องมี destination
ของตัวเองเพื่อให้ `cl_http_destination_provider` หาปลายทางเจอ

**Exit criteria**: **SBPA** ยิงเข้ามาได้จริงและได้ response ที่ถูกต้อง · และผลกลับไปถึง SFDC จริง

---

## Phase 5A — Log & Monitor (เพิ่ม 2026-09-15 · เสร็จ 2026-09-16)

ฟีเจอร์ที่เพิ่มหลังวางแผน — เก็บ log ทุก payment ที่ยิงเข้ามา (ผ่านและตก) + monitor UI ตามแบบ ZSDE002

| # | งาน | Status |
|---|-----|--------|
| 5A.1 | Table 3 ตัว `HDRLOG` `ITMLOG` `MSGLOG` — MSGLOG เพิ่ม `salesforce_item_id` เหนือกว่า ZSDE002 | ✅ |
| 5A.2 | CDS 6 + metadata extension 3 + BDEF 2 + behavior pool | ✅ |
| 5A.3 | Service definition + binding + publish | ✅ |
| 5A.4 | `save_log( )` ใน processor — หลัง save ก่อน callback · LUW แยก · ล้มไม่กระทบ request | ✅ |
| 5A.5 | Fiori app + IAM app + business catalog (wizard) | ✅ |
| 5A.6 | Test 3 ตัว บน `cl_osql_test_environment` | ✅ |
| 5A.7 | ยิงจริงจาก Postman แล้วเปิด monitor เห็นข้อมูล | ✅ |

**บทเรียนที่จดไว้**

- **`strict ( 2 )` บังคับ `authorization master/dependent` ทุก entity** — read-only BO ก็ต้องมี behavior pool ที่มี `get_global_authorizations` ว่าง ๆ ตัดไม่ได้
- **BDEF managed ที่ CDS ใช้ CamelCase ต้องมี `mapping for <table>` ทุก entity** ไม่งั้นติด warning ที่ **transport ไม่ผ่าน** · ZSDE002 ยังไม่มี ต้องกลับไปเติมก่อน transport
- **key UUID ต้อง `numbering : managed`** แม้ไม่มี `create` — framework ถามว่า key เกิดมายังไง
- request ที่ไม่มี payment (`012` `013`) **ไม่ถูก log** — ตกลงตาม ZSDE002

**Exit criteria**: ยิงเข้ามาแล้วเห็นใน monitor ทั้งใบผ่านและใบตก ✅

---

## Phase 6 — Test & hardening → **ข้าม (2026-09-16)**

**ตัดสินใจไม่ทำเป็น phase แยก** — functional team กับ SBPA เทสจริงร่วมกันบน tenant มาระยะหนึ่งแล้ว
ให้ผลที่ตรงกว่า test plan ที่เขียนล่วงหน้า · งานของเราคือ **รับ issue จากการเทสมาแก้** ทีละเรื่อง
(แบบเดียวกับ `SalesforceId` ว่างบน error ระดับ header ที่เจอและแก้ไปเมื่อ 2026-09-15)

สิ่งที่ยังคุมอยู่: **unit test 33 ตัว / 3 class** รันทุกครั้งที่แก้ code · เขียวหมด

ของใน Phase 6 เดิมที่**ไม่ใช่การเทส**และยังต้องทำ ย้ายไป Phase 7:

| เดิม | ไปอยู่ที่ | เหตุผล |
|---|---|---|
| 6.11 ATC check | **7.7** | เป็น gate ของ transport ไม่ใช่ test — จะติด `SPIKE` / `UTIL` แน่ ต้องลบก่อน (7.6) |
| 6.8 Volume test | — ไม่ทำ | OQ-07 ตอบจากการใช้จริงแทน |

---

## Phase 7 — Documentation & handover

| # | งาน | Status |
|---|-----|--------|
| 7.1 | `docs/05_api_spec.md` ฉบับสมบูรณ์ + payload/response ตัวจริง | ⬜ |
| 7.2 | `docs/06_deployment.md` — comm arrangement ทั้ง 2 ทาง | ⬜ |
| 7.3 | Troubleshooting guide — รวมเคส OQ-14 (ใบที่ post ไม่ผ่านส่งซ้ำไม่ได้) และเคส callback ล้ม | ⬜ |
| 7.4 | Technical spec สำหรับ RICEFW document | ⬜ |
| 7.5 | ส่งมอบ contract ของ table ให้ทีม **ZARE002** | ⬜ |
| 7.6 | 🔴 **ลบ `ZCL_ZARI002_SPIKE` และ `ZCL_ZARI002_UTIL`** — utility ชั่วคราวที่ SBPA ใช้เคลียร์ข้อมูลระหว่างเทส · `DELETE` ตรง ๆ ห้ามหลุดไปกับของส่งมอบ · **ต้องทำก่อน 7.7** | ⬜ |
| 7.7 | 🔴 **ATC check** (Clean Core / released API) ผ่านหมด — gate ก่อน transport · ย้ายมาจาก 6.11 | ⬜ |
