# ZARI002 — Field Mapping

API field ↔ table field · **JSON ใช้ CamelCase · table ใช้ snake_case**

การแปลงชื่อทั้ง 2 ทาง (parse ขาเข้า · error response ขาออก) อยู่ที่ `ZCL_ZARI002_JSON`
ที่เดียว — `ZCL_ZARI002_VALIDATOR` คืนชื่อ field ของ table เสมอ ไม่รู้จัก JSON

**Mand.**: `✔` = บังคับเสมอ · `(✔)` = บังคับแบบมีเงื่อนไข · `–` = optional
**I/O**: `in` = SFDC ส่งเข้ามาได้ · `out` = ระบบเติมให้ ไม่รับจาก payload (ส่งมาก็ถูกเมิน)

> ปรับใหญ่ 2026-08-28 ตามโครงสร้าง table ฉบับแก้ — ดู §6 สำหรับสรุปการเปลี่ยนแปลง

---

## 1. Header — entity set `Payment` ← `ZTAR_I002_PYMT`

| JSON field | Table field | Type | JSON type | I/O | Mand. | หมายเหตุ |
|---|---|---|---|---|---|---|
| `PaymentUuid` | `payment_uuid` | `sysuuid_x16` | `Guid` | out | – | Key — RAP gen |
| `RequestId` | `request_id` | `char(30)` | `String(30)` | in | – | **SFDC เป็นเจ้าของ** · ไม่ส่งมา SAP สร้างให้รูปแบบ `YYYYMMDD_hhmmss` เป็นเวลาไทย · อยู่ระดับ request ไม่ใช่ระดับ payment · ขยาย 25 → 30 เมื่อ 2026-10-09 · **ยาวเกิน 30 ถูกตัดท้ายเงียบ ๆ ไม่มี error** |
| `SalesforceId` | `salesforce_id` | `char(18)` | `String(18)` | in | ✔ | key ฝั่ง SFDC · **ซ้ำได้** ไม่ใช่ตัวกัน duplicate |
| `PaymentDocumentNo` | `payment_document_no` | `char(10)` | `String(10)` | in | ✔ | เลขที่เอกสารรับชำระเงินฝั่ง SFDC · **เป็นส่วนหนึ่งของ duplicate key** |
| `NumberOfItemsInPayment` | `number_of_items_in_payment` | `int4` | `Int32` | in | ✔ | จำนวนนับ ส่งเป็นตัวเลข · ต้องเท่ากับจำนวน `Items` |
| `CompanyCode` | `company_code` | `char(4)` | `String(4)` | in | ✔ | ต้องมีจริงใน SAP |
| `PostingDate` | `posting_date` | `dats` | `Date` | in | ✔ | |
| `GlAccount` | `gl_account` | `char(10)` | `String(10)` | in | ✔ | **เดิม `GLAccount`** เปลี่ยน 2026-08-31 เพราะตัวใหญ่ติดกันทำให้กฎแปลงชื่อแตก · ส่งแบบไม่มี leading zero ได้ — SAP pad ให้ (§4.1) |
| `PaymentMethod` | `payment_method` | `char(20)` | `String(20)` | in | ✔ | `<ประเภทการขาย>-<วิธีจ่าย>` เช่น `CA-Cash` `CR-Cheque` (§4.2) · ขยาย 8 → 20 เมื่อ 2026-10-20 |
| `ChequeNo` | `cheque_no` | `char(8)` | `String(8)` | in | (✔) | บังคับเมื่อจ่ายด้วยเช็ค |
| `IssueDate` | `issue_date` | `dats` | `Date` | in | (✔) | บังคับเมื่อจ่ายด้วยเช็ค |
| `DueOn` | `due_on` | `dats` | `Date` | in | (✔) | บังคับเมื่อจ่ายด้วยเช็ค · ต้องไม่ก่อน `IssueDate` |
| `ChequeBankBranch` | `cheque_bank_branch` | `char(15)` | `String(15)` | in | (✔) | บังคับเมื่อจ่ายด้วยเช็ค · validate กับ `I_Bank_2-BankInternalID` (CHAR 15 เท่ากัน) · **ไม่ pad** — field ไม่มี conversion routine |
| `Currency` | `currency` | `cuky` | `String(5)` | out | – | ดึงจาก `I_CompanyCode` เสมอ (ธุรกิจใช้สกุลเดียว) |
| `RoundingDiff` | `rounding_diff` | `curr(23,2)` | `Decimal` | in | – | ติดลบได้ |
| `AdvancePayment` | `advance_payment` | `curr(23,2)` | `Decimal` | in | – | ติดลบได้ |
| `Fees` | `fees` | `curr(23,2)` | `Decimal` | in | – | |
| `PaymentAmount` | `payment_amount` | `curr(23,2)` | `Decimal` | in | ✔ | มี `check_payment_total` เป็นที่ว่างไว้ (OQ-05) |
| `Status` | `status` | `ze_request_status` | `String(1)` | out | – | **transaction status** — ZARI002 set `N` เท่านั้น |
| `SalesforceStatus` | `salesforce_status` | `ze_response_status` | `String(1)` | out | – | **result status ที่ส่งกลับ SFDC** — ZARI002 ปล่อยว่างเสมอ |
| `SalesforceMessage` | `salesforce_message` | `char(200)` | `String(200)` | out | – | ข้อความคู่กับ `SalesforceStatus` — ZARI002 ปล่อยว่างเสมอ |
| — | `payment_accounting_document` | `char(10)` | — | — | – | **ของ ZARE002** (เพิ่ม 2026-09-22 `08c105c`) เลข JE ที่ Submit post · ZARI002 ไม่เขียน |
| — | `clearing_accounting_document` | `char(10)` | — | — | – | **ของ ZARE002** เลข clearing ที่ BOT ส่งกลับ · ZARI002 ไม่เขียน |
| — | `payment_fiscal_year` | `numc(4)` | — | — | – | **ของ ZARE002** (เพิ่ม 2026-09-24) ปีบัญชีของ JE · เลขเอกสาร unique แค่กับ company + ปี |
| — | `clearing_fiscal_year` | `numc(4)` | — | — | – | **ของ ZARE002** ปีบัญชีของเอกสาร clearing (BOT ส่งมา) |
| — | `submit_message` | `char(200)` | — | — | – | **ของ ZARE002** ข้อความล่าสุดของขั้น Submit (คนละช่องกับ `salesforce_message`) · ZARI002 ไม่เขียน |
| — | `clearing_message` | `char(200)` | — | — | – | **เขียนโดย ZARI003** (API #3 ย้ายจาก ZARE002 2026-09-28) ข้อความของขั้น clearing จาก BOT · แยกจาก `submit_message` และ `salesforce_message` |
| — | `reject_batch_id` | `char(25)` | — | — | – | **ของ ZARE002** (เพิ่ม 2026-09-29 `44b5281` · อยู่ต่อจาก `clearing_fiscal_year`) เลข `YYYYMMDD_hhmmss` เวลาไทย ทุกใบที่ Reject ในการกดครั้งเดียวได้เลขเดียวกัน · ส่งเป็น `BST_SAP_BatchId__c` ไป SFDC และส่งให้ SBPA |
| — | `reject_message` | `char(200)` | — | — | – | **ZARE002 เขียนก่อน** (ข้อความ Reject สำเร็จ) แล้ว **ZARI003 เขียนทับ** ด้วยผลการแจ้ง SBPA (bgPF หลัง commit) · เพิ่ม 2026-09-29 `44b5281` |
| `CreatedBy` `CreatedAt` `LastChangedBy` `LastChangedAt` `LocalLastChangedAt` | admin fields | | | out | – | managed · `LocalLastChangedAt` = etag |
| `Items` | — | array | array | in | ✔ | ต้องมีอย่างน้อย 1 รายการ |

**Input field: 15** — `SalesforceId` `PaymentDocumentNo` `NumberOfItemsInPayment` `CompanyCode`
`PostingDate` `GlAccount` `PaymentMethod` `ChequeNo` `IssueDate` `DueOn` `ChequeBankBranch`
`RoundingDiff` `AdvancePayment` `Fees` `PaymentAmount`

**Mandatory 8** · **conditional 4** (กรณีเช็ค) · **optional 3**

## 2. Item — entity set `PaymentItem` ← `ZTAR_I002_ITEM`

| JSON field | Table field | Type | JSON type | I/O | Mand. | หมายเหตุ |
|---|---|---|---|---|---|---|
| `ItemUuid` | `item_uuid` | `sysuuid_x16` | `Guid` | out | – | Key — RAP gen |
| `PaymentUuid` | `payment_uuid` | `sysuuid_x16` | `Guid` | out | – | RAP ผูกจาก composition |
| `SalesforceItemId` | `salesforce_item_id` | `char(18)` | `String(18)` | in | ✔ | key ฝั่ง SFDC · **ซ้ำข้าม payment ได้** แต่ห้ามซ้ำกันเองใน payment เดียวกัน |
| `CustomerCode` | `customer_code` | `char(10)` | `String(10)` | in | ✔ | ต้องมีจริง · SAP pad ให้ |
| `BillingNoteNo` | `billing_note_no` | `char(10)` | `String(10)` | in | – | **Cash: บังคับ = เลข SO** (`119`) · SAP pad 10 หลักแล้วใช้หา invoice |
| `AccountingDocument` | `accounting_document` | `char(10)` | `String(10)` | in | ✔ | ต้องยังไม่ถูกรับชำระ/reverse — ที่ว่าง (OQ-08) |
| `BillingDocument` | `billing_document` | `char(10)` | `String(10)` | in | ✔ | **เป็นส่วนหนึ่งของ duplicate key** · ไม่ตรวจกับ master data |
| `InvoicePostingDate` | `invoice_posting_date` | `dats` | `Date` | in | ✔ | |
| `Currency` | `currency` | `cuky` | `String(5)` | out | – | copy จาก header |
| `InvoiceAmount` | `invoice_amount` | `curr(23,2)` | `Decimal` | in | ✔ | |
| `AmountPaid` | `amount_paid` | `curr(23,2)` | `Decimal` | in | ✔ | ผลรวมทุก item ต้อง > 0 |
| `PartialAmount` | `partial_amount` | `char(1)` | `String(1)` | in | – | **flag ไม่ใช่จำนวนเงิน** — `X` = จ่ายบางส่วน |
| `SaleSubmitDate` | `sale_submit_date` | `dats` | `Date` | in | ✔ | |
| `RejectReason` | `reject_reason` | `char(200)` | `String(200)` | out | – | **ZARI002 ไม่เคยเขียน** — เป็นของ ZARE002 |
| `CreatedBy` `CreatedAt` `LastChangedBy` `LastChangedAt` `LocalLastChangedAt` | admin fields | | | out | – | managed · **`LastChangedAt` เพิ่มเมื่อ 2026-09-10** ให้ RAP draft ของ ZARE002 ใช้ (เดิมตั้งใจไม่ใส่) |


**Input field: 10** — mandatory 8 · optional 2 (`BillingNoteNo` `PartialAmount`)

> item **ไม่มี `status` และ `error_message` แล้ว** — สถานะทั้งหมดอยู่ที่ระดับ header เท่านั้น
> error อะไรก็ตามถือเป็น error ของ payment ทั้งใบ

## 3. Duplicate check

```
ztar_i002_pymt-payment_document_no   +   ztar_i002_item-billing_document
```

ถ้าคู่นี้เคยมีอยู่แล้วใน table → reject ทั้ง request ด้วย `ZARI002/010` ไม่บันทึกอะไรเลย

**เทียบทุก `status`** ไม่กรองตามสถานะ (ตกลง 2026-08-28: *"ห้ามส่งซ้ำถ้าเคยส่งมาแล้ว"*)
→ `status` จึงอยู่ในนิยาม key แต่ไม่ได้ทำหน้าที่กรองในทางปฏิบัติ logic จริงคือเช็ค 2 field ข้างบน

> **อัปเดต 2026-10-01 (`a9fbef1`)**: นับ **`status IN ('N','S','E')`** — `E` (ZARE002 post JE ไม่ผ่าน) ยัง Submit ซ้ำได้เหมือน N จึงต้องกันส่งซ้ำ · `R` ยังส่งแก้เข้ามาใหม่ได้
>
> **อัปเดต 2026-09-29 (`12d266f`)**: logic จริงนับเป็นใบซ้ำเฉพาะ row ที่ยังไม่ปิดงาน **`status IN ('N','S')`** —
> `S` (Submitted: post JE แล้วรอ BOT clear) ต้องดักที่นี่ เพราะ JE ของ ZARE002 ไม่ได้ clear invoice ช่วงนั้น AR Open Item check จึงดักไม่ได้
> `C` (Cleared) ให้ AR Open Item check ดัก · `R` / `E` ไม่บล็อก ส่งแก้เข้ามาใหม่ได้

ตรวจ **ทีละ item** — 1 payment มีหลาย item ที่ `billing_document` ต่างกัน การเทียบเป็นคู่
`(payment_document_no, billing_document)` จึงบอกได้ว่า**บรรทัดไหน**ซ้ำ ไม่ใช่แค่ว่าใบนี้เคยมา
ส่งชุดเดิม 5 บรรทัดกลับมาซ้ำ = ได้ 5 message ในรอบเดียว แล้ว reject ทั้ง request

⚠️ **ไม่มีตาข่ายระดับ DB** — key คร่อม 2 table ทำ unique index ไม่ได้ เหลือ validation ชั้นเดียว
2 request เหมือนกันที่ยิงพร้อมกันจริง ๆ อาจหลุดเข้าไปทั้งคู่ (ยอมรับความเสี่ยงนี้แล้ว)

⚠️ **ไม่ครอบเคสซ้ำกันเองภายใน payload เดียว** (2 item ใช้ `billing_document` เดียวกัน) —
ตอน validate ยังไม่มีอะไรใน table ให้ชน · รอคำตอบทาง business ที่ **OQ-16**

⚠️ **ผลที่ตามมา**: ถ้า ZARE002 post ไม่สำเร็จ **SFDC ส่งใบเดิมเข้ามาแก้ไม่ได้** เพราะจะโดนจับเป็น
duplicate — การแก้ต้องทำฝั่ง SAP · ส่วนใบที่ถูก **reject ตั้งแต่ ZARI002** ส่งใหม่ได้ปกติ
เพราะ reject-all ไม่ได้บันทึกอะไรลง table ตั้งแต่แรก

## 4. กฎที่ client ต้องรู้

### 4.1 Leading zero — ไม่ต้องเติมมา

SAP pad `GlAccount` และ `CustomerCode` เป็น 10 หลักให้เอง ทั้งตอนตรวจและตอนบันทึก
ส่งมาเต็มหรือไม่เต็มผลเหมือนกัน

### 4.2 `PaymentMethod` เป็นข้อมูลแสดงผล ไม่ใช่ตัวขับการ post

**functional ยืนยัน 2026-09-18**: Salesforce ส่งคำมาให้เก็บเฉย ๆ SAP ไม่ได้เอาไป post FI
· เก็บตามที่ส่งมาใน `payment_method` char(20) · **ไม่แปลงเป็น SAP code** · column `sap_payment_method`
ถูกลบแล้ว

**เปลี่ยน 2026-10-20** — ค่าอยู่ในรูป `<ประเภทการขาย>-<วิธีจ่าย>` รับ 6 ค่า (ไม่สนตัวพิมพ์/ช่องว่าง)
`CA-Cheque` `CA-Cash` `CA-Transfer` `CR-Cheque` `CR-Cash` `CR-Transfer` · ค่าอื่น **รวมถึงคำเดิมไม่มี prefix** → `202`
· 2 ส่วนเป็นอิสระต่อกัน แยกด้วย `split_payment_method( )`

| ส่วน | ค่า | ผลต่อ validation |
|---|---|---|
| ประเภทการขาย | `CA` | **Cash Sales** (`is_cash_sales( )`) — บังคับ `BillingNoteNo` (= เลข SO, `119`) · SAP หา `AccountingDocument` `BillingDocument` `InvoicePostingDate` `InvoiceAmount` มาทับเอง · หาไม่เจอ `208` |
| ประเภทการขาย | `CR` | เคสอื่นที่ไม่ใช่ Cash Sales — ไม่มีเงื่อนไขเพิ่ม |
| วิธีจ่าย | `Cheque` | (`is_cheque( )`) บังคับ `ChequeNo` `IssueDate` `DueOn` `ChequeBankBranch` (`107`–`110`) + ตรวจ bank (`207`) |
| วิธีจ่าย | `Cash` / `Transfer` | ไม่มีเงื่อนไขเพิ่ม |

เช่น `CA-Cheque` = Cash Sales ที่จ่ายด้วยเช็ค → ต้องส่งเลข SO **และ** ข้อมูลเช็คครบ · `CR-Cash` จ่ายเงินสดแต่**ไม่ใช่** Cash Sales

ที่ยังตรวจคำทั้งที่เป็น information: กันพิมพ์ผิดจน `is_cheque( )` มองไม่เห็นว่าเป็นเช็ค แล้วใบเช็คเข้า table
โดยไม่มีเลขเช็ค

### 4.3 ไม่เช็คเครื่องหมายจำนวนเงินรายบรรทัด

CN ติดลบได้ · แต่ **ผลรวม `AmountPaid` ของทุก item ต้อง > 0**

## 5. Validation ทั้งหมด

| Check | ระดับ | Message | สถานะ |
|---|---|---|---|
| `check_mandatory` | header | `100`–`106` | ✅ |
| `check_number_of_items` | header | `001` `002` | ✅ |
| `check_dates` | header | `003` | ✅ |
| `check_cheque_fields` | header | `107`–`110` | ✅ |
| `check_company_code` | header | `200` | ✅ |
| `check_gl_account` | header | `201` | ✅ |
| `check_payment_method` | header | `202` | ✅ 6 ค่า `CA-`/`CR-` (2026-10-20) |
| `check_amount_paid_total` | header | `011` | ✅ |
| `check_duplicate` | header | `010` | ✅ key = `payment_document_no` + `billing_document` + **`status`** (2026-09-17) — ซ้ำกับ row `N` `S` `E` (เพิ่ม `S` 2026-09-29 `12d266f` · `E` 2026-10-01 `a9fbef1`) |
| `check_bank` | header | `207` | ✅ เฉพาะตอนจ่ายด้วยเช็ค |
| `check_payment_total` | header | `007` | 🟨 ที่ว่าง — OQ-05 |
| `check_item_ids` | item | `005` `111` | ✅ |
| `enrich_cash_sales` | item | `119` `208` | ✅ เฉพาะ prefix `CA` · ทำก่อน validate ตัวอื่น (2026-10-15) |
| `check_item_mandatory` | item | `006` `112`–`118` | ✅ |
| `check_customer_code` | item | `205` | ✅ |
| `check_billing_document` | item | `209` | ✅ `I_BillingDocument` · เติม 0 ครบ 10 หลักก่อนตรวจ · ข้าม `CA-` · ใบที่ได้ `209` ไม่ได้ `206` ซ้อน (2026-10-22) |
| `check_ar_open_item` | item | `206` | ✅ `I_OperationalAcctgDocItem` — `FinancialAccountType = D` · `OriginalReferenceDocument = billing_document` · `ClearingJournalEntry` ว่าง (2026-09-17) |
| `check_accounting_document` | item | `210` | ✅ `I_JournalEntry` key = company code + เลขเอกสาร + ปีบัญชี · **ปีบัญชี = ปีของ `InvoicePostingDate`** (functional ยืนยัน) · เติม 0 ครบ 10 หลัก · ข้าม `CA-` (2026-10-22) |

**18 validation** (เพิ่ม `209` `210` 2026-10-22) (จากเดิม 17 — `validateSalesforceId` ถูกตัดออก ดู §6)

## 6. สรุปการเปลี่ยนแปลง 2026-08-28

| # | เปลี่ยนอะไร | ผลกับ API contract |
|---|---|---|
| 1 | `status` แยกเป็น 2 domain: `ZD_REQUEST_STATUS` (`N`/`S`/`C`/`R`/`E`) transaction status · `ZD_RESPONSE_STATUS` (`S`/`W`/`E`) result status ที่ส่งกลับ SFDC | ไม่กระทบ input |
| 2 | +`batch_id` SAP สร้างตอนรับ | ไม่กระทบ input · โผล่ใน response |
| 3 | +`salesforce_status` +`salesforce_message` · −`error_message` (header) | response เปลี่ยน |
| 4 | `number_of_items` → `number_of_items_in_payment` | 🔴 **`NumberOfItems` → `NumberOfItemsInPayment` — SFDC ต้องแก้ client** |
| 5 | `cheque_bankbranch` → `cheque_bank_branch` | ไม่กระทบ — CamelCase ยังเป็น `ChequeBankBranch` เหมือนเดิม |
| 6 | item: −`status` −`error_message` +`reject_reason` | 🔴 **response รายบรรทัดที่เคยตกลงไว้ทำไม่ได้แล้ว** |
| 7 | duplicate key = `payment_document_no` + `billing_document` | 🔴 `salesforce_id` ไม่ unique อีกต่อไป — **ถอด unique index** |
| 8 | `validateSalesforceId` ถูกตัด | เดิมทำ 2 อย่าง: mandatory (`100`) กับ unique (`004`) · unique ไม่ใช้แล้ว ส่วน mandatory `check_mandatory` ทำอยู่แล้ว จึงเหลือ method เปล่า |
| 9 | message `004 Salesforce ID already exists` เลิกใช้ | เลขไม่ถูกนำกลับมาใช้ซ้ำ เพื่อไม่ให้ client ที่ผูก logic ไว้แล้วสับสน |
