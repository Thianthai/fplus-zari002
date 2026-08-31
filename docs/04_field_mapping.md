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
| `BatchId` | `batch_id` | `char(20)` | `String(20)` | out | – | **SAP สร้างตอนรับ** รูปแบบ `YYYYMMDD_hhmmss` |
| `SalesforceId` | `salesforce_id` | `char(18)` | `String(18)` | in | ✔ | key ฝั่ง SFDC · **ซ้ำได้** ไม่ใช่ตัวกัน duplicate |
| `PaymentDocumentNo` | `payment_document_no` | `char(10)` | `String(10)` | in | ✔ | เลขที่เอกสารรับชำระเงินฝั่ง SFDC · **เป็นส่วนหนึ่งของ duplicate key** |
| `NumberOfItemsInPayment` | `number_of_items_in_payment` | `int4` | `Int32` | in | ✔ | จำนวนนับ ส่งเป็นตัวเลข · ต้องเท่ากับจำนวน `Items` |
| `CompanyCode` | `company_code` | `char(4)` | `String(4)` | in | ✔ | ต้องมีจริงใน SAP |
| `PostingDate` | `posting_date` | `dats` | `Date` | in | ✔ | |
| `GlAccount` | `gl_account` | `char(10)` | `String(10)` | in | ✔ | **เดิม `GLAccount`** เปลี่ยน 2026-08-31 เพราะตัวใหญ่ติดกันทำให้กฎแปลงชื่อแตก · ส่งแบบไม่มี leading zero ได้ — SAP pad ให้ (§4.1) |
| `PaymentMethod` | `payment_method` | `char(8)` | `String(8)` | in | ✔ | ส่งเป็น**คำ** เช่น `Cheque` `Transfer` (§4.2) |
| `SapPaymentMethod` | `sap_payment_method` | `char(1)` | `String(1)` | out | – | code ที่แปลงแล้ว — **ZARE002 ใช้ตัวนี้ post FI** |
| `ChequeNo` | `cheque_no` | `char(8)` | `String(8)` | in | (✔) | บังคับเมื่อจ่ายด้วยเช็ค |
| `IssueDate` | `issue_date` | `dats` | `Date` | in | (✔) | บังคับเมื่อจ่ายด้วยเช็ค |
| `DueOn` | `due_on` | `dats` | `Date` | in | (✔) | บังคับเมื่อจ่ายด้วยเช็ค · ต้องไม่ก่อน `IssueDate` |
| `ChequeBankBranch` | `cheque_bank_branch` | `char(15)` | `String(15)` | in | (✔) | บังคับเมื่อจ่ายด้วยเช็ค · ยังไม่ validate (OQ-01) |
| `Currency` | `currency` | `cuky` | `String(5)` | out | – | ดึงจาก `I_CompanyCode` เสมอ (ธุรกิจใช้สกุลเดียว) |
| `RoundingDiff` | `rounding_diff` | `curr(23,2)` | `Decimal` | in | – | ติดลบได้ |
| `AdvancePayment` | `advance_payment` | `curr(23,2)` | `Decimal` | in | – | ติดลบได้ |
| `Fees` | `fees` | `curr(23,2)` | `Decimal` | in | – | |
| `PaymentAmount` | `payment_amount` | `curr(23,2)` | `Decimal` | in | ✔ | มี `check_payment_total` เป็นที่ว่างไว้ (OQ-05) |
| `Status` | `status` | `ze_request_status` | `String(1)` | out | – | **transaction status** — ZARI002 set `N` เท่านั้น |
| `SalesforceStatus` | `salesforce_status` | `ze_response_status` | `String(1)` | out | – | **result status ที่ส่งกลับ SFDC** — ZARI002 ปล่อยว่างเสมอ |
| `SalesforceMessage` | `salesforce_message` | `char(200)` | `String(200)` | out | – | ข้อความคู่กับ `SalesforceStatus` — ZARI002 ปล่อยว่างเสมอ |
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
| `BillingNoteNo` | `billing_note_no` | `char(10)` | `String(10)` | in | – | |
| `AccountingDocument` | `accounting_document` | `char(10)` | `String(10)` | in | ✔ | ต้องยังไม่ถูกรับชำระ/reverse — ที่ว่าง (OQ-08) |
| `BillingDocument` | `billing_document` | `char(10)` | `String(10)` | in | ✔ | **เป็นส่วนหนึ่งของ duplicate key** · ไม่ตรวจกับ master data |
| `InvoicePostingDate` | `invoice_posting_date` | `dats` | `Date` | in | ✔ | |
| `Currency` | `currency` | `cuky` | `String(5)` | out | – | copy จาก header |
| `InvoiceAmount` | `invoice_amount` | `curr(23,2)` | `Decimal` | in | ✔ | |
| `AmountPaid` | `amount_paid` | `curr(23,2)` | `Decimal` | in | ✔ | ผลรวมทุก item ต้อง > 0 |
| `PartialAmount` | `partial_amount` | `char(1)` | `String(1)` | in | – | **flag ไม่ใช่จำนวนเงิน** — `X` = จ่ายบางส่วน |
| `SaleSubmitDate` | `sale_submit_date` | `dats` | `Date` | in | ✔ | |
| `RejectReason` | `reject_reason` | `char(200)` | `String(200)` | out | – | **ZARI002 ไม่เคยเขียน** — เป็นของ ZARE002 |
| `CreatedBy` `CreatedAt` `LastChangedBy` `LocalLastChangedAt` | admin fields | | | out | – | managed · ไม่มี `LastChangedAt` (ดู `01_architecture.md` §3.4) |


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

