# ZARI002 — Field Mapping

API field ↔ table field · CDS alias เป็น **CamelCase** · field ใน DDIC table เป็น snake_case

**I/O**: `in` = 3rd-party ส่งเข้ามาได้ · `out` = ระบบเติมให้ ไม่รับจาก payload (ส่งมาก็ถูกเมิน)

**Mand.**: `✔` = บังคับเสมอ · `(✔)` = บังคับแบบมีเงื่อนไข · `–` = optional
ยืนยัน mandatory list แล้ว 2026-08-27

### Conditional mandatory — payment แบบเช็ค

`cheque_no` · `issue_date` · `due_on` · `cheque_bankbranch` **ไม่ใช่ mandatory ทั่วไป
แต่บังคับเมื่อ `payment_method` = เช็ค** → validation `validateChequeFields`
⚠️ ค่า code ของ "เช็ค" ยังไม่ล็อก (ดู §5)  <!-- open -->

---

## 1. Header — entity set `Payment` ← `ZTAR_I002_PYMT`

| CDS alias (OData) | Table field | Type | OData type | I/O | Mand. | Validation / หมายเหตุ |
|---|---|---|---|---|---|---|
| `PaymentUUID` | `payment_uuid` | `sysuuid_x16` | `Edm.Guid` | out | – | Key — RAP gen (early numbering) · คืนกลับใน response |
| `SalesforceId` | `salesforce_id` | `char(18)` | `Edm.String(18)` | in | ✔ | **Unique** — `validateSalesforceId` + unique index |
| `PaymentDocumentNo` | `payment_document_no` | `char(10)` | `Edm.String(10)` | in | ✔ | เลขที่เอกสารรับชำระเงินจากระบบ Salesforce |
| `NumberOfItems` | `number_of_items` | `int4` | `Edm.Int32` | in | ✔ | จำนวนนับ (`5` ไม่ใช่ `"005"`) · ต้องเท่ากับจำนวน `_Item` ที่ส่งมา — `validateNumberOfItems` |
| `CompanyCode` | `company_code` | `char(4)` | `Edm.String(4)` | in | ✔ | `I_CompanyCode` |
| `PostingDate` | `posting_date` | `dats` | `Edm.Date` | in | ✔ | |
| `GLAccount` | `gl_account` | `char(10)` | `Edm.String(10)` | in | ✔ | `I_GLAccountInCompanyCode` (คู่กับ `CompanyCode`) |
| `PaymentMethod` | `payment_method` | `char(30)` | `Edm.String(30)` | in | ✔ | **คำจาก Salesforce** (เช่น `Cheque`) เก็บดิบไว้เพื่อ audit |
| `SapPaymentMethod` | `sap_payment_method` | `char(1)` | `Edm.String(1)` | out | – | code ที่แปลงแล้ว — determination `setPaymentMethodCode` · validate กับ `I_PaymentMethod` · เป็นตัวตัดสิน conditional mandatory ของกลุ่มเช็ค · **ZARE002 ใช้ตัวนี้ post FI** |
| `ChequeNo` | `cheque_no` | `char(8)` | `Edm.String(8)` | in | (✔) | บังคับเมื่อจ่ายด้วยเช็ค |
| `IssueDate` | `issue_date` | `dats` | `Edm.Date` | in | (✔) | บังคับเมื่อจ่ายด้วยเช็ค |
| `DueOn` | `due_on` | `dats` | `Edm.Date` | in | (✔) | บังคับเมื่อจ่ายด้วยเช็ค · ต้องไม่ก่อน `IssueDate` |
| `ChequeBankBranch` | `cheque_bankbranch` | `char(15)` | `Edm.String(15)` | in | (✔) | บังคับเมื่อจ่ายด้วยเช็ค · = `I_Bank_2.BankInternalID` · validate กับ `I_Bank_2` |
| `Currency` | `currency` | `cuky` | `Edm.String(5)` | **out** | – | ไม่รับจาก payload — determination ดึง currency ของ `CompanyCode` จาก `I_CompanyCode` เสมอ (ธุรกิจใช้สกุลเดียว) · เป็น currency reference ของทุก amount ใน header **และของ item** |
| `RoundingDiff` | `rounding_diff` | `curr(23,2)` | `Edm.Decimal` | in | – | |
| `AdvancePayment` | `advance_payment` | `curr(23,2)` | `Edm.Decimal` | in | – | ไม่ติดลบ |
| `Fees` | `fees` | `curr(23,2)` | `Edm.Decimal` | in | – | ไม่ติดลบ |
| `PaymentAmount` | `payment_amount` | `curr(23,2)` | `Edm.Decimal` | in | ✔ | ไม่ติดลบ · มี validation `validatePaymentTotal` เป็นที่ว่างไว้ให้ ยังไม่ใส่ logic (ตกลง 2026-08-27) |
| `Status` | `status` | `ze_status` | `Edm.String(1)` | out | – | ZARI002 set = `N` เสมอ |
| `ErrorMessage` | `error_message` | `string` | `Edm.String` | out | – | ว่างเสมอตอน create (เป็นของ ZARE002) |
| `CreatedBy` | `created_by` | `abp_creation_user` | `Edm.String` | out | – | managed |
| `CreatedAt` | `created_at` | `abp_creation_tstmpl` | `Edm.DateTimeOffset` | out | – | managed |
| `LastChangedBy` | `last_changed_by` | `abp_lastchange_user` | `Edm.String` | out | – | managed |
| `LastChangedAt` | `last_changed_at` | `abp_lastchange_tstmpl` | `Edm.DateTimeOffset` | out | – | **etag master** |
| `LocalLastChangedAt` | `local_last_changed_at` | `abp_locinst_lastchange_tstmpl` | `Edm.DateTimeOffset` | out | – | total etag |
| `_Item` | — | — | navigation | in | ✔ | Composition ไป `PaymentItem` — ต้องมีอย่างน้อย 1 |

