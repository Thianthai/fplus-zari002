# ZARI002 — ทะเบียนข้อสงสัย

รวมทุกอย่างที่ยัง**ไม่เคลียร์** ไว้ที่เดียว — **รีวิวทุกครั้งที่จบ phase** (ตกลง 2026-08-27)

> **บริบท**: master data บน tenant ยัง config ไม่เสร็จ · ABAP implement รอไว้ก่อนเพื่อไม่ให้เสียเวลา
> เจอจุดไหนไม่ชัดให้ **note ไว้ที่นี่แล้วเดินต่อ** อย่าหยุดรอ

สถานะ: `⬜` เปิดอยู่ · `🟨` มีคำตอบชั่วคราวแล้ว เดินต่อได้ · `✅` ปิด

| # | เรื่อง | เจ้าของคำตอบ | ยกมาจาก | บล็อกอะไร | สถานะ |
|---|--------|-------------|---------|-----------|--------|
| OQ-01 | โครงสร้างจริงของ `cheque_bankbranch` — ตัวอย่าง `0040129` ไม่มีใน `I_Bank_2` แต่ `004` มี · น่าจะเป็น bank 3 หลัก + branch 4 หลัก | Salesforce / FI | Phase 1 | `validateChequeBankBranch` เป็นที่ว่างไว้ · field คง `char(15)` ไว้ก่อน | 🟨 |
| OQ-02 | รายการคำ `payment_method` ทั้งชุดที่ Salesforce จะส่ง (ตอนนี้รู้แค่ `Cheque` / `Transfer`) · ⚠️ **`Transfer` ยาว 8 ตัวเต็ม `char(8)` พอดี ไม่เหลือที่ว่าง** — คำใหม่ที่ยาวกว่านี้จะส่งเข้ามาไม่ได้เลยตั้งแต่ชั้น OData ต้องขยาย field ก่อน (พิสูจน์จาก compiler 2026-08-28) | Salesforce | Phase 1 | mapping constant ไม่ครบ → คำที่ไม่รู้จักถูก reject · คำที่ยาวเกิน 8 ส่งไม่ได้เลย | 🟨 |
| OQ-03 | `IsPaymentMethodForIncomingPayments` ติ๊กแค่ `M` `N` `E` ไม่รวม `A` / `T` ที่ใช้จริง | FI | Phase 1 | ZARI002 ไม่เช็ค flag นี้ แต่ **ZARE002 จะ post ไม่ผ่านถ้า config ถูกต้องจริง** | ⬜ |
| OQ-04 | master data บน tenant ยังไม่ครบ — `I_Customer` ขึ้นเป็น **8 ราย** แล้ว (2026-08-28) แต่ customer ที่ sample ของ SFDC ใช้ (`1000000001` `1000000005` `1000000013` `1000000020` `1000000021`) ยังไม่มี | FI / ผู้ดูแล tenant | Phase 1 | **บล็อก Phase 7** — ยิง sample แล้วจะติด `validateCustomerCode` | 🟨 คืบหน้า |
| OQ-05 | `payment_amount` ต้องเท่ากับผลรวม `amount_paid` ของทุก item หรือไม่ | Salesforce / FI | Phase 1 | `validatePaymentTotal` เป็นที่ว่างไว้แล้ว เพิ่ม logic ทีหลังได้ทันที | 🟨 |
| OQ-06 | URL endpoint ตัวจริง | — | Phase 1 | `05_api_spec.md` §2 ยังเป็นค่าประมาณ · ได้จริงตอน Phase 5.4 | ⬜ |
| OQ-07 | จำนวน item สูงสุดต่อ request | — | Phase 1 | กำหนดหลัง volume test Phase 7.7 | ⬜ |

| OQ-08 | released CDS view ตัวไหนบอกได้ว่า accounting document ถูกรับชำระ/reverse แล้ว (`I_OperationalAcctgDocItem` / กลุ่ม journal entry) | ผู้ใช้ + FI | Phase 3 | `validateArOpenItem` เป็นที่ว่างไว้ · ถ้าไม่มี view ที่ released จะเขียน logic ไม่ได้เลย | ⬜ |
| OQ-09 | duplicate check — **ปิดแล้ว 2026-08-28**: key = `payment_document_no` + `billing_document` เทียบทุกสถานะ · `salesforce_id` ไม่ใช่ key กันซ้ำ | — | Phase 3 | — | ✅ |
| OQ-10 | `validateAmountFormat` ควร fire ตอนไหน — OData จับค่าที่ไม่ใช่ตัวเลขไปก่อนแล้ว | Salesforce | Phase 3 | message `009` ประกาศไว้แล้ว แต่ยังไม่มี logic | 🟨 |

| OQ-11 | interface ใช้ชื่อ **`ZIF_ZARI002_MD_CHK` เป็นการชั่วคราว** — ชื่อที่ตั้งใจคือ `ZIF_ZARI002_MD_CHECK` แต่ tenant ไม่ยอมให้สร้างซ้ำเพราะเคยสร้างเป็น class ชื่อเดียวกันแล้วลบไป (น่าจะมี cache ค้าง) | ผู้ใช้ | Phase 4 | ไม่บล็อกอะไร แต่ถ้าไม่ rename กลับ ชื่อจะหลุดกฎ naming ไปถาวรและขัดกับตัวอย่างใน `CLAUDE.md` | ⬜ |

