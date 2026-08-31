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
บันทึกลง 2 table · `batch_id`/`currency`/`status`/`sap_payment_method` ถูกเติม · `gl_account` ถูก pad ·
reject แล้วไม่เหลือ row · duplicate ถูกจับ · callback ได้ 1 บรรทัดต่อ 1 item ทั้งกรณี S และ E

---

## Phase 4 — HTTP service

| # | Object | Status |
|---|--------|--------|
| 4.1 | `ZCL_ZARI002_HTTP` — handler ที่ implement `IF_HTTP_SERVICE_EXTENSION` · บางที่สุด | ⬜ |
| 4.2 | HTTP Service repository object ผูกกับ handler | ⬜ |
| 4.3 | ทดสอบยิง POST จากใน tenant | ⬜ |
| 4.4 | บันทึก URL จริงลง `05_api_spec.md` §2 (ปิด OQ-06) | ⬜ |

**Exit criteria**: POST payload จริงเข้ามาแล้วข้อมูลลง table · payload ผิดได้ error กลับไปครบทุกข้อ

---

## Phase 5 — Security & connectivity

| # | งาน | ฝั่ง | Status |
|---|-----|------|--------|
| 5.1 | Communication Scenario **inbound** ผูก HTTP service | Claude + ผู้ใช้ | ⬜ |
| 5.2 | Communication Scenario **outbound** สำหรับยิง callback ไป SFDC | Claude + ผู้ใช้ | ⬜ |
| 5.3 | Communication System / User / Arrangement ทั้ง 2 ทาง | ผู้ใช้ (Fiori) | ⬜ |
| 5.4 | ทดสอบ inbound จาก Postman นอก tenant | ร่วมกัน | ⬜ |
| 5.5 | ทดสอบ outbound callback ไปปลายทางจริง (รอ SFDC ทำ API) | ร่วมกัน | ⬜ |

⚠️ **งานนี้มี 2 ทิศทาง** ต่างจากตอนเป็น OData ที่มีแค่ขาเข้า — outbound ต้องมี destination
ของตัวเองเพื่อให้ `cl_http_destination_provider` หาปลายทางเจอ

**Exit criteria**: SFDC ยิงเข้ามาได้จริง และเรายิง callback ออกไปได้จริง

---

## Phase 6 — Test & hardening

| # | งาน | Status |
|---|-----|--------|
| 6.1 | Positive: 1 header/1 item · 1 header/N item · optional field ว่าง | ⬜ |
| 6.2 | Negative — format: mandatory ขาด, type ผิด, วันที่ผิดรูป, JSON พัง | ⬜ |
| 6.3 | Negative — consistency: `number_of_items_in_payment` ไม่ตรง, `salesforce_item_id` ซ้ำ, ไม่มี item | ⬜ |
| 6.4 | Negative — master data: company code / GL / payment method / customer ไม่มีจริง | ⬜ |
| 6.5 | **Duplicate**: ส่งชุดเดิมซ้ำ → ได้ message `010` ครบทุกบรรทัด | ⬜ |
| 6.6 | **Rollback**: item ใบเดียวผิด → ต้องไม่มี row ค้างทั้ง 2 table | ⬜ |
| 6.7 | **Callback**: ยิงถูกทั้งกรณี S และ E · ปลายทางล่มแล้ว request หลักต้องไม่พัง | ⬜ |
| 6.8 | Volume test — หาจำนวน item/call ที่ปลอดภัย (ปิด OQ-07) | ⬜ |
| 6.9 | ATC check (Clean Core / released API) ผ่านหมด | ⬜ |

---

## Phase 7 — Documentation & handover

| # | งาน | Status |
|---|-----|--------|
| 7.1 | `docs/05_api_spec.md` ฉบับสมบูรณ์ + payload/response ตัวจริง | ⬜ |
| 7.2 | `docs/06_deployment.md` — comm arrangement ทั้ง 2 ทาง | ⬜ |
| 7.3 | Troubleshooting guide — รวมเคส OQ-14 (ใบที่ post ไม่ผ่านส่งซ้ำไม่ได้) และเคส callback ล้ม | ⬜ |
| 7.4 | Technical spec สำหรับ RICEFW document | ⬜ |
| 7.5 | ส่งมอบ contract ของ table ให้ทีม **ZARE002** | ⬜ |