### 4.2 `PaymentMethod` ส่งเป็นคำ

| SFDC ส่ง | SAP code |
|---|---|
| `Cheque` | `A` (Manual Cheque) |
| `Transfer` | `T` (Bank Transfer) |

`Cheque` ทำให้ `ChequeNo` `IssueDate` `DueOn` `ChequeBankBranch` กลายเป็นบังคับ
⚠️ `Transfer` ยาว 8 ตัวเต็ม `char(8)` พอดี — คำใหม่ที่ยาวกว่านี้ส่งเข้ามาไม่ได้ (OQ-02)

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
| `check_payment_method` | header | `202` `203` | ✅ |
| `check_amount_paid_total` | header | `011` | ✅ |
| `check_duplicate` | header | `010` | ✅ นิยามชัดแล้ว |
| `check_amount_format` | header | `009` | 🟨 ที่ว่าง — OQ-10 |
| `check_cheque_bank_branch` | header | `008` | 🟨 ที่ว่าง — OQ-01 |
| `check_payment_total` | header | `007` | 🟨 ที่ว่าง — OQ-05 |
| `check_item_ids` | item | `005` `111` | ✅ |
| `check_item_mandatory` | item | `006` `112`–`118` | ✅ |
| `check_customer_code` | item | `205` | ✅ |
| `check_ar_open_item` | item | `206` | 🟨 ที่ว่าง — OQ-08 |

**16 validation** (จากเดิม 17 — `validateSalesforceId` ถูกตัดออก ดู §6)

## 6. สรุปการเปลี่ยนแปลง 2026-08-28

| # | เปลี่ยนอะไร | ผลกับ API contract |
|---|---|---|
| 1 | `status` แยกเป็น 2 domain: `ZD_REQUEST_STATUS` (`N`/`C`/`R`/`E`) transaction status · `ZD_RESPONSE_STATUS` (`S`/`W`/`E`) result status ที่ส่งกลับ SFDC | ไม่กระทบ input |
| 2 | +`batch_id` SAP สร้างตอนรับ | ไม่กระทบ input · โผล่ใน response |
| 3 | +`salesforce_status` +`salesforce_message` · −`error_message` (header) | response เปลี่ยน |
| 4 | `number_of_items` → `number_of_items_in_payment` | 🔴 **`NumberOfItems` → `NumberOfItemsInPayment` — SFDC ต้องแก้ client** |
| 5 | `cheque_bankbranch` → `cheque_bank_branch` | ไม่กระทบ — CamelCase ยังเป็น `ChequeBankBranch` เหมือนเดิม |
| 6 | item: −`status` −`error_message` +`reject_reason` | 🔴 **response รายบรรทัดที่เคยตกลงไว้ทำไม่ได้แล้ว** |
| 7 | duplicate key = `payment_document_no` + `billing_document` | 🔴 `salesforce_id` ไม่ unique อีกต่อไป — **ถอด unique index** |
| 8 | `validateSalesforceId` ถูกตัด | เดิมทำ 2 อย่าง: mandatory (`100`) กับ unique (`004`) · unique ไม่ใช้แล้ว ส่วน mandatory `check_mandatory` ทำอยู่แล้ว จึงเหลือ method เปล่า |
| 9 | message `004 Salesforce ID already exists` เลิกใช้ | เลขไม่ถูกนำกลับมาใช้ซ้ำ เพื่อไม่ให้ client ที่ผูก logic ไว้แล้วสับสน |
