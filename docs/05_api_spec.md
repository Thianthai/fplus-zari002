# ZARI002 — API Specification

เอกสารสำหรับ **ทีม Salesforce** เอาไปเขียน client

> 🟨 **Draft (2026-08-27)** — field contract นิ่งแล้ว แต่ **URL จริงยังไม่มี** จนกว่าจะ publish
> service binding ใน Phase 5 · ข้อที่ยัง `⬜` ระบุไว้ชัดเจนในแต่ละหัวข้อ

## 1. ภาพรวม

| | |
|---|---|
| ทำอะไร | รับข้อมูล incoming payment จาก Salesforce มาเก็บใน SAP |
| Protocol | OData **V4** (A2X / Web API) |
| Operation | **Create อย่างเดียว** — ไม่มี read / update / delete |
| โครงสร้าง | **Deep insert** — 1 request = 1 payment header + N items |
| Transaction | **All-or-nothing** — ผิดข้อเดียว ไม่บันทึกอะไรเลยทั้ง request |
| Entity set | `Payment` (header) · `PaymentItem` (item ผ่าน navigation `_Item`) |

**สิ่งที่ API นี้ไม่ทำ**: ไม่ post FI · ไม่ตอบผลการ post
การ post เป็นงานของ **ZARE002** และการส่งผลกลับ Salesforce เป็นงานของ **ZARI003**

## 2. Endpoint

```
POST /sap/opu/odata4/sap/zapi_zari002_o4/srvd_a2x/sap/zapi_zari002/0001/Payment
```

⬜ **ยังไม่ final** — ยืนยันอีกครั้งหลัง Phase 5.4 (publish service binding)

| Header | ค่า |
|---|---|
| `Content-Type` | `application/json` |
| `Authorization` | Basic auth ด้วย communication user (⬜ ได้จาก Phase 6) |

**แนะนำให้ต่อท้าย URL ด้วย `$select` / `$expand`** เพื่อให้ response เล็กและคงที่:

```
?$select=SalesforceId,Status,ErrorMessage&$expand=_Item($select=SalesforceItemId,Status,ErrorMessage)
```

## 3. Field ของ header (`Payment`)

**ส่งได้ 15 field** — `✔` = บังคับ · `(✔)` = บังคับเมื่อจ่ายด้วยเช็ค · `–` = optional

| Field | Type | | หมายเหตุ |
|---|---|---|---|
| `SalesforceId` | String(18) | ✔ | **ต้องไม่ซ้ำ** — ใช้กันการยิงซ้ำ (ดู §7) |
| `PaymentDocumentNo` | String(10) | ✔ | เลขที่เอกสารรับชำระเงินฝั่ง Salesforce |
| `NumberOfItems` | **Int32** | ✔ | จำนวนนับ ส่งเป็นตัวเลข `5` ไม่ใช่ `"5"` หรือ `"005"` · ต้องเท่ากับจำนวน `_Item` |
| `CompanyCode` | String(4) | ✔ | ต้องมีจริงใน SAP |
| `PostingDate` | Date | ✔ | `YYYY-MM-DD` |
| `GLAccount` | String(10) | ✔ | **ส่งแบบไม่มี leading zero ได้** — SAP เติมให้เอง (ดู §6.1) |
| `PaymentMethod` | String(8) | ✔ | ส่งเป็น**คำ** เช่น `Cheque`, `Transfer` (ดู §6.2) |
| `ChequeNo` | String(8) | (✔) | |
| `IssueDate` | Date | (✔) | |
| `DueOn` | Date | (✔) | ต้องไม่ก่อน `IssueDate` |
| `ChequeBankBranch` | String(15) | (✔) | ⬜ โครงสร้างยังไม่ยืนยัน ตอนนี้ยังไม่ validate |
| `RoundingDiff` | Decimal(23,2) | – | **ติดลบได้** |
| `AdvancePayment` | Decimal(23,2) | – | **ติดลบได้** |
| `Fees` | Decimal(23,2) | – | |
| `PaymentAmount` | Decimal(23,2) | ✔ | |
| `_Item` | array | ✔ | ต้องมีอย่างน้อย 1 รายการ |

**ห้ามส่ง** (ระบบเติมเอง ส่งมาก็ถูกเมิน): `PaymentUUID` · `Currency` · `SapPaymentMethod` ·
`Status` · `ErrorMessage` · field `Created*` / `LastChanged*` ทั้งหมด

## 4. Field ของ item (`_Item`)