**Input field ที่ 3rd-party ส่งได้: 15 field** — เดิม 16 ตัด `Currency` ออกเพราะ derive เสมอ
**Mandatory 8 ตัว**: `SalesforceId` `PaymentDocumentNo` `NumberOfItems` `CompanyCode`
`PostingDate` `GLAccount` `PaymentMethod` `PaymentAmount` · **conditional อีก 4 ตัว** (กรณีเช็ค)

## 2. Item — entity set `PaymentItem` ← `ZTAR_I002_ITEM`

| CDS alias (OData) | Table field | Type | OData type | I/O | Mand. | Validation / หมายเหตุ |
|---|---|---|---|---|---|---|
| `ItemUUID` | `item_uuid` | `sysuuid_x16` | `Edm.Guid` | out | – | Key — RAP gen |
| `PaymentUUID` | `payment_uuid` | `sysuuid_x16` | `Edm.Guid` | out | – | RAP ผูกจาก composition ให้เอง |
| `SalesforceItemId` | `salesforce_item_id` | `char(18)` | `Edm.String(18)` | in | ✔ | **Business key / item number** — ห้ามซ้ำภายใน payment เดียวกัน |
| `CustomerCode` | `customer_code` | `char(10)` | `Edm.String(10)` | in | ✔ | `I_Customer` |
| `BillingNoteNo` | `billing_note_no` | `char(10)` | `Edm.String(10)` | in | – | |
| `AccountingDocument` | `accounting_document` | `char(10)` | `Edm.String(10)` | in | ✔ | **ไม่ validate** กับ master data (ตกลง 2026-08-27) |
| `BillingDocument` | `billing_document` | `char(10)` | `Edm.String(10)` | in | ✔ | **ไม่ validate** กับ master data |
| `InvoicePostingDate` | `invoice_posting_date` | `dats` | `Edm.Date` | in | ✔ | |
| `Currency` | `currency` | `cuky` | `Edm.String(5)` | **out** | ⚠️ | Determination `setItemDefaults` copy จาก header — ไม่รับจาก payload เพื่อไม่ให้ขัดกับ header |
| `InvoiceAmount` | `invoice_amount` | `curr(23,2)` | `Edm.Decimal` | in | ✔ | ไม่ติดลบ |
| `AmountPaid` | `amount_paid` | `curr(23,2)` | `Edm.Decimal` | in | ✔ | ไม่ติดลบ |
| `PartialAmount` | `partial_amount` | `curr(23,2)` | `Edm.Decimal` | in | – | ไม่ติดลบ |
| `SaleSubmitDate` | `sale_submit_date` | `dats` | `Edm.Date` | in | ✔ | |
| `Status` | `status` | `ze_status` | `Edm.String(1)` | out | – | set = `N` |
| `ErrorMessage` | `error_message` | `string` | `Edm.String` | out | – | ว่างเสมอตอน create |
| `CreatedBy` / `CreatedAt` / `LastChangedBy` / `LastChangedAt` / `LocalLastChangedAt` | admin fields | | | out | – | managed · `LastChangedAt` = etag |
| `_Payment` | — | — | navigation | – | – | Association to parent |

