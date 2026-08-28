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
| 3.3 | ทั้ง 2 table: `status : abap.char(1)` → data element ที่มี domain | ได้ fixed value + label ฟรี ทั้งใน ADT และ OData metadata |

### 3.3.1 โครงสร้าง status ฉบับปรับใหญ่ (2026-08-28)

แยกเป็น **2 domain คนละหน้าที่** และ **ย้ายทั้งหมดไปอยู่ที่ระดับ header เท่านั้น**

| Field (header) | Domain | หน้าที่ | ใครเขียน |
|---|---|---|---|
| `status` | `ZD_REQUEST_STATUS` | **transaction status** — payment ใบนี้อยู่ขั้นไหนของกระบวนการ | ZARI002 เขียน `N` · ZARE002 เขียนที่เหลือ |
| `salesforce_status` | `ZD_RESPONSE_STATUS` | **result status** ที่ส่งกลับ SFDC | ZARE002 |
| `salesforce_message` | `char(200)` | ข้อความคู่กับ `salesforce_status` | ZARE002 |

`ZD_REQUEST_STATUS`: `N` New · `C` Complete · `R` Reject · `E` Error
`ZD_RESPONSE_STATUS`: `S` Success · `W` Warning · `E` Error

**item ไม่มี status และไม่มี message แล้ว** — error อะไรก็ตามถือเป็น error ของ payment ทั้งใบ
item มีแค่ `reject_reason` (char 200) ซึ่ง **ZARI002 ไม่เคยเขียน** เป็นของ ZARE002 ที่อยากระบุว่า
item ไหนมีปัญหา

⚠️ **ZARI002 เขียนแค่ `status = 'N'` ตัวเดียว** — `salesforce_status`, `salesforce_message`
และ `reject_reason` ปล่อยว่างเสมอ เพราะ reject-all แปลว่าใบที่มีปัญหาไม่ถูกบันทึกตั้งแต่แรก

`ZD_STATUS` / `ZE_STATUS` ชุดเดิมไม่มี table ไหนใช้แล้ว — เก็บไว้ให้ RICEFW อื่น reuse

| 3.4 | `batch_id` char(20) | SAP สร้างตอนรับ รูปแบบ `YYYYMMDD_hhmmss` — ไม่ใช่ input จาก SFDC |

### 3.4 Admin field ของ header กับ item ไม่เท่ากัน — **ตั้งใจ ไม่ใช่ของที่ตกหล่น**

| Table | admin field |
|---|---|
| `ZTAR_I002_PYMT` | `created_by` `created_at` `last_changed_by` **`last_changed_at`** `local_last_changed_at` |
| `ZTAR_I002_ITEM` | `created_by` `created_at` `last_changed_by` — `local_last_changed_at` |

เป็น pattern มาตรฐานของ RAP ห้ามไป "แก้ให้เท่ากัน" ความหมายของ 2 field ต่างกัน:

- `local_last_changed_at` (`abp_locinst_lastchange_tstmpl`) = **instance ตัวนี้ตัวเดียว** ถูกแก้เมื่อไหร่ → ใช้เป็น `etag master`
- `last_changed_at` (`abp_lastchange_tstmpl`) = instance นี้ **หรือลูกตัวใดก็ได้ในสายพันธุ์** ถูกแก้เมื่อไหร่ → ตั้งใจไว้ให้เป็น `total etag`

⚠️ **แต่ `total etag` ประกาศได้เฉพาะ BO ที่มี draft** (พิสูจน์ตอน activate BDEF 2026-08-27:
`A "total etag" field can be flagged only if "with draft" is used.`) — BO นี้เป็น API ไม่มี draft
จึงใช้ `lock master` เปล่า ๆ และ **ไม่ได้ประกาศ `total etag` เลย**

```abap
define behavior for ZR_ZARI002 alias Payment
persistent table ztar_i002_pymt
lock master
etag master LocalLastChangedAt
...
define behavior for ZI_ZARI002_ITEM alias Item
persistent table ztar_i002_item
lock dependent by _Payment
etag master LocalLastChangedAt
```

`last_changed_at` ยังอยู่ใน table และยังถูก managed runtime เติมให้จาก annotation
`@Semantics.systemDateTime.lastChangedAt` ใน CDS (คนละกลไกกับ etag) — **ZARE002 ใช้ได้ตามปกติ**
และถ้าวันหน้าทำ draft ก็พร้อมใช้เป็น total etag ทันที

