# ZARI002 — Architecture Design

> Design decision ยืนยันแล้ว 2026-08-27 · ข้อที่ mark ⚠️ ยังรอข้อมูล/ผลทดสอบเพิ่ม

## 1. Requirement สรุป

- OData API สำหรับให้ **Salesforce ส่งข้อมูล incoming payment เข้ามาเก็บใน SAP**
- ไม่มี UI — ถูกเรียกจาก non-SAP system ผ่าน HTTPS
- Payload เป็น **nested JSON**: 1 payment header มีหลาย item
- Logic คือ validate แล้ว **save ลง 2 table ให้ถูกต้อง** — ไม่ post FI ใน RICEFW นี้

```
POST /Payment
{
  "SalesforceId": "...",          ← header
  "CompanyCode": "...",
  ...
  "_Item": [                      ← items
    { "SalesforceItemId": "...", ... },
    { "SalesforceItemId": "...", ... }
  ]
}
```

## 2. ทำไมถึงเป็น RAP managed BO

ข้อมูลลง **custom table ของเราเอง** ทั้งหมด ไม่ได้ไปยุ่งกับ BO มาตรฐานของ SAP
→ managed runtime จัดการ INSERT, UUID generation, admin field, locking, LUW ให้หมด
เราเขียนแค่ determination + validation

| | ผล |
|---|---|
| Deep insert | managed composition รองรับ `_Item[]` ใน payload เดียว out-of-the-box |
| UUID key | `field ( numbering : managed )` — RAP gen `payment_uuid` / `item_uuid` และผูก parent ให้เอง |
| Admin field | `created_by/at`, `last_changed_by/at`, `local_last_changed_at` เติมอัตโนมัติผ่าน BDEF |
| Transaction | 1 request = 1 LUW → validation ไม่ผ่านข้อเดียว rollback ทั้งชุด ตรงกับ requirement |
| ไม่มี draft | เป็น API ล้วน ไม่มี UI ที่ต้องเซฟค้าง → ไม่ต้องมี draft table |

ทางเลือกที่ตัดทิ้ง — **unmanaged BO**: ต้องเขียน INSERT / lock / numbering เองทั้งหมด
ได้อิสระที่ไม่จำเป็นต้องใช้ในงานนี้เลย

## 3. การปรับ table (2026-08-27)

Table ทั้ง 2 ตัวออกแบบไว้ก่อนหน้าแล้ว ปรับ 3 จุดเพื่อให้ประกอบเป็น RAP BO ได้

| # | จุดที่ปรับ | เหตุผล |
|---|-----------|--------|
| 3.1 | `ztar_i002_item`: เพิ่ม field `currency : abap.cuky` และย้าย `@Semantics.amount.currencyCode` มาชี้ `'ztar_i002_item.currency'` | เดิมชี้ข้ามไป `ztar_i002_pymt.currency` — ระดับ DDIC ผ่าน แต่ **CDS view entity ต้องการ currency reference ที่เป็น element ในตัวเอง** ถ้าไปดึงผ่าน association path จะกลายเป็น element ที่ไม่มีที่เก็บจริง managed runtime เขียนกลับไม่ได้ · ค่าถูกเติมด้วย determination `setItemDefaults` ไม่ใช่ input จาก API |
| 3.2 | `ztar_i002_item`: rename `salesforce_id` → `salesforce_item_id` | item เดิมไม่มี business key เลย มีแต่ `item_uuid` ที่ระบบ gen → error message อ้างกลับไม่ได้ว่าเป็น item ไหน · field นี้ทำหน้าที่เป็นทั้ง business key และ item number |
| 3.3 | ทั้ง 2 table: `status : abap.char(1)` → `status : ze_status` (domain `ZD_STATUS`) | ได้ fixed value + label ฟรี ทั้งใน ADT และใน OData metadata · สำคัญกับ **ZARE002** ที่เป็น UI · ทำตอนนี้เพื่อไม่ต้อง convert table ซ้ำตอนมีข้อมูลจริงแล้ว |

`ZD_STATUS` เป็น domain กลาง **ไม่ใส่ RICEFW ID ในชื่อ** เพื่อให้ RICEFW อื่น reuse ได้

### 3.4 Admin field ของ header กับ item ไม่เท่ากัน — **ตั้งใจ ไม่ใช่ของที่ตกหล่น**

| Table | admin field |
|---|---|
| `ZTAR_I002_PYMT` | `created_by` `created_at` `last_changed_by` **`last_changed_at`** `local_last_changed_at` |
| `ZTAR_I002_ITEM` | `created_by` `created_at` `last_changed_by` — `local_last_changed_at` |

เป็น pattern มาตรฐานของ RAP ห้ามไป "แก้ให้เท่ากัน" ความหมายของ 2 field ต่างกัน:

- `local_last_changed_at` (`abp_locinst_lastchange_tstmpl`) = **instance ตัวนี้ตัวเดียว** ถูกแก้เมื่อไหร่ → ใช้เป็น `etag master`
- `last_changed_at` (`abp_lastchange_tstmpl`) = instance นี้ **หรือลูกตัวใดก็ได้ในสายพันธุ์** ถูกแก้เมื่อไหร่ → ใช้เป็น `total etag` ที่ผูกกับ `lock master`