**Input field ที่ 3rd-party ส่งได้: 10 field**
**Mandatory 8 ตัว**: `SalesforceItemId` `CustomerCode` `AccountingDocument` `BillingDocument`
`InvoicePostingDate` `InvoiceAmount` `AmountPaid` `SaleSubmitDate`
optional 2 ตัว: `BillingNoteNo` `PartialAmount`

> `AccountingDocument` / `BillingDocument` **บังคับให้ส่ง แต่ไม่ validate กับ master data**
> — เป็นคนละเรื่องกัน (ตกลง 2026-08-27)

## 3. ตัวอย่าง payload

```http
POST /sap/opu/odata4/sap/zapi_zari002_o4/srvd_a2x/sap/zapi_zari002/0001/Payment
Content-Type: application/json
```

```json
{
  "SalesforceId": "a0X5g000004ABCDEAB",
  "PaymentDocumentNo": "PAY0000123",
  "NumberOfItems": "002",
  "CompanyCode": "1000",
  "PostingDate": "2026-08-27",
  "GLAccount": "0011001000",
  "PaymentMethod": "C",
  "ChequeNo": "00123456",
  "IssueDate": "2026-08-20",
  "DueOn": "2026-09-20",
  "ChequeBankBranch": "0011002",
  "Currency": "THB",
  "RoundingDiff": "0.00",
  "AdvancePayment": "0.00",
  "Fees": "50.00",
  "PaymentAmount": "10000.00",
  "_Item": [
    {
      "SalesforceItemId": "a0Y5g000004ITEM01A",
      "CustomerCode": "0000100001",
      "BillingNoteNo": "BN00000123",
      "AccountingDocument": "1800000123",
      "BillingDocument": "9000000123",
      "InvoicePostingDate": "2026-08-15",
      "InvoiceAmount": "6000.00",
      "AmountPaid": "6000.00",
      "PartialAmount": "0.00",
      "SaleSubmitDate": "2026-08-16"
    },
    {
      "SalesforceItemId": "a0Y5g000004ITEM02A",
      "CustomerCode": "0000100001",
      "BillingNoteNo": "BN00000124",
      "AccountingDocument": "1800000124",
      "BillingDocument": "9000000124",
      "InvoicePostingDate": "2026-08-16",
      "InvoiceAmount": "4000.00",
      "AmountPaid": "4000.00",
      "PartialAmount": "0.00",
      "SaleSubmitDate": "2026-08-16"
    }
  ]
}
```

Response `201 Created` คืน `PaymentUUID` + `ItemUUID` ของทุก item + `Status = "N"`

## 4. Error response

validate ไม่ผ่าน → **`400 Bad Request` ไม่บันทึกอะไรลง table เลย** พร้อม message ครบทุกข้อในรอบเดียว
message ที่เกี่ยวกับ item จะอ้างถึงด้วย `SalesforceItemId` เพราะ `ItemUUID` ยังไม่เกิด

รูปแบบ error body ตัวจริง + รายการ message code ทั้งหมด → `docs/05_api_spec.md` (Phase 5.6)

⚠️ **`500` จากการยิงซ้ำพร้อมกัน**: ถ้า unique index เป็นตัวจับ duplicate (เคส race)
จะออกมาเป็น 500 ไม่ใช่ 400 — ให้ถือว่า **อาจสร้างสำเร็จไปแล้ว ห้าม retry อัตโนมัติ**
(เหตุผลเต็ม: `01_architecture.md` §5)


---

## 5. ข้อที่ยังไม่ปิด

| # | เรื่อง | สถานะ |
|---|--------|--------|
| 5.1 | `Currency` ตัดออกจาก input — determination ดึงจาก company code เสมอ | ✅ ตกลง 2026-08-27 |
| 5.2 | `ChequeBankBranch` ขยายเป็น `char(15)` + validate กับ `I_Bank_2` | ✅ ตกลง 2026-08-27 · รอ activate |
| 5.3 | `payment_method` — แปลงคำ → SAP code ด้วย constant ใน `ZCL_ZARI002_VALIDATOR` | ✅ ตกลงวิธี · ⬜ รอค่าจริง ดู §6 |
| 5.4 | `BankCountry` derive จาก `Country` ของ company code | ✅ ตกลง 2026-08-27 |
| 5.5 | `NumberOfItems` เปลี่ยนเป็น `int4` | ✅ ตกลง 2026-08-27 · รอ activate |
| 5.6 | รูปแบบ response ตอน error | ✅ คง reject ทั้ง request → 400 OData error payload |