✅ **ยืนยันแล้ว (2026-08-28)** — ทดสอบ EML deep create จริง `last_changed_at` ถูกเติมค่า
`20260828071522.850218` ตอน create ทั้งที่ไม่ได้ประกาศ `total etag` เลย
→ การเติม admin field มาจาก annotation ใน CDS ล้วน ๆ ไม่ได้ผูกกับ etag **ZARE002 ใช้ได้ตามปกติ**

item ยังมี optimistic concurrency ของตัวเองเต็มรูปแบบผ่าน `local_last_changed_at` —
**ZARE002 แก้คนละ item ใน payment เดียวกันพร้อมกันได้ไม่ชนกัน**

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

## 5. Duplicate check (เดิมคือ Idempotency)

**key = `payment_document_no` (header) + `billing_document` (item)** — ถ้าคู่นี้เคยมีใน table
แล้ว reject ทั้ง request ด้วย `ZARI002/010`

ตรวจ **ทุกสถานะ** ไม่กรองตาม `status` (ตกลง 2026-08-28: *ห้ามส่งซ้ำถ้าเคยส่งมาแล้ว*)
`status` จึงอยู่ในนิยาม key ตามที่ธุรกิจอธิบาย แต่ไม่ได้ทำหน้าที่กรองในทางปฏิบัติ

### `salesforce_id` ไม่ใช่ key กันซ้ำอีกต่อไป

SFDC ยืนยันว่าเมื่อถูก reject จะแก้ข้อมูลแล้วส่งกลับมาด้วย `salesforce_id` และ
`salesforce_item_id` **เดิม** — เป็น key ฝั่งเขา ไม่ใช่ของเรา

→ **unique index `ZTAR_I002_PYMT~SFI` ต้องถูกลบ** ไม่งั้นจะบล็อก flow นี้

เคสที่ปลอดภัยอยู่แล้ว: ใบที่ถูก reject ไม่ได้ถูกบันทึกตั้งแต่แรก (reject-all) ส่งใหม่ด้วย id เดิมได้
เคสที่ index จะพัง: ใบที่บันทึกสำเร็จแล้ว ZARE002 post ไม่ผ่าน แล้ว SFDC ส่งใบเดิมกลับเข้ามา

### ⚠️ เสียตาข่ายระดับ DB

key คร่อม 2 table จึงทำ unique index ไม่ได้ — เหลือ **validation ชั้นเดียว**
2 request ที่เหมือนกันและยิงพร้อมกันจริง ๆ จะ SELECT ไม่เจอกันเอง ผ่าน validation ทั้งคู่
แล้วเข้าไปทั้งคู่ · **ยอมรับความเสี่ยงนี้แล้ว (2026-08-28)**

### ⚠️ ผลข้างเคียงที่ต้องรู้

ใบที่บันทึกสำเร็จแล้วแต่ ZARE002 post ไม่ผ่าน **SFDC ส่งเข้ามาแก้ไม่ได้** เพราะจะโดนจับเป็น
duplicate — การแก้ต้องทำฝั่ง SAP

## 6. Validation strategy

แยกเป็น 2 กลุ่ม ทั้งคู่ทำใน validation ของ BDEF

**กลุ่ม A — format / mandatory / consistency** (ไม่แตะ master data, unit test ได้ 100%)

| Validation | Entity | ตรวจอะไร |
|---|---|---|
| `validateMandatory` | Payment | 8 field บังคับ ครบไหม (ดู `04_field_mapping.md`) |
| `validateChequeFields` | Payment | ถ้า `sap_payment_method` = เช็ค → `cheque_no` `issue_date` `due_on` `cheque_bankbranch` ต้องครบ (ดูจาก code ที่แปลงแล้ว ไม่ใช่คำดิบ) |
| `validatePaymentTotal` | Payment | **ที่ว่างไว้ ยังไม่ใส่ logic** — เผื่อภายหลังต้องเทียบ `payment_amount` กับผลรวม `amount_paid` |
| `validateAmountPaidTotal` | Payment | ผลรวม `amount_paid` ของทุก item ต้อง **> 0** |
| `validateAmountFormat` | Payment | **ที่ว่างไว้ ยังไม่ใส่ logic** — OData จับค่าที่ไม่ใช่ตัวเลขไปก่อนแล้ว รอนิยามเงื่อนไข (OQ-10) |
| `validateItemDuplicate` | Payment | `payment_document_no` + `billing_document` ต้องไม่เคยมีใน table |
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
| `validateArOpenItem` | `accounting_document` (Item) | **ที่ว่างไว้ ยังไม่ใส่ logic** — ตรวจว่ารายการยังไม่ถูกรับชำระหรือ reverse · ต้องหา released view ที่มีสถานะนี้ก่อน (OQ-08) |
| `validateChequeBankBranch` | `cheque_bankbranch` | **ที่ว่างไว้ ยังไม่ใส่ logic** — โครงสร้างของ field ยังไม่ชัด (`0040129` ไม่มีใน `I_Bank_2`) ดู `04_field_mapping.md` §7.2 |