Root จึงต้องมีทั้งคู่เพราะเป็นทั้ง etag master และ lock master ที่ถือ total etag
ส่วน child เป็น `lock dependent by _Payment` ไม่ได้ถือ total etag จึงต้องการแค่ตัวแรก

```abap
define behavior for ZR_ZARI002 alias Payment
persistent table ztar_i002_pymt
lock master total etag LastChangedAt
etag master LocalLastChangedAt
...
define behavior for ZI_ZARI002_ITEM alias Item
persistent table ztar_i002_item
lock dependent by _Payment
etag master LocalLastChangedAt
```

item จึงมี optimistic concurrency ของตัวเองเต็มรูปแบบ — **ZARE002 แก้คนละ item
ใน payment เดียวกันพร้อมกันได้ไม่ชนกัน**

| ค่า | ความหมาย | ใครเขียน |
|-----|----------|---------|
| `N` | New — รับเข้ามาแล้ว รอ post | **ZARI002** |
| `S` | Success — post FI สำเร็จ | ZARE002 |
| `W` | Warning — post สำเร็จแต่มีข้อสังเกต | ZARE002 |
| `E` | Error — post ไม่สำเร็จ (ดู `error_message`) | ZARE002 |

ZARI002 เขียน `N` อย่างเดียว และปล่อย `error_message` ว่างเสมอ

## 4. Error handling — reject ทั้ง request

validate ไม่ผ่านข้อไหนก็ตาม → **HTTP 400 + message list ครบทุกข้อ ไม่บันทึกอะไรลง table เลย**

| | เหตุผล |
|---|---|
| ข้อมูลใน table สะอาด | ทุก row ที่มีอยู่ = ข้อมูลที่ผ่าน validation แล้ว ZARE002 ไม่ต้องเช็คซ้ำ |
| ไม่มีขยะสะสม | ถ้ารับเข้ามาหมดแล้ว flag error จะมี row ที่ไม่มีวันถูก post ค้างใน table |
| ความรับผิดชอบชัด | ข้อมูลผิด = ฝั่ง Salesforce แก้แล้วยิงใหม่ ไม่มีใครต้องมานั่งแก้ใน SAP |

RAP `strict ( 2 )` รวบ message จากทุก validation ที่ fail ในรอบเดียวส่งกลับพร้อมกัน
Salesforce จึงเห็นปัญหาทั้งหมดในครั้งเดียว ไม่ต้องยิงไล่แก้ทีละข้อ

## 5. Idempotency — `salesforce_id` unique

กันเคส Salesforce timeout แล้วยิงซ้ำจน payment ซ้ำใน SAP · ทำ **2 ชั้น**

1. **RAP validation `validateSalesforceId`** — `SELECT SINGLE` เช็คว่ามีอยู่แล้วไหม
   ถ้ามี → 400 พร้อม message ที่อ่านรู้เรื่อง (จับได้ 99.9% ของเคสจริง)
2. **Unique secondary index** บน `ZTAR_I002_PYMT` (`client` + `salesforce_id`)
   จับเคส race ที่ validation จับไม่ได้ — request 2 ตัวยิงพร้อมกัน SELECT ไม่เจอกันเอง
   ผ่าน validation ทั้งคู่ แล้วมา INSERT ชนกันตอน save

⚠️ ชั้นที่ 2 ถ้า fire จะออกมาเป็น **HTTP 500** ไม่ใช่ 400 เพราะพังใน save phase
เนื่องจากไม่ได้เปิด read operation ให้ Salesforce query กลับ ต้องระบุใน API spec ว่า
**500 จากการยิงซ้ำ = ให้ถือว่าอาจสร้างสำเร็จไปแล้ว ห้าม retry ซ้ำอัตโนมัติ** ต้องให้คนตรวจสอบ

> ถ้าภายหลังพบว่าเคสนี้เกิดบ่อย ทางแก้คือเปิด read operation เพิ่ม (ดู §8)

## 6. Validation strategy

แยกเป็น 2 กลุ่ม ทั้งคู่ทำใน validation ของ BDEF

**กลุ่ม A — format / mandatory / consistency** (ไม่แตะ master data, unit test ได้ 100%)

| Validation | Entity | ตรวจอะไร |
|---|---|---|
| `validateSalesforceId` | Payment | mandatory + ไม่ซ้ำใน table |
| `validateMandatory` | Payment | 8 field บังคับ ครบไหม (ดู `04_field_mapping.md`) |
| `validateChequeFields` | Payment | ถ้าจ่ายด้วยเช็ค → `cheque_no` `issue_date` `due_on` `cheque_bankbranch` ต้องครบ |
| `validatePaymentTotal` | Payment | **ที่ว่างไว้ ยังไม่ใส่ logic** — เผื่อภายหลังต้องเทียบ `payment_amount` กับผลรวม `amount_paid` |
| `validateNumberOfItems` | Payment | ต้องเท่ากับจำนวน `_Item` ที่ส่งมาจริง |
| `validateAmounts` | Payment | mandatory + ไม่ติดลบ |
| `validateDates` | Payment | รูปแบบวันที่ + `due_on` ต้องไม่ก่อน `issue_date` |
| `validateSalesforceItemId` | Item | mandatory + ไม่ซ้ำกันเองภายใน payment เดียวกัน |
| `validateItemAmounts` | Item | mandatory + ไม่ติดลบ |