| OQ-12 | **ต้องแจ้ง SFDC ว่า API contract เปลี่ยน 2 จุด**: `NumberOfItems` → `NumberOfItemsInPayment` · response รายบรรทัดไม่มี `Status`/`ErrorMessage` แล้ว | ผู้ใช้ → Salesforce | Phase 4 | SFDC ถือ `05_api_spec.md` ฉบับเดิมไปเขียน client แล้ว ถ้าไม่แจ้งจะพังตอน integration test | ⬜ |
| OQ-13 | `ZD_STATUS` / `ZE_STATUS` — **ลบทิ้งแล้ว 2026-08-28** | — | Phase 4 | — | ✅ |
| OQ-14 | ใบที่บันทึกสำเร็จแล้ว ZARE002 post ไม่ผ่าน → SFDC ส่งเข้ามาแก้ไม่ได้ (โดน duplicate) ต้องแก้ฝั่ง SAP · **ตกลงยอมรับแล้ว** แต่ต้องเขียนไว้ใน troubleshooting guide ให้ชัด | ผู้ใช้ | Phase 4 | Phase 8.3 | 🟨 |

| OQ-15 | description ของ object status — **แก้แล้ว 2026-08-28** เป็น `Request Status` / `Response Status` (รวม field label `Req Status` / `Res Status`) · `ZIF_ZARI002_MD_CHK` ได้ prefix แล้ว | — | Phase 4 | — | ✅ |

## วิธีใช้

- เจอข้อสงสัยใหม่ระหว่างทำ → **เพิ่มแถวที่นี่ทันที** อย่าเก็บไว้ในหัวหรือใน commit message
- ตอนจบ phase → ไล่ทั้งตาราง ถามเจ้าของคำตอบ แล้วอัปเดตสถานะ
- ข้อที่เป็น `🟨` = มีทางเดินต่อแล้ว แต่ต้องกลับมาทำให้จบ ไม่ใช่ปิดไปเลย


## บันทึกการรีวิว

### จบ Phase 2 — 2026-08-27

ไล่ครบทั้ง 7 ข้อ · **ไม่มีข้อใหม่จาก Phase 2** และไม่มีข้อไหนปิดได้

- OQ-01 / OQ-05 มี message จองไว้แล้ว (`ZARI002/008` และ `ZARI002/007`) เติม logic ได้ทันทีที่ได้คำตอบ
  โดยไม่ต้องแตะ message class อีก
- OQ-03 / OQ-04 เป็นของทีม FI ทั้งคู่ และ **ยังไม่มีใครไปถาม** — OQ-04 บล็อก Phase 7 แน่นอน
  ยิ่งถามช้ายิ่งเสี่ยง เพราะการโหลด master data ไม่ใช่งานที่เสร็จในวันเดียว
- OQ-06 / OQ-07 รอ Phase 5 กับ Phase 7 ตามแผน ไม่ต้องทำอะไรตอนนี้

**เข้า Phase 3 ได้** — ไม่มีข้อไหนบล็อกการสร้าง RAP BO


### จบ Phase 3 — 2026-08-28

ไล่ครบทั้ง 10 ข้อ · **ไม่มีข้อใหม่ และไม่มีข้อไหนปิดได้**

- **ที่ว่างทั้ง 5 ตัวประกาศใน BDEF ครบแล้ว** (`validateAmountFormat` `validateChequeBankBranch`
  `validateItemDuplicate` `validatePaymentTotal` `validateArOpenItem`) → OQ-01 / 05 / 08 / 09 / 10
  เติม logic ได้ทันทีที่ได้คำตอบ **โดยไม่ต้องแตะ BDEF หรือ activate BO ใหม่**
- **OQ-03 และ OQ-04 ยังไม่มีใครไปถาม FI เลยตั้งแต่ Phase 1** — ผ่านมา 2 phase แล้ว
  OQ-04 (master data ไม่ครบ) เป็นตัวเดียวที่จะบล็อกจริงและบล็อกที่ Phase 7
- OQ-08 ไม่บล็อก Phase 4 เพราะ `validateArOpenItem` เป็นที่ว่าง — แต่ถ้าไม่มี released view
  ที่บอกสถานะ cleared/reversed จะเขียน logic ไม่ได้เลย ไม่ใช่แค่ "ยังไม่ได้เขียน"

**เข้า Phase 4 ได้** — ไม่มีข้อไหนบล็อกการเขียน determination/validation ที่เหลือ


### ทบทวนพิเศษ — table ปรับใหญ่ 2026-08-28

- **ปิด** OQ-09 (duplicate key ชัดเจนแล้ว)
- **เปิดใหม่** OQ-12 (แจ้ง SFDC) · OQ-13 (`ZD_STATUS` orphan) · OQ-14 (แก้ใบที่ post ไม่ผ่าน)
- OQ-01 `cheque_bank_branch` **ยังเปิดอยู่** — เปลี่ยนแค่ชื่อ field ไม่ได้ตอบเรื่องโครงสร้าง
- OQ-02 `payment_method` ยังเปิด · OQ-03 / OQ-04 ยังไม่มีใครถาม FI · OQ-05 / OQ-08 / OQ-10 / OQ-11 ไม่กระทบ
