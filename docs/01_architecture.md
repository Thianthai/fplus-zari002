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
| `validateChequeFields` | Payment | ถ้า `sap_payment_method` = เช็ค → `cheque_no` `issue_date` `due_on` `cheque_bankbranch` ต้องครบ (ดูจาก code ที่แปลงแล้ว ไม่ใช่คำดิบ) |
| `validatePaymentTotal` | Payment | **ที่ว่างไว้ ยังไม่ใส่ logic** — เผื่อภายหลังต้องเทียบ `payment_amount` กับผลรวม `amount_paid` |
| `validateNumberOfItems` | Payment | ต้องเท่ากับจำนวน `_Item` ที่ส่งมาจริง |
| `validateDates` | Payment | `due_on` ต้องไม่ก่อน `issue_date` |
| `validateSalesforceItemId` | Item | mandatory + ไม่ซ้ำกันเองภายใน payment เดียวกัน |
| `validateItemMandatory` | Item | 8 field บังคับของ item ครบไหม |

**กลุ่ม B — master data** ⚠️ ต้อง verify release state บน tenant ก่อน (Phase 1)

| Validation | Field | Released CDS view ที่ตั้งใจใช้ |
|---|---|---|
| `validateCompanyCode` | `company_code` | `I_CompanyCode` |
| `validateGLAccount` | `gl_account` | `I_GLAccountInCompanyCode` |
| `validatePaymentMethod` | `sap_payment_method` | `I_PaymentMethod` เช็คแค่ว่า code มีจริง · ถ้าแปลงไม่ได้ (คำที่ไม่รู้จัก) ต้องแจ้งคำที่ส่งมาในข้อความด้วย |
| `validateCustomerCode` | `customer_code` (Item) | `I_Customer` |
| `validateChequeBankBranch` | `cheque_bankbranch` | **ที่ว่างไว้ ยังไม่ใส่ logic** — โครงสร้างของ field ยังไม่ชัด (`0040129` ไม่มีใน `I_Bank_2`) ดู `04_field_mapping.md` §7.2 |

**ไม่เช็คเครื่องหมายจำนวนเงิน** — sample จริงมี `rounding_diff = -1.00` และ
`advance_payment = -100.00` ซึ่งถูกต้องตามธุรกิจ · ปล่อยให้ ZARE002 ไปเจอเองตอน post

### Normalize ก่อน validate

Salesforce ส่ง `gl_account` มาแบบ **ไม่มี leading zero** (`11011214`) แต่ SAP เก็บเต็ม 10 หลัก
(`0011011214`) → ถ้าเทียบตรง ๆ ไม่มีวันเจอ และ ZARE002 จะได้ GL account ที่ post ไม่ได้

`setPaymentDefaults` / `setItemDefaults` จึง **pad ซ้ายด้วย `0` ให้ครบ 10 หลัก** ทั้ง
`gl_account` และ `customer_code` ก่อน แล้ว validation ค่อยทำงานกับค่าที่ normalize แล้ว
— กันเคสที่ต้นทางส่งมาบ้างไม่ส่งมาบ้างด้วย

**ไม่ validate**: `billing_document`, `accounting_document` — เป็นเลขอ้างอิงฝั่ง Salesforce
ที่อาจยังไม่มีใน SAP ตอนส่งเข้ามา (ตกลง 2026-08-27 — ถ้าต้องการเพิ่มทีหลังบอกได้)

การอ่าน master data ทั้งหมดผ่าน **`ZIF_ZARI002_MD_CHECK`** เพื่อให้ unit test ใส่ test double ได้
ไม่ต้องพึ่งข้อมูลจริงบน tenant

## 7. Determination

| Determination | Entity | ทำอะไร |
|---|---|---|
| `setPaymentDefaults` | Payment | อ่าน `I_CompanyCode` ครั้งเดียวได้ `Currency` + `Country` → เติม `currency` ให้ header **และ push ลงทุก item** · `status = 'N'` · เคลียร์ `error_message` |
| `setPaymentMethodCode` | Payment | แปลงคำจาก Salesforce (`payment_method`) → SAP code (`sap_payment_method`) ด้วย constant ใน `ZCL_ZARI002_VALIDATOR` — `Cheque` → `A` · `Transfer` → `T` |
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

## 9. ความสัมพันธ์กับ ZARE002 และ ZARI003

ทั้ง 3 รหัสคุยกันผ่าน **table + field `status` เท่านั้น** ไม่มี call ตรงระหว่างกัน

