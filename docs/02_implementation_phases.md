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
| 2.1 | Unique secondary index `ZTAR_I002_PYMT~SFI` (`client` + `salesforce_id`) | ✅ |
| 2.2 | Message class `ZARI002` — 34 messages (`0xx` โครงสร้าง · `1xx` mandatory · `2xx` master data · `900` technical) | ✅ |
| 2.3 | Exception class `ZCX_ZARI002_ERROR` | ✅ |

> ไม่มี data element/domain เพิ่มแล้ว — `ZD_STATUS` / `ZE_STATUS` ทำใน Phase 0
> field อื่นใช้ built-in type ตรง ๆ label ไปอยู่ที่ `@EndUserText.label` ใน CDS

**Exit criteria**: activate ผ่านทุก object · index สร้างสำเร็จ ✅ — รีวิวทะเบียนข้อสงสัยแล้ว ไม่มีข้อใหม่จาก Phase 2

---

## Phase 3 — RAP business object (managed)

| # | Object | Status |
|---|--------|--------|
| 3.1 | Root view entity `ZR_ZARI002` (บน `ztar_i002_pymt`) + composition `_Item` | ✅ |
| 3.2 | Child view entity `ZI_ZARI002_ITEM` + `association to parent _Payment` | ✅ |
| 3.3 | Behavior definition `ZR_ZARI002` — `managed; strict ( 2 ); persistent table; lock master / dependent by _Payment;` early numbering UUID, `etag master LocalLastChangedAt`, `authorization master ( global )` · **ไม่มี `total etag`** เพราะไม่มี draft | ✅ |
| 3.4 | Behavior pool `ZBP_R_ZARI002` — `lhc_Payment` (16 method) / `lhc_Item` (5 method) generate จาก BDEF | ✅ |

**Exit criteria**: EML deep create จาก console class → row ลงครบทั้ง 2 table, `payment_uuid` ฝั่ง item ผูกถูก, admin field เติมเอง ✅

ผลทดสอบ 2026-08-28 (`ZCL_ZARI002_SPIKE_EML`): MODIFY + COMMIT ผ่าน · header 1 row + item 2 row
· `payment_uuid` ของ item ทั้งสองตรงกับ header (`FA163E19…2234F`) · `item_uuid` ต่างกัน
· admin field ครบทุกตัวรวม `last_changed_at` · `currency` / `sap_payment_method` / `status`
ว่างเปล่าตามที่คาด เพราะ determination ยังไม่มี logic

---

## Phase 4 — Determination, validation + ABAP Unit

| # | Object | Status |
|---|--------|--------|
| 4.1 | `ZIF_ZARI002_MD_CHECK` + `ZCL_ZARI002_MD_CHECK` — อ่าน master data (mock ได้ใน test) | ⬜ |
| 4.2 | `ZCL_ZARI002_VALIDATOR` — logic กลุ่ม A (format/mandatory/consistency) ทั้งหมด | ⬜ |
| 4.3 | Determination `setInitialStatus`, `setItemDefaults` ใน `ZBP_R_ZARI002` | ⬜ |
| 4.4 | Validation กลุ่ม A + B ใน `ZBP_R_ZARI002` (เรียก class ข้างบน) | ⬜ |
| 4.5 | ABAP Unit — validator/md_check ครบทุก branch + BO test ด้วย `cl_abap_behv_test_environment` | ⬜ |

**Exit criteria**: unit test เขียวทั้งหมด · deep create ที่ข้อมูลผิดถูก reject พร้อม message ครบทุกข้อในรอบเดียว · rollback ไม่เหลือ row ค้าง

---

## Phase 5 — Service exposure

| # | Object | Status |
|---|--------|--------|
| 5.1 | Projection view `ZC_ZARI002` / `ZC_ZARI002_ITEM` (เปิดเฉพาะ field ที่เป็น API contract) | ⬜ |
| 5.2 | Behavior projection `ZC_ZARI002` — `use create;` เท่านั้น | ⬜ |
| 5.3 | Service definition `ZAPI_ZARI002` — `expose ZC_ZARI002 as Payment; expose ZC_ZARI002_ITEM as PaymentItem;` | ⬜ |
| 5.4 | Service binding `ZAPI_ZARI002_O4` (OData V4 Web API / A2X) + publish | ⬜ |
| 5.5 | ทดสอบ `$metadata` + POST nested payload ผ่าน ADT preview ในระบบ | ⬜ |
| 5.6 | บันทึก URL + payload ตัวจริงลง `docs/05_api_spec.md` | ⬜ |

**Exit criteria**: deep insert `POST /Payment` พร้อม `_Item[]` สำเร็จจากในระบบ และ error case ตอบ 400 พร้อม message ที่อ่านรู้เรื่อง

---

## Phase 6 — Security & connectivity

| # | งาน | ฝั่ง | Status |
|---|-----|------|--------|
| 6.1 | Communication Scenario `ZARI002_CSCEN` (inbound) ผูก service binding | Claude + ผู้ใช้ | ⬜ |
| 6.2 | Communication System + Communication User | ผู้ใช้ (Fiori app) | ⬜ |
| 6.3 | Communication Arrangement | ผู้ใช้ | ⬜ |
| 6.4 | Business role / catalog ให้ comm user | ผู้ใช้ | ⬜ |
| 6.5 | ทดสอบยิงจาก Postman นอก tenant | ร่วมกัน | ⬜ |

**Exit criteria**: Salesforce (หรือ Postman แทน) ยิงเข้ามาบันทึกข้อมูลได้จริงจากนอกระบบ

---

## Phase 7 — Test & hardening

| # | งาน | Status |
|---|-----|--------|
| 7.1 | Positive: 1 header/1 item · 1 header/N item · ทุก optional field ว่าง | ⬜ |
| 7.2 | Negative — format: mandatory ขาด, type ผิด, จำนวนเงินติดลบ, วันที่ผิดรูป | ⬜ |
| 7.3 | Negative — consistency: `number_of_items` ไม่ตรง, `salesforce_item_id` ซ้ำกันเองใน payment, ไม่มี item เลย | ⬜ |
| 7.4 | Negative — master data: company code / GL account / currency / payment method / customer ไม่มีจริง | ⬜ |
| 7.5 | **Idempotency**: ยิง `salesforce_id` เดิมซ้ำ → 400 · ยิงพร้อมกัน 2 request → ต้องเข้าได้ใบเดียว | ⬜ |
| 7.6 | **Rollback**: item ใบกลางผิด → ต้องไม่มี row ค้างทั้ง header และ item | ⬜ |
| 7.7 | Volume test — หาจำนวน item/call ที่ปลอดภัย แล้วกำหนด limit ใน API spec | ⬜ |
| 7.8 | ATC check (Clean Core / released API) ผ่านหมด | ⬜ |

---

## Phase 8 — Documentation & handover

| # | งาน | Status |
|---|-----|--------|
| 8.1 | `docs/05_api_spec.md` ฉบับสมบูรณ์ — endpoint, auth, payload/response ตัวอย่าง, error code ทุกตัว, limit | ⬜ |
| 8.2 | `docs/06_deployment.md` — ขั้นตอน communication arrangement + การ deploy ไประบบอื่น | ⬜ |
| 8.3 | Troubleshooting guide — request ที่ถูก reject ไม่เหลือร่องรอยฝั่ง SAP ต้องเขียนให้ชัดว่าสืบจากที่ไหน | ⬜ |
| 8.4 | Technical spec สำหรับ RICEFW document | ⬜ |
| 8.5 | ส่งมอบ contract ของ table ให้ทีม **ZARE002** | ⬜ |