**ส่งได้ 10 field**

| Field | Type | | หมายเหตุ |
|---|---|---|---|
| `SalesforceItemId` | String(18) | ✔ | **business key ของ item** — ต้องไม่ซ้ำกันเองภายใน payment เดียวกัน · error message จะอ้างถึง item ด้วยค่านี้ |
| `CustomerCode` | String(10) | ✔ | ต้องมีจริงใน SAP · ส่งแบบไม่มี leading zero ได้ |
| `BillingNoteNo` | String(10) | – | |
| `AccountingDocument` | String(10) | ✔ | ต้องเป็นรายการที่**ยังไม่ถูกรับชำระหรือ reverse** (`ZARI002/206`) |
| `BillingDocument` | String(10) | ✔ | **ไม่ถูกตรวจกับข้อมูลใน SAP** |
| `InvoicePostingDate` | Date | ✔ | |
| `InvoiceAmount` | Decimal(23,2) | ✔ | |
| `AmountPaid` | Decimal(23,2) | ✔ | |
| `PartialAmount` | **String(1)** | – | **เป็น flag ไม่ใช่จำนวนเงิน** — `"X"` = จ่ายบางส่วน · `""` = จ่ายเต็ม |
| `SaleSubmitDate` | Date | ✔ | |

**ห้ามส่ง**: `ItemUUID` · `PaymentUUID` · `Currency` · `Status` · `ErrorMessage` · admin fields

## 5. ตัวอย่าง request

```json
{
  "SalesforceId": "b0yfd000000GRsHAAW",
  "PaymentDocumentNo": "1000000001",
  "NumberOfItems": 2,
  "CompanyCode": "2000",
  "PostingDate": "2026-08-15",
  "GLAccount": "11011214",
  "PaymentMethod": "Cheque",
  "ChequeNo": "10020185",
  "IssueDate": "2026-07-15",
  "DueOn": "2026-08-31",
  "ChequeBankBranch": "0040129",
  "RoundingDiff": "0.00",
  "AdvancePayment": "60.00",
  "Fees": "5.00",
  "PaymentAmount": "9650.00",
  "_Item": [
    {
      "SalesforceItemId": "a0yfd000000GRsHAAW",
      "CustomerCode": "1000000001",
      "BillingNoteNo": "BN00000001",
      "AccountingDocument": "6000000001",
      "BillingDocument": "0090000000",
      "InvoicePostingDate": "2026-07-01",
      "InvoiceAmount": "1070.00",
      "AmountPaid": "1070.00",
      "PartialAmount": "",
      "SaleSubmitDate": "2026-08-15"
    },
    {
      "SalesforceItemId": "a2yfd000000GRsHAAW",
      "CustomerCode": "1000000001",
      "BillingNoteNo": "BN00000001",
      "AccountingDocument": "6000000003",
      "BillingDocument": "0090000002",
      "InvoicePostingDate": "2026-08-03",
      "InvoiceAmount": "1605.00",
      "AmountPaid": "500.00",
      "PartialAmount": "X",
      "SaleSubmitDate": "2026-08-15"
    }
  ]
}
```

## 6. กฎที่ต้องรู้ก่อนเขียน client

### 6.1 Leading zero — ไม่ต้องเติมมา

SAP เก็บ `GLAccount` และ `CustomerCode` เป็น 10 หลักเต็มโดยเติม `0` ข้างหน้า
API **เติมให้เอง** ก่อนตรวจและก่อนบันทึก

```
ส่ง  11011214   →  SAP เก็บ  0011011214
ส่ง  0011011214 →  SAP เก็บ  0011011214    (ส่งมาเต็มก็ได้ ผลเหมือนกัน)
```

### 6.2 `PaymentMethod` ส่งเป็นคำ

API แปลงคำเป็น SAP payment method code ให้เอง

| Salesforce ส่ง | SAP code |
|---|---|
| `Cheque` | `A` (Manual Cheque) |
| `Transfer` | `T` (Bank Transfer) |

⬜ **ถ้า Salesforce จะส่งคำอื่นนอกจาก 2 คำนี้ ต้องแจ้งล่วงหน้า** — คำที่ไม่อยู่ในรายการ
จะถูก reject ทั้ง request

**`PaymentMethod = "Cheque"` ทำให้ 4 field กลายเป็นบังคับ**: `ChequeNo` `IssueDate`
`DueOn` `ChequeBankBranch`

