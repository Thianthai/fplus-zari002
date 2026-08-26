# ZARI002 — Implementation Phases

ทำทีละ phase — จบ phase แล้ว push → ฝั่ง SAP pull + activate → verify → ค่อยขึ้น phase ถัดไป

สัญลักษณ์: `⬜` ยังไม่ทำ · `🟨` กำลังทำ / ส่ง code ให้แล้วรอ activate · `✅` เสร็จ

---

## Phase 0 — Repository & environment setup

| # | งาน | ฝั่ง | Status |
|---|-----|------|--------|
| 0.1 | สร้าง local repo + `.abapgit.xml` + โครง `src/` + `docs/` + `README` + `CLAUDE.md` | Claude | ✅ |
| 0.2 | Push skeleton ขึ้น GitHub | Claude | ✅ |
| 0.3 | ผูก abapGit repo กับ package `ZARI002` บน tenant | ผู้ใช้ | ⬜ |
| 0.4 | abapGit push `ZTAR_I002_PYMT`, `ZTAR_I002_ITEM`, `ZD_STATUS`, `ZE_STATUS` + `package.devc.xml` ตัวจริงกลับมา | ผู้ใช้ | ⬜ |
| 0.5 | Claude ตรวจว่าไฟล์ที่ได้มาตรงกับที่ออกแบบ แล้วอัปเดต `03_object_list.md` | Claude | ⬜ |

**Exit criteria**: pull/push ระหว่าง GitHub ↔ tenant ผ่านทั้ง 2 ทาง และเห็น table/domain/data element เป็นไฟล์ใน repo

---

## Phase 1 — Spec freeze + master data verification

| # | งาน | Status |
|---|-----|--------|
| 1.1 | ยืนยัน mandatory field list ใน `04_field_mapping.md` (ตอนนี้เป็นข้อเสนอของ Claude) | ⬜ |
| 1.2 | **Verify release state** ของ `I_CompanyCode`, `I_GLAccountInCompanyCode`, `I_Currency`, `I_PaymentMethod`, `I_Customer` บน tenant (C1 Released + Use in Cloud Development = Yes) | ⬜ |
| 1.3 | ถ้า view ตัวไหนไม่ released → หาตัวแทน หรือถอด validation ข้อนั้นออก | ⬜ |
| 1.4 | ยืนยัน format/ความหมายของ field ที่ยังคลุมเครือกับฝั่ง Salesforce: `payment_document_no`, `cheque_bankbranch`, `number_of_items` (char(3) — leading zero หรือไม่), ความสัมพันธ์ `payment_amount` กับผลรวม `amount_paid` ของ item | ⬜ |
| 1.5 | Draft `docs/05_api_spec.md` ให้ทีม Salesforce เริ่มเขียน client ได้ | ⬜ |

**Exit criteria**: field mapping + validation list นิ่ง และรู้แน่ว่า master data view ตัวไหนใช้ได้

---

## Phase 2 — Data model foundation

| # | Object | Status |
|---|--------|--------|
| 2.1 | Unique secondary index บน `ZTAR_I002_PYMT` (`client` + `salesforce_id`) | ⬜ |
| 2.2 | Message class `ZARI002` — message ทุกตัวที่ validation จะใช้ | ⬜ |
| 2.3 | Exception class `ZCX_ZARI002_ERROR` | ⬜ |

> ไม่มี data element/domain เพิ่มแล้ว — `ZD_STATUS` / `ZE_STATUS` ทำใน Phase 0
> field อื่นใช้ built-in type ตรง ๆ label ไปอยู่ที่ `@EndUserText.label` ใน CDS

**Exit criteria**: activate ผ่านทุก object · index สร้างสำเร็จ (ถ้ามี duplicate ค้างต้องเคลียร์ก่อน)

---

## Phase 3 — RAP business object (managed)

| # | Object | Status |
|---|--------|--------|
| 3.1 | Root view entity `ZR_ZARI002` (บน `ztar_i002_pymt`) + composition `_Item` | ⬜ |
| 3.2 | Child view entity `ZI_ZARI002_ITEM` + `association to parent _Payment` | ⬜ |
| 3.3 | Behavior definition `ZR_ZARI002` — `managed; strict ( 2 ); persistent table; lock master / dependent by _Payment;` early numbering UUID, etag `last_changed_at`, total etag `local_last_changed_at`, `authorization master ( global )` | ⬜ |
| 3.4 | Behavior pool `ZBP_R_ZARI002` — โครง `lhc_Payment` / `lhc_Item` เปล่า ๆ + `get_global_authorizations` | ⬜ |

**Exit criteria**: EML deep create จาก console class → row ลงครบทั้ง 2 table, `payment_uuid` ฝั่ง item ผูกถูก, admin field เติมเอง

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
