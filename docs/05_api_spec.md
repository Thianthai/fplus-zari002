# ZARI002 — API Specification

เอกสารสำหรับ **ทีม Salesforce** เอาไปเขียน client

> 🟨 **Draft (2026-08-27)** — field contract นิ่งแล้ว แต่ **URL จริงยังไม่มี** จนกว่าจะ publish
> service binding ใน Phase 5 · ข้อที่ยัง `⬜` ระบุไว้ชัดเจนในแต่ละหัวข้อ

## 1. ภาพรวม

| | |
|---|---|
| ทำอะไร | รับข้อมูล incoming payment จาก Salesforce มาเก็บใน SAP |
| Protocol | **HTTP Service (REST/JSON)** — เปลี่ยนจาก OData V4 เมื่อ 2026-08-31 |
| Operation | **POST อย่างเดียว** |
| โครงสร้าง | nested JSON — 1 header + N items |
| Transaction | **All-or-nothing** — ผิดข้อเดียว ไม่บันทึกอะไรเลยทั้ง request |
| แจ้งผล | **SAP ยิง callback กลับไปที่ API ของ Salesforce** รายบรรทัด (ดู §9) |

**สิ่งที่ API นี้ไม่ทำ**: ไม่ post FI · ไม่ตอบผลการ post
การ post เป็นงานของ **ZARE002** และการส่งผล post กลับเป็นงานของ **ZARI003**

## 2. Endpoint

```
POST  https://my442178-api.s4hana.cloud.sap/sap/bc/http/sap/zari002_incoming_pymt
Content-Type: application/json
Authorization: Basic <base64 ของ user:password>
```

| | |
|---|---|
| Client | **100** (arrangement ผูกไว้แล้ว — ไม่ต้องส่ง `sap-client`) |
| Auth | Basic · communication user `SBPA_DEV` (รหัสผ่านขอจากผู้ดูแล tenant) |
| Communication scenario | `ZCS_INCOMING_PYMT` |
| Auth ที่รองรับ | Basic · OAuth 2.0 (ยังไม่ได้ตั้ง arrangement สำหรับ OAuth) |

⚠️ **API host ไม่ใช่ host เดียวกับที่เปิดใน browser** — `my442178-api…` สำหรับ API
ส่วน `my442202…` เป็น UI/dev host · เลข tenant ของสองอันไม่เกี่ยวกัน อย่าเดาเอง

## 3. Field ของ header (`Payment`)

**ส่งได้ 15 field** — `✔` = บังคับ · `(✔)` = บังคับเมื่อจ่ายด้วยเช็ค · `–` = optional

| Field | Type | | หมายเหตุ |
|---|---|---|---|
| `SalesforceId` | String(18) | ✔ | **ต้องไม่ซ้ำ** — ใช้กันการยิงซ้ำ (ดู §7) |
| `PaymentDocumentNo` | String(10) | ✔ | เลขที่เอกสารรับชำระเงินฝั่ง Salesforce |
| `NumberOfItemsInPayment` | **Int32** | ✔ | 🔴 **เปลี่ยนชื่อจาก `NumberOfItems` (2026-08-28)** · จำนวนนับ ส่งเป็นตัวเลข `5` ไม่ใช่ `"5"` · ต้องเท่ากับจำนวน `Items` |
| `CompanyCode` | String(4) | ✔ | ต้องมีจริงใน SAP |
| `PostingDate` | Date | ✔ | `YYYY-MM-DD` |
| `GlAccount` | String(10) | ✔ | 🔴 **เดิมชื่อ `GLAccount`** เปลี่ยน 2026-08-31 · **ส่งแบบไม่มี leading zero ได้** — SAP เติมให้เอง (ดู §6.1) |
| `PaymentMethod` | String(8) | ✔ | ส่งเป็น**คำ** เช่น `Cheque`, `Transfer` (ดู §6.2) |
| `ChequeNo` | String(8) | (✔) | |
| `IssueDate` | Date | (✔) | |
| `DueOn` | Date | (✔) | ต้องไม่ก่อน `IssueDate` |
| `ChequeBankBranch` | String(15) | (✔) | ⬜ โครงสร้างยังไม่ยืนยัน ตอนนี้ยังไม่ validate |
| `RoundingDiff` | Decimal(23,2) | – | **ติดลบได้** |
| `AdvancePayment` | Decimal(23,2) | – | **ติดลบได้** |
| `Fees` | Decimal(23,2) | – | |
| `PaymentAmount` | Decimal(23,2) | ✔ | |
| `Items` | array | ✔ | ต้องมีอย่างน้อย 1 รายการ · **เดิมชื่อ `_Item` สมัย OData** เปลี่ยน 2026-08-31 เพราะขึ้นต้นด้วย `_` ทำให้กฎแปลงชื่อเพี้ยน |