### 6.3 `Currency` ไม่ต้องส่ง

ธุรกิจใช้สกุลเงินเดียวตาม company code → API ดึงมาเติมให้ทั้ง header และทุก item
⚠️ แปลว่า **API นี้รองรับสกุลเงินของ company code เท่านั้น** ถ้าวันหน้ามีรับชำระสกุลอื่น
ต้องแก้ contract

### 6.4 `PartialAmount` เป็น flag

ชื่อ field สื่อว่าเป็นจำนวนเงิน แต่**ไม่ใช่** — ส่ง `"X"` เมื่อเป็นการจ่ายบางส่วน
ส่งค่าว่างเมื่อจ่ายเต็ม · ส่งตัวเลขมาจะถูก reject

### 6.5 ไม่มีการตรวจเครื่องหมายจำนวนเงิน

**รายบรรทัด**รับค่าติดลบได้ (CN เป็นค่าติดลบตามปกติ) — แต่ **ผลรวม `AmountPaid` ของทุก item
ในหนึ่ง payment ต้องมากกว่า 0** ไม่งั้นได้ `ZARI002/011`

## 7. Idempotency — ห้ามยิงซ้ำ

ตรวจ 2 ชั้น:

1. **`SalesforceId` ต้องไม่ซ้ำ** ในระดับ payment — ยิง id เดิมเข้ามาอีกครั้งได้ `ZARI002/004`
2. **`SalesforceItemId` ต้องไม่เคยเข้ามาใน payment ใบก่อนหน้า** — กันจ่ายซ้ำใบแจ้งหนี้เดิม
   ผ่าน payment คนละใบ ได้ `ZARI002/010`

⚠️ **ถ้าได้ `500` จากการยิงซ้ำพร้อมกัน 2 request ให้ถือว่าอาจสร้างสำเร็จไปแล้ว
ห้าม retry อัตโนมัติ** — API นี้ไม่มี read operation ให้ query กลับมาเช็ค
ต้องให้คนตรวจสอบ หรือรอผลจาก ZARI003

## 8. Response

### 8.1 สำเร็จ — `201 Created`

เมื่อยิงพร้อม `$select` / `$expand` ตาม §2:

```json
{
  "SalesforceId": "b0yfd000000GRsHAAW",
  "Status": "N",
  "ErrorMessage": "",
  "_Item": [
    { "SalesforceItemId": "a0yfd000000GRsHAAW", "Status": "N", "ErrorMessage": "" },
    { "SalesforceItemId": "a2yfd000000GRsHAAW", "Status": "N", "ErrorMessage": "" }
  ]
}
```

`Status = "N"` และ `ErrorMessage = ""` **เสมอ** ตอนสร้างสำเร็จ — แปลว่า "รับเข้าคิวแล้ว
รอ post" ไม่ใช่ผลการ post · ค่า `S` / `W` / `E` จะถูก stamp โดย ZARE002 ทีหลัง
และส่งกลับมาให้ Salesforce ผ่าน **ZARI003**

### 8.2 ไม่สำเร็จ — `400 Bad Request`

**ไม่มีอะไรถูกบันทึกเลย** ทั้ง header และทุก item · message มาครบทุกข้อในรอบเดียว
ไม่ต้องยิงไล่แก้ทีละข้อ

```json
{
  "error": {
    "code": "ZARI002/200",
    "message": "Company code 9999 does not exist",
    "details": [
      { "code": "ZARI002/200", "message": "Company code 9999 does not exist", "target": "CompanyCode" },
      { "code": "ZARI002/205", "message": "Item a2yfd000000GRsHAAW: customer 1000000099 does not exist" }
    ]
  }
}
```

**message ที่เกี่ยวกับ item จะขึ้นต้นด้วย `SalesforceItemId` เสมอ** เพราะตอน reject
ยังไม่มี `ItemUUID` ให้อ้างถึง

### 8.3 Message code ทั้งหมด

เลขในแต่ละกลุ่ม **run ต่อกันไม่เว้นช่วง** · message ที่เพิ่มใหม่ให้**ต่อท้ายกลุ่มของตัวเอง**
เลขที่ประกาศไปแล้วจะไม่เปลี่ยนอีก ฝั่ง client จึงผูก logic กับ `code` ได้ปลอดภัย

**`0xx` — โครงสร้างและความสอดคล้องของข้อมูล**