---

## 6. 🔴 `payment_method` — ต้องมี conversion ก่อนเข้า Phase 4

Salesforce ส่ง**คำ** (เช่น `"Cheque"`) ไม่ใช่ SAP payment method code
ซึ่ง `I_PaymentMethod.PaymentMethod` เป็น **`CHAR 1`** → validate ตรง ๆ ไม่มีวันผ่าน

**ปัญหา 2 ชั้น**

1. **ความยาว** — field เป็น `char(8)` "Cheque" (6) พอดี แต่คำอย่าง `"Bank Transfer"` (13)
   ไม่รอด ไม่ว่าจะโดนตัดหรือถูก OData deserializer reject ตั้งแต่ชั้นนอกก็ใช้ไม่ได้ทั้งคู่
2. **ค่าไม่ตรงชนิด** — ต้องแปลงคำ → SAP code ก่อน validate และก่อนส่งต่อให้ ZARE002 post FI

**ทางที่ตัดทิ้งแล้ว: match กับ description ของ `I_PaymentMethodText`**
description เป็น config text ที่ business user แก้ได้ตลอด · ขึ้นกับภาษา · ไม่ unique
ถ้าใครไปแก้ข้อความ interface พังเงียบ ๆ ทันที — เอาข้อความ config มาเป็น key ไม่ได้

**ทางที่เลือก (2026-08-27): แปลงฝั่ง SAP ด้วย constant**

| ของที่เพิ่ม | ทำไม |
|---|---|
| ขยาย `payment_method` เป็น `char(30)` | รับคำเต็ม ๆ จาก Salesforce ได้ · เก็บค่าดิบไว้เพื่อ audit |
| field ใหม่ `sap_payment_method : abap.char(1)` | code ที่แปลงแล้ว — ZARE002 ใช้ post FI |
| constant `gc_payment_method_map` ใน `ZCL_ZARI002_VALIDATOR` | ตัวแปลง — **ไม่สร้าง class ใหม่** ตามที่ตกลง |
| determination `setPaymentMethodCode` | แปลงก่อน validation ทำงาน |

⬜ **ยังเติมค่าจริงไม่ได้** ต้องรู้ 2 อย่างก่อน: Salesforce ส่งคำอะไรมาบ้าง (ทั้งชุด ไม่ใช่แค่เช็ค)
และ tenant มี payment method code อะไรให้แมตช์ (ผลบล็อก 8 ของ spike)

> ตั้งใจให้ย้ายไป **constant table** ที่ maintain เองได้ในภายหลัง — เก็บ mapping ไว้ที่เดียว
> และให้ determination เรียกผ่าน method เดียว เพื่อให้ย้ายแล้วกระทบจุดเดียว


---

## 7. 🔴 ที่เจอจาก sample data ของ Salesforce (2026-08-27)

| # | เรื่อง | สถานะ |
|---|--------|--------|
| 7.1 | `partial_amount` ใน sample เป็น **flag `CHAR(1)` ค่า `X`** ไม่ใช่จำนวนเงิน แต่ table เป็น `curr(23,2)` | ⬜ รอตัดสินใจ |
| 7.2 | `cheque_bankbranch` ตัวอย่าง `0040129` — ดูเหมือน **bank 3 หลัก + branch 4 หลัก** ไม่ใช่ `BankInternalID` ล้วน (`I_Bank_2` มีแต่ `004` ไม่มี `0040129`) | ⬜ รอตัดสินใจ |
| 7.3 | `gl_account` Salesforce ส่ง `11011214` **ไม่มี leading zero** แต่ SAP เก็บ `0011011214` → ต้อง ALPHA conversion ก่อน validate | ⬜ รอตัดสินใจ |
| 7.4 | `rounding_diff` และ `advance_payment` ใน sample **ติดลบได้** (`-1.00`, `-100.00`) → กฎ "ไม่ติดลบ" ใช้กับ 2 field นี้ไม่ได้ | ⬜ รอตัดสินใจ |
| 7.5 | Mapping `Cheque` / `Transfer` → SAP code ยังเติมไม่ได้ ต้องรู้ description ของ payment method บน tenant ก่อน | ⬜ รอผล spike |

`payment_method` **คง `char(8)` ตามเดิม** — sample มีแค่ `Cheque` (6) กับ `Transfer` (8) พอดีตัว