**ไม่เช็คเครื่องหมายจำนวนเงิน** — sample จริงมี `rounding_diff = -1.00` และ
`advance_payment = -100.00` ซึ่งถูกต้องตามธุรกิจ · ปล่อยให้ ZARE002 ไปเจอเองตอน post

### Normalize ก่อน validate

Salesforce ส่ง `gl_account` มาแบบ **ไม่มี leading zero** (`11011214`) แต่ SAP เก็บเต็ม 10 หลัก
(`0011011214`) → ถ้าเทียบตรง ๆ ไม่มีวันเจอ และ ZARE002 จะได้ GL account ที่ post ไม่ได้

`setPaymentDefaults` / `setItemDefaults` จึง **pad ซ้ายด้วย `0` ให้ครบ 10 หลัก** ทั้ง
`gl_account` และ `customer_code` ก่อน แล้ว validation ค่อยทำงานกับค่าที่ normalize แล้ว
— กันเคสที่ต้นทางส่งมาบ้างไม่ส่งมาบ้างด้วย

**ไม่ validate**: `billing_document` — เป็นเลขอ้างอิงฝั่ง Salesforce ที่อาจยังไม่มีใน SAP

⚠️ `accounting_document` **เคยตกลงว่าไม่ validate แล้วกลับคำ** (2026-08-27) — ตอนนี้ต้องตรวจว่า
รายการยังเปิดอยู่ ผ่าน `validateArOpenItem`

การอ่าน master data ทั้งหมดผ่าน **`ZIF_ZARI002_MD_CHK`** เพื่อให้ unit test ใส่ test double ได้
ไม่ต้องพึ่งข้อมูลจริงบน tenant

## 7. Determination

| Determination | Entity | ทำอะไร |
|---|---|---|
| `setPaymentDefaults` | Payment | อ่าน `I_CompanyCode` ครั้งเดียวได้ `Currency` + `Country` → เติม `currency` ให้ header **และ push ลงทุก item** · สร้าง `batch_id` · pad `gl_account` · `status = 'N'` |
| `setPaymentMethodCode` | Payment | แปลงคำจาก Salesforce (`payment_method`) → SAP code (`sap_payment_method`) ด้วย constant ใน `ZCL_ZARI002_VALIDATOR` — `Cheque` → `A` · `Transfer` → `T` |
| `setItemDefaults` | Item | pad `customer_code` (item ไม่มี status/error แล้ว) |

ทั้งคู่เป็น `determination on save { create; }` — ทำงานก่อน validation ในลำดับ RAP save sequence

### ทำไม `currency` ของ item ถึงเติมจาก determination ฝั่ง header ไม่ใช่ฝั่ง item

RAP **ไม่การันตีลำดับ**ของ determination ข้าม entity — ถ้าให้ item ไปอ่าน `currency`
ของ parent เอง อาจอ่านตอนที่ header ยังไม่ได้เติมค่า (กรณี Salesforce ไม่ส่ง currency มา
แล้วต้อง derive จาก company code) แล้วได้ค่าว่างแบบเงียบ ๆ

`setPaymentDefaults` จึงหา currency ให้เสร็จในที่เดียว แล้วเขียนลง item ทั้งหมดด้วย EML
ในจังหวะเดียวกัน — ลำดับถูกต้องแน่นอนเพราะอยู่ใน method เดียว

### ทำไม BDEF ประกาศ `update;` ทั้งที่ API เปิดแค่ create

determination เขียนค่ากลับเข้า entity ด้วย `MODIFY ENTITIES ... UPDATE ... IN LOCAL MODE`
ซึ่งต้องการให้ BDEF ประกาศ `update;` ไว้ ไม่งั้น derived type `TABLE FOR UPDATE` ไม่มีตัวตน
(`The operation "UPDATE" is not activated for entity "ZR_ZARI002"`)

⚠️ **ตัวที่กัน `update` ไม่ให้รั่วออกไปหา Salesforce คือ behavior projection เท่านั้น**
(`use create;` อย่างเดียว — Phase 5.2) · ถ้าพลาดตรงนั้น Salesforce จะแก้ข้อมูลที่ ZARE002
post ไปแล้วได้

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
| Validate `billing_document` / `accounting_document` | เพิ่ม validation + method ใน `ZIF_ZARI002_MD_CHK` |
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