| Code | ข้อความ |
|---|---|
| `ZARI002/001` | Payment must have at least one item |
| `ZARI002/002` | Number of items &1 does not match &2 items sent |
| `ZARI002/003` | Due date &1 is before issue date &2 |
| `ZARI002/004` | Salesforce ID &1 already exists |
| `ZARI002/005` | Duplicate Salesforce item ID &1 |
| `ZARI002/006` | Item &1: partial flag must be X or blank |
| `ZARI002/007` | Payment amount &1 does not match item total &2 — ⬜ ยังไม่เปิดใช้ (OQ-05) |
| `ZARI002/008` | Bank/branch &1 does not exist — ⬜ ยังไม่เปิดใช้ (OQ-01) |
| `ZARI002/009` | Invalid payment data for payment &1. Please verify — ⬜ ยังไม่เปิดใช้ (OQ-10) |
| `ZARI002/010` | Duplicate record: item &1 already exists in SAP |
| `ZARI002/011` | Payment &1: received amount must be greater than zero |

**`1xx` — field ที่บังคับ**

| Code | ข้อความ |
|---|---|
| `ZARI002/100` | Salesforce ID is required |
| `ZARI002/101` | Payment document number is required |
| `ZARI002/102` | Company code is required |
| `ZARI002/103` | Posting date is required |
| `ZARI002/104` | G/L account is required |
| `ZARI002/105` | Payment method is required |
| `ZARI002/106` | Payment amount is required |
| `ZARI002/107` | Cheque number is required for payment method &1 |
| `ZARI002/108` | Issue date is required for payment method &1 |
| `ZARI002/109` | Due date is required for payment method &1 |
| `ZARI002/110` | Bank/branch is required for payment method &1 |
| `ZARI002/111` | Every item must have a Salesforce item ID |
| `ZARI002/112` | Item &1: customer code is required |
| `ZARI002/113` | Item &1: accounting document is required |
| `ZARI002/114` | Item &1: billing document is required |
| `ZARI002/115` | Item &1: invoice posting date is required |
| `ZARI002/116` | Item &1: invoice amount is required |
| `ZARI002/117` | Item &1: amount paid is required |
| `ZARI002/118` | Item &1: sale submit date is required |

`107`–`110` เกิดเฉพาะเมื่อ `PaymentMethod` เป็นเช็ค

**`2xx` — ข้อมูลไม่มีอยู่จริงใน SAP**

| Code | ข้อความ |
|---|---|
| `ZARI002/200` | Company code &1 does not exist |
| `ZARI002/201` | G/L account &1 does not exist in company code &2 |
| `ZARI002/202` | Payment method &1 is not known to this interface |
| `ZARI002/203` | Payment method &1 does not exist for country &2 |
| `ZARI002/204` | Currency for company code &1 cannot be determined |
| `ZARI002/205` | Item &1: customer &2 does not exist |
| `ZARI002/206` | Item &1: document &2 already cleared or reversed — ⬜ ยังไม่เปิดใช้ (OQ-08) |

`202` = คำที่ส่งมาไม่อยู่ในรายการแปลง (ดู §6.2) · `203` = แปลงได้แต่ code ไม่มีใน SAP

**`900` — ข้อผิดพลาดทางเทคนิค**

| Code | ข้อความ |
|---|---|
| `ZARI002/900` | Unexpected error: &1 |

> `&1` ของทุก message ที่เกี่ยวกับ item คือ **`SalesforceItemId`** เสมอ
> ยกเว้น `111` ที่เกิดตอนไม่ได้ส่ง id มา จึงอ้างถึงไม่ได้

## 9. ข้อจำกัด

| | |
|---|---|
| จำนวน item ต่อ request | ⬜ กำหนดหลัง volume test (Phase 7.7) |
| Rate limit | ⬜ |

## 10. ของที่ยังต้องยืนยันกับ Salesforce

1. โครงสร้างจริงของ `ChequeBankBranch` — ตัวอย่าง `0040129` ไม่มีใน bank master ของ SAP
   น่าจะเป็น bank 3 หลัก + branch 4 หลัก · ตอนนี้จึงยังไม่ validate
2. รายการคำ `PaymentMethod` ทั้งชุดที่จะส่ง (ตอนนี้รู้แค่ `Cheque` / `Transfer`)
3. `PaymentAmount` ต้องเท่ากับผลรวม `AmountPaid` ของทุก item หรือไม่ —
   ตอนนี้**ไม่ตรวจ** แต่เว้นที่ไว้ให้เพิ่มทีหลังแล้ว