**ห้ามส่ง** (ระบบเติมเอง ส่งมาก็ถูกเมิน): `PaymentUuid` · `BatchId` · `Currency` ·
`SapPaymentMethod` · `Status` · `SalesforceStatus` · `SalesforceMessage` ·
field `Created*` / `LastChanged*` ทั้งหมด

## 4. Field ของ item (`Items`)

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
| `BillingDocument` | String(10) | ✔ | **เป็นส่วนหนึ่งของ duplicate key** (ดู §7) |

**ห้ามส่ง**: `ItemUuid` · `PaymentUuid` · `Currency` · `RejectReason` · admin fields

> **item ไม่มี `Status` และ `ErrorMessage` แล้ว** (2026-08-28) — สถานะทั้งหมดอยู่ที่ระดับ
> header เท่านั้น · error อะไรก็ตามถือเป็น error ของ payment ทั้งใบ

## 5. ตัวอย่าง request

```json
{
  "SalesforceId": "b0yfd000000GRsHAAW",
  "PaymentDocumentNo": "1000000001",
  "NumberOfItemsInPayment": 2,
  "CompanyCode": "2000",
  "PostingDate": "2026-08-15",
  "GlAccount": "11011214",
  "PaymentMethod": "Cheque",
  "ChequeNo": "10020185",
  "IssueDate": "2026-07-15",
  "DueOn": "2026-08-31",
  "ChequeBankBranch": "0040129",
  "RoundingDiff": "0.00",
  "AdvancePayment": "60.00",
  "Fees": "5.00",
  "PaymentAmount": "9650.00",
  "Items": [
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

### 6.0 รูปแบบวันที่

รับได้ทั้ง **ISO `"2026-08-15"`** และ **SAP `"20260815"`** — ให้ผลเหมือนกัน

⬜ ⚠️ ค่าที่ไม่ใช่วันที่เลย (เช่น `"abc"`) **ยังไม่ถูกตรวจ** จะกลายเป็นวันที่ขยะ —
ดู OQ-10

### 6.1 Leading zero — ไม่ต้องเติมมา

SAP เก็บ `GlAccount` และ `CustomerCode` เป็น 10 หลักเต็มโดยเติม `0` ข้างหน้า
API **เติมให้เอง** ก่อนตรวจและก่อนบันทึก

**กฎคือ: เติมให้เฉพาะ field ที่มี conversion routine** (ถึงจะไม่ได้เรียกใช้ routine ตรง ๆ ก็ตาม)
· `GlAccount` และ `CustomerCode` มี ALPHA จึงเติมให้
· ⚠️ **`ChequeBankBranch` ไม่มี conversion routine จึงไม่เติมให้** — ต้นทางต้องส่งมาให้ตรงกับ
ที่ SAP เก็บเป๊ะ ไม่งั้นจะได้ `008` ทั้งที่ธนาคารมีอยู่จริง

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

## 7. Duplicate check

`PaymentDocumentNo` (header) คู่กับ `BillingDocument` (item) **ต้องไม่เคยมีอยู่ใน SAP มาก่อน**
ถ้าเคยมี → `400` พร้อม `ZARI002/010` และไม่บันทึกอะไรเลย

ตรวจ **ทุกสถานะ** ไม่ว่าใบเดิมจะอยู่ในสถานะไหน — *ส่งซ้ำไม่ได้ถ้าเคยส่งมาแล้ว*

**`SalesforceId` และ `SalesforceItemId` ซ้ำได้** — เป็น key ฝั่ง SFDC ไม่ได้ใช้กัน duplicate
ถ้า request ถูก reject แล้วแก้ข้อมูลส่งใหม่ **ใช้ id เดิมได้ตามปกติ** เพราะใบที่ถูก reject
ไม่ได้ถูกบันทึกลง SAP ตั้งแต่แรก

⚠️ **แต่ถ้าใบนั้นถูกบันทึกสำเร็จไปแล้ว จะส่งซ้ำเข้ามาแก้ไม่ได้** แม้ ZARE002 จะ post ไม่ผ่าน
— การแก้ต้องทำฝั่ง SAP

⚠️ การตรวจนี้เป็น **validation ชั้นเดียว ไม่มีตาข่ายระดับฐานข้อมูล** (key คร่อม 2 table
จึงทำ unique index ไม่ได้) · 2 request ที่เหมือนกันและยิงพร้อมกันจริง ๆ อาจเข้าไปทั้งคู่

## 8. Response ของ API นี้

⬜ **รูปแบบยังไม่สรุป (OQ-18)** — ผลจริงถูกส่งผ่าน callback (§9) แล้ว response ตัวนี้จึงเหลือ
หน้าที่แค่บอกว่า "รับเรื่องแล้ว" หรือ "ไม่รับเพราะอะไร"

ข้อเสนอ: `200` + จำนวนที่บันทึก · `400` + รายการ error ครบทุกข้อ (รูปแบบเดียวกับ §8.3)

### 8.3 Message code ทั้งหมด

เลขในแต่ละกลุ่ม **run ต่อกันไม่เว้นช่วง** · message ที่เพิ่มใหม่ให้**ต่อท้ายกลุ่มของตัวเอง**
เลขที่ประกาศไปแล้วจะไม่เปลี่ยนอีก ฝั่ง client จึงผูก logic กับ `code` ได้ปลอดภัย

**`0xx` — โครงสร้างและความสอดคล้องของข้อมูล**

| Code | ข้อความ |
|---|---|
| `ZARI002/000` | `&1 &2 &3 &4` — **ข้อความอิสระ** ใช้เมื่อไม่มี code เฉพาะที่ตรงกว่า · ⚠️ client แยกประเภทจาก code ไม่ได้ ใช้เท่าที่จำเป็น |
| `ZARI002/001` | Payment must have at least one item |
| `ZARI002/002` | Number of items &1 does not match &2 items sent |
| `ZARI002/003` | Due date &1 is before issue date &2 |
| ~~`ZARI002/004`~~ | ~~Salesforce ID &1 already exists~~ — **เลิกใช้ 2026-08-28** เลขนี้จะไม่ถูกนำกลับมาใช้ซ้ำ |
| `ZARI002/005` | Duplicate Salesforce item ID &1 |
| `ZARI002/006` | Item &1: partial flag must be X or blank |
| `ZARI002/007` | Payment amount &1 does not match item total &2 — ⬜ ยังไม่เปิดใช้ (OQ-05) |
| `ZARI002/008` | Bank/branch &1 does not exist |
| `ZARI002/009` | Invalid payment data for payment &1. Please verify — ⬜ ไม่ได้เปิดใช้ (ยกเลิกการตรวจ format ตัวเลข 2026-09-04) |
| `ZARI002/010` | Duplicate: payment &1 with billing document &2 exists |
| `ZARI002/011` | Payment &1: received amount must be greater than zero |
| `ZARI002/012` | Request body is not valid JSON |

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


---

## 9. Callback ไปหา Salesforce

หลังจบการประมวลผล **SAP ยิง POST ไปที่ API ของ Salesforce** เพื่อแจ้งผล **รายบรรทัด**

| Field | Type | | ที่มา |
|---|---|---|---|
| Salesforce ID (Header) | CHAR(18) | R | `salesforce_id` |
| Salesforce ID (Item) | CHAR(18) | R | `salesforce_item_id` — key ที่ SFDC ใช้จับคู่ |
| Status | CHAR(1) | R | `S` = บันทึกสำเร็จ · `E` = ไม่บันทึก |
| Error Message | CHAR(200) | C | มีเมื่อ `E` |

**ยิงทั้งกรณีสำเร็จและไม่สำเร็จ** — เคส error ต้องยิงระหว่าง request เพราะ reject-all
ไม่ได้บันทึก row ไว้ให้ตามไปแจ้งทีหลัง

⚠️ **fire and forget** — ไม่เก็บสถานะว่าแจ้งไปแล้วหรือยัง (ตกลง 2026-08-31) ·
ถ้า callback ล้ม ข้อมูลจะอยู่ใน SAP โดยที่ SFDC ไม่รู้ และ **retry ไม่ได้**

⚠️ `Status` ตัวนี้เป็นคนละตัวกับ `status` (`N`/`C`/`R`/`E`) และ `salesforce_status` (`S`/`W`/`E`)
ที่เก็บใน table — ตัวนี้ตอบแค่ว่า "SAP รับข้อมูลได้ไหม"