**กลุ่ม B — master data** ⚠️ ต้อง verify release state บน tenant ก่อน (Phase 1)

| Validation | Field | Released CDS view ที่ตั้งใจใช้ |
|---|---|---|
| `validateCompanyCode` | `company_code` | `I_CompanyCode` |
| `validateGLAccount` | `gl_account` | `I_GLAccountInCompanyCode` |
| `validateCurrency` | `currency` | `I_Currency` |
| `validatePaymentMethod` | `payment_method` | `I_PaymentMethod` |
| `validateCustomerCode` | `customer_code` (Item) | `I_Customer` |
| `validateChequeBankBranch` | `cheque_bankbranch` | `I_Bank_2` — `BankCountry` derive จาก `Country` ของ company code |

**ไม่ validate**: `billing_document`, `accounting_document` — เป็นเลขอ้างอิงฝั่ง Salesforce
ที่อาจยังไม่มีใน SAP ตอนส่งเข้ามา (ตกลง 2026-08-27 — ถ้าต้องการเพิ่มทีหลังบอกได้)

การอ่าน master data ทั้งหมดผ่าน **`ZIF_ZARI002_MD_CHECK`** เพื่อให้ unit test ใส่ test double ได้
ไม่ต้องพึ่งข้อมูลจริงบน tenant

## 7. Determination

| Determination | Entity | ทำอะไร |
|---|---|---|
| `setPaymentDefaults` | Payment | `status = 'N'`, เคลียร์ `error_message`, เติม `currency` ถ้าไม่ได้ส่งมา **และ push `currency` ลงทุก item** |
| `setItemDefaults` | Item | `status = 'N'`, เคลียร์ `error_message` |

ทั้งคู่เป็น `determination on save { create; }` — ทำงานก่อน validation ในลำดับ RAP save sequence

### ทำไม `currency` ของ item ถึงเติมจาก determination ฝั่ง header ไม่ใช่ฝั่ง item

RAP **ไม่การันตีลำดับ**ของ determination ข้าม entity — ถ้าให้ item ไปอ่าน `currency`
ของ parent เอง อาจอ่านตอนที่ header ยังไม่ได้เติมค่า (กรณี Salesforce ไม่ส่ง currency มา
แล้วต้อง derive จาก company code) แล้วได้ค่าว่างแบบเงียบ ๆ

`setPaymentDefaults` จึงหา currency ให้เสร็จในที่เดียว แล้วเขียนลง item ทั้งหมดด้วย EML
ในจังหวะเดียวกัน — ลำดับถูกต้องแน่นอนเพราะอยู่ใน method เดียว

### Currency มาจากไหน

**ธุรกิจใช้สกุลเงินเดียวตาม company code** (ยืนยัน 2026-08-27) → `setPaymentDefaults`
ดึง `Currency` ของ `CompanyCode` จาก `I_CompanyCode` มาเติมเสมอ แล้ว push ลงทุก item

การอ่าน `I_CompanyCode` ครั้งเดียวได้ทั้ง `Currency` และ `Country` (ตัวหลังใช้เป็น
`BankCountry` ตอน validate `cheque_bankbranch`) — ไม่ต้องอ่านซ้ำ

⚠️ ถ้าวันหน้ามีรับชำระสกุลต่างประเทศ ต้องกลับมาเปิด `Currency` เป็น input ใหม่

## 8. สิ่งที่จงใจไม่ทำในรอบนี้

| ไม่ทำ | ถ้าจะเพิ่มทีหลังต้องทำอะไร |
|---|---|
| Read / Update / Delete operation | เปิดใน behavior projection + service definition — ไม่กระทบ table |
| Validate `billing_document` / `accounting_document` | เพิ่ม validation + method ใน `ZIF_ZARI002_MD_CHECK` |
| Authorization object แยก (`Z_ZARI002`) | ตอนนี้ใช้ `authorization master ( global )` + คุมสิทธิ์ที่ communication arrangement |
| Application log | ถ้าต้องการ audit trail ของ request ที่ถูก reject ต้องเพิ่ม log table (ตอนนี้ reject แล้วไม่เหลือร่องรอยฝั่ง SAP) |

## 9. ความสัมพันธ์กับ ZARE002

ZARI002 กับ ZARE002 คุยกันผ่าน **table + field `status` เท่านั้น** ไม่มี call ตรงระหว่างกัน

- ZARI002 เป็นเจ้าของ contract ของ table (ใครแก้โครงสร้างต้องคุยกัน)
- ZARE002 อ่าน row ที่ `status = 'N'` ไป post แล้วเขียนกลับเป็น `S` / `W` / `E`
- ⚠️ ถ้าภายหลัง ZARI002 เปิด update/delete ต้องคุมไม่ให้แก้ row ที่ ZARE002 กำลัง post อยู่