| RICEFW | หน้าที่ | ทำอะไรกับ table |
|---|---|---|
| **ZARI002** (งานนี้) | รับข้อมูลจาก Salesforce | insert อย่างเดียว · `status = 'N'` |
| **ZARE002** | RAP UI post FI | อ่าน row `N` → update `status` = `S`/`W`/`E` + `error_message` |
| **ZARI003** | ส่งผล post กลับ Salesforce | อ่านอย่างเดียว |

- ZARI002 เป็นเจ้าของ contract ของ table (ใครแก้โครงสร้างต้องคุยกัน)
- **ZARI003 เป็นคำตอบว่า Salesforce รู้ผล post ได้ยังไง** — ZARI002 จึงไม่ต้องเปิด read
  operation ให้ Salesforce poll และยืนยันว่า create-only ถูกต้องแล้ว
- `sap_payment_method` เป็น field ที่ ZARE002 ใช้ post FI ไม่ใช่ `payment_method` ที่เป็นคำดิบ
- ⚠️ ถ้าภายหลัง ZARI002 เปิด update/delete ต้องคุมไม่ให้แก้ row ที่ ZARE002 กำลัง post อยู่


---

## 10. ข้อมูลจริงบน tenant (spike `ZCL_ZARI002_SPIKE_MD` — 2026-08-27)

released CDS view ใช้ได้ครบทั้ง 6 ตัว ชื่อ field ตรงตามที่ออกแบบไว้ทั้งหมด

| View | ผล |
|---|---|
| `I_CompanyCode` | `1000`, `2000` — **ทั้งคู่ `THB` / `TH`** → derive currency + bank country ได้จริง |
| `I_GLAccountInCompanyCode` | ใช้ได้ · format บน tenant มี leading zero เต็ม 10 หลัก เช่น `0011001000` |
| `I_Currency` | `THB` ✅ |
| `I_PaymentMethod` | TH มี 10 code — ดูตารางข้างล่าง |
| `I_Customer` | **มีแค่ 3 ราย**: `1000000002` `1000000003` `1000000004` |
| `I_Bank_2` | key = `BankCountry` + `BankInternalID` · ค่าบน tenant เป็น **รหัส 3 หลัก**: `002 004 006 008 009 011 014 017 018 020` |

⚠️ **`I_Customer` มีแค่ 3 ราย** แต่ sample data ของ Salesforce อ้างถึง customer อย่างน้อย 8 ราย
(`1000000001` `1000000005` `1000000013` `1000000020` `1000000021` …) → ถ้าไม่โหลด customer เพิ่ม
`validateCustomerCode` จะ reject sample แทบทุกใบ **ต้องเตรียม test data ก่อน Phase 7**


### Payment method บน tenant (TH)

| Code | ชื่อ | ใช้กับเช็ค | สำหรับ **incoming payment** |
|---|---|---|---|
| `A` | Manual Cheque | **X** | |
| `B` | BAHTNET | | |
| `C` | Cheque Direct | | |
| `E` | Direct Debit | | **X** |
| `F` | Bank Transfer–Foreign | | |
| `I` | iCash | | |
| `M` | Direct Debit Customer Payments | | **X** |
| `N` | Card Payment | | **X** |
| `S` | Cash Payment | | |
| `T` | Bank Transfer | | |

**Mapping ที่ใช้**: `Cheque` → `A` (Manual Cheque) · `Transfer` → `T` (Bank Transfer)

⚠️ **`IsPaymentMethodForIncomingPayments` ติ๊กไว้แค่ `M` `N` `E`** — ไม่รวม `A` หรือ `T`
ที่ Salesforce ส่งเข้ามาจริง ทั้งที่ ZARI002 เป็น interface ของ **incoming payment**

ตกลงว่า **ZARI002 ไม่เช็ค flag นี้** (เช็คแค่ว่า code มีจริง) เพราะถ้าเช็คจะ reject ทุกใบ
ตั้งแต่วันแรกและ Phase 7 เทสไม่ได้เลย — แต่ **ต้องแจ้งทีม FI ให้ตรวจ config ขนานกันไป**
ถ้า config นี้ถูกต้องตามที่ใช้จริง **ZARE002 จะ post ไม่ผ่าน** และจะไปเจอตอนนั้นแทน
เราแค่ย้ายจุดที่ปัญหาจะโผล่ ไม่ได้แก้มัน

### ยืนยันจาก spike รอบ 2

- **leading zero**: pad `11011214` → `0011011214` แล้ว **เจอครบ 3/3** บน company code `2000`
  → determination ที่ pad ก่อน validate ทำงานถูกต้องแน่นอน
- **`cheque_bankbranch`**: `004` มีใน `I_Bank_2` แต่ `0040129` **ไม่มี** → ยืนยันว่า field นี้
  ไม่ใช่ `BankInternalID` ล้วน เป็น bank + branch ประกอบกัน
