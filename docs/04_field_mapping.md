# ZARI002 — Field Mapping

API field ↔ table field · CDS alias เป็น **CamelCase** · field ใน DDIC table เป็น snake_case

**I/O**: `in` = 3rd-party ส่งเข้ามาได้ · `out` = ระบบเติมให้ ไม่รับจาก payload (ส่งมาก็ถูกเมิน)

> ⚠️ คอลัมน์ **Mand.** เป็น **ข้อเสนอของ Claude รอผู้ใช้/ทีม Salesforce ยืนยันใน Phase 1 (§1.1)**
> ที่เหลือยืนยันแล้วทั้งหมด

---

## 1. Header — entity set `Payment` ← `ZTAR_I002_PYMT`

| CDS alias (OData) | Table field | Type | OData type | I/O | Mand. | Validation / หมายเหตุ |
|---|---|---|---|---|---|---|
| `PaymentUUID` | `payment_uuid` | `sysuuid_x16` | `Edm.Guid` | out | – | Key — RAP gen (early numbering) · คืนกลับใน response |
| `SalesforceId` | `salesforce_id` | `char(18)` | `Edm.String(18)` | in | ✔ | **Unique** — `validateSalesforceId` + unique index |
| `PaymentDocumentNo` | `payment_document_no` | `char(10)` | `Edm.String(10)` | in | – | เลขเอกสารฝั่ง Salesforce · ⚠️ ยืนยันความหมายใน Phase 1 |
| `NumberOfItems` | `number_of_items` | `char(3)` | `Edm.String(3)` | in | ✔ | ต้องเท่ากับจำนวน `_Item` ที่ส่งมา — `validateNumberOfItems` · ⚠️ ตกลง leading zero ใน Phase 1 |
| `CompanyCode` | `company_code` | `char(4)` | `Edm.String(4)` | in | ✔ | `I_CompanyCode` |
| `PostingDate` | `posting_date` | `dats` | `Edm.Date` | in | ✔ | |
| `GLAccount` | `gl_account` | `char(10)` | `Edm.String(10)` | in | ✔ | `I_GLAccountInCompanyCode` (คู่กับ `CompanyCode`) |
| `PaymentMethod` | `payment_method` | `char(8)` | `Edm.String(8)` | in | – | `I_PaymentMethod` — เช็คเฉพาะเมื่อส่งมา |
| `ChequeNo` | `cheque_no` | `char(8)` | `Edm.String(8)` | in | – | |
| `IssueDate` | `issue_date` | `dats` | `Edm.Date` | in | – | |
| `DueOn` | `due_on` | `dats` | `Edm.Date` | in | – | ต้องไม่ก่อน `IssueDate` |
| `ChequeBankBranch` | `cheque_bankbranch` | `char(7)` | `Edm.String(7)` | in | – | ⚠️ ยืนยัน format ใน Phase 1 |
| `Currency` | `currency` | `cuky` | `Edm.String(5)` | in | ✔ | `I_Currency` · เป็น currency reference ของทุก amount ใน header |
| `RoundingDiff` | `rounding_diff` | `curr(23,2)` | `Edm.Decimal` | in | – | |
| `AdvancePayment` | `advance_payment` | `curr(23,2)` | `Edm.Decimal` | in | – | ไม่ติดลบ |
| `Fees` | `fees` | `curr(23,2)` | `Edm.Decimal` | in | – | ไม่ติดลบ |
| `PaymentAmount` | `payment_amount` | `curr(23,2)` | `Edm.Decimal` | in | ✔ | ไม่ติดลบ · ⚠️ ต้องเท่ากับผลรวม `AmountPaid` ของ item หรือไม่ — ยืนยัน Phase 1 |
| `Status` | `status` | `ze_status` | `Edm.String(1)` | out | – | ZARI002 set = `N` เสมอ |
| `ErrorMessage` | `error_message` | `string` | `Edm.String` | out | – | ว่างเสมอตอน create (เป็นของ ZARE002) |
| `CreatedBy` | `created_by` | `abp_creation_user` | `Edm.String` | out | – | managed |
| `CreatedAt` | `created_at` | `abp_creation_tstmpl` | `Edm.DateTimeOffset` | out | – | managed |
| `LastChangedBy` | `last_changed_by` | `abp_lastchange_user` | `Edm.String` | out | – | managed |
| `LastChangedAt` | `last_changed_at` | `abp_lastchange_tstmpl` | `Edm.DateTimeOffset` | out | – | **etag master** |
| `LocalLastChangedAt` | `local_last_changed_at` | `abp_locinst_lastchange_tstmpl` | `Edm.DateTimeOffset` | out | – | total etag |
| `_Item` | — | — | navigation | in | ✔ | Composition ไป `PaymentItem` — ต้องมีอย่างน้อย 1 |

**Input field ที่ 3rd-party ส่งได้: 16 field** (ตามที่ requirement ระบุ — ไม่รวม key/status/error/admin)

## 2. Item — entity set `PaymentItem` ← `ZTAR_I002_ITEM`

| CDS alias (OData) | Table field | Type | OData type | I/O | Mand. | Validation / หมายเหตุ |
|---|---|---|---|---|---|---|
| `ItemUUID` | `item_uuid` | `sysuuid_x16` | `Edm.Guid` | out | – | Key — RAP gen |
| `PaymentUUID` | `payment_uuid` | `sysuuid_x16` | `Edm.Guid` | out | – | RAP ผูกจาก composition ให้เอง |
| `SalesforceItemId` | `salesforce_item_id` | `char(18)` | `Edm.String(18)` | in | ✔ | **Business key / item number** — ห้ามซ้ำภายใน payment เดียวกัน |
| `CustomerCode` | `customer_code` | `char(10)` | `Edm.String(10)` | in | ✔ | `I_Customer` |
| `BillingNoteNo` | `billing_note_no` | `char(10)` | `Edm.String(10)` | in | – | |
| `AccountingDocument` | `accounting_document` | `char(10)` | `Edm.String(10)` | in | – | **ไม่ validate** กับ master data (ตกลง 2026-08-27) |
| `BillingDocument` | `billing_document` | `char(10)` | `Edm.String(10)` | in | – | **ไม่ validate** กับ master data |
| `InvoicePostingDate` | `invoice_posting_date` | `dats` | `Edm.Date` | in | – | |
| `Currency` | `currency` | `cuky` | `Edm.String(5)` | **out** | – | Determination `setItemDefaults` copy จาก header — ไม่รับจาก payload เพื่อไม่ให้ขัดกับ header |
| `InvoiceAmount` | `invoice_amount` | `curr(23,2)` | `Edm.Decimal` | in | ✔ | ไม่ติดลบ |
| `AmountPaid` | `amount_paid` | `curr(23,2)` | `Edm.Decimal` | in | ✔ | ไม่ติดลบ |
| `PartialAmount` | `partial_amount` | `curr(23,2)` | `Edm.Decimal` | in | – | ไม่ติดลบ |
| `SaleSubmitDate` | `sale_submit_date` | `dats` | `Edm.Date` | in | – | |
| `Status` | `status` | `ze_status` | `Edm.String(1)` | out | – | set = `N` |
| `ErrorMessage` | `error_message` | `string` | `Edm.String` | out | – | ว่างเสมอตอน create |
| `CreatedBy` / `CreatedAt` / `LastChangedBy` / `LastChangedAt` / `LocalLastChangedAt` | admin fields | | | out | – | managed · `LastChangedAt` = etag |
| `_Payment` | — | — | navigation | – | – | Association to parent |

**Input field ที่ 3rd-party ส่งได้: 10 field**

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
