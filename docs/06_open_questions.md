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

| OQ-11 | ชื่อชั่วคราวของ interface — **ปิดแล้ว 2026-08-28** rename เป็น `ZIF_ZARI002_MASTER_DATA` คู่กับ `ZCL_ZARI002_MASTER_DATA` (`MD_` อ่านเป็น manday) | — | Phase 4 | — | ✅ |

| OQ-12 | แจ้ง SFDC เรื่อง contract เปลี่ยน — **ปิดแล้ว 2026-08-28**: SFDC ยังไม่เริ่ม implement · ส่วนเรื่อง response รายบรรทัดกลายเป็นคนละเรื่อง เพราะย้ายไปตอบผ่าน callback API ของ SFDC แทน (ดู OQ-17) | — | Phase 4 | — | ✅ |
| OQ-13 | `ZD_STATUS` / `ZE_STATUS` — **ลบทิ้งแล้ว 2026-08-28** | — | Phase 4 | — | ✅ |
| OQ-14 | ใบที่บันทึกสำเร็จแล้ว ZARE002 post ไม่ผ่าน → SFDC ส่งเข้ามาแก้ไม่ได้ (โดน duplicate) ต้องแก้ฝั่ง SAP · **ตกลงยอมรับแล้ว** แต่ต้องเขียนไว้ใน troubleshooting guide ให้ชัด | ผู้ใช้ | Phase 4 | Phase 8.3 | 🟨 |

| OQ-15 | description ของ object status — **แก้แล้ว 2026-08-28** เป็น `Request Status` / `Response Status` (รวม field label `Req Status` / `Res Status`) · `ZIF_ZARI002_MD_CHK` ได้ prefix แล้ว | — | Phase 4 | — | ✅ |

| OQ-16 | payload เดียวที่มี 2 item ใช้ `billing_document` ตัวเดียวกัน — `validateItemDuplicate` ปล่อยผ่าน เพราะตอน validate ยังไม่มีอะไรใน table ให้ชน · **ต้องรู้ก่อนว่าธุรกิจมีเคสที่ 1 ใบแจ้งหนี้ถูกแบ่งจ่าย 2 บรรทัดในใบเดียวกันไหม** ถ้ามีจริงการกันไว้จะไปบล็อกของที่ถูกต้อง | Salesforce / business | Phase 4 | ไม่บล็อกอะไร — เป็น defensive check ไม่ใช่ requirement · ถ้าจะเพิ่มก็แค่เช็คภายใน `lt_item` ก่อนยิง SELECT | ⬜ |

| OQ-17 | callback ไป SFDC — endpoint, auth, รูปแบบ JSON ตัวจริง ยังไม่มี (SFDC ยังไม่ได้ทำ API) | Salesforce | Phase 3 | `ZCL_ZARI002_SFDC_NOTIFY` เขียนได้แต่ยิงจริงไม่ได้จนกว่าจะมีปลายทาง | ⬜ |
| OQ-18 | response ของ API เราเองควรมีอะไร ในเมื่อผลจริงส่งผ่าน callback แล้ว | Salesforce | Phase 4 | `05_api_spec.md` §8 ยังเปิดไว้ | ⬜ |

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


### จบ Phase 4 — 2026-08-28

16 ข้อ · **ปิดไป 4** (OQ-09 duplicate key · OQ-11 ชื่อ interface · OQ-13 domain กำพร้า · OQ-15 description)
· เปิดใหม่ 5 ระหว่าง phase (OQ-12 ถึง OQ-16)

**ไม่มีข้อไหนบล็อก Phase 5** แต่มี 2 ข้อที่เปลี่ยนระดับความเร่งด่วน:

- **OQ-12 กลายเป็นเร่งด่วน** — Phase 5 publish service · Phase 6 เปิดให้ SFDC ยิงเข้ามา
  ถ้ายังไม่แจ้งว่า `NumberOfItems` → `NumberOfItemsInPayment` และ response รายบรรทัดไม่มี
  `Status`/`ErrorMessage` แล้ว **integration test จะพังทันทีที่เริ่ม** และจะดูเหมือนบั๊กฝั่งเรา
- **OQ-06 จะถูกตอบโดย Phase 5.4 เอง** — ไม่ต้องทำอะไร แค่จำไว้ว่าต้องเอา URL จริงไปเติม
  `05_api_spec.md` §2

**2 ข้อที่ค้างมา 3 phase แล้วโดยยังไม่มีใครไปถาม FI**: OQ-03 และ OQ-04
OQ-04 บล็อก Phase 7 ซึ่งห่างจากตอนนี้แค่ 2 phase และการโหลด master data ไม่ใช่งานวันเดียว

**ที่ว่างใน BDEF 4 ตัวยังรอคำตอบตามเดิม** — OQ-01 `validateChequeBankBranch` ·
OQ-05 `validatePaymentTotal` · OQ-08 `validateArOpenItem` · OQ-10 `validateAmountFormat`
ทุกตัวประกาศไว้แล้ว เติม logic ได้โดยไม่ต้องแตะ BDEF


### เปลี่ยนสถาปัตยกรรม — 2026-08-31

ถอด RAP ออกทั้งหมด เปลี่ยนเป็น HTTP Service · **ไม่มีข้อสงสัยข้อไหนถูกยกเลิก**
เพราะทุกข้อเป็นเรื่อง business rule กับ master data ไม่ได้ผูกกับ transport

- OQ-06 (URL endpoint) ยังเปิดอยู่ แต่ตอนนี้จะได้คำตอบจาก **Phase 4.2** แทน Phase 5.4
- เปิดใหม่ OQ-17 (ปลายทาง callback) · OQ-18 (response ของ API เรา)
- OQ-12 ที่ปิดไปแล้วยิ่งชัดว่าปิดถูก — response รายบรรทัดที่เคยกังวลถูกแทนด้วย callback
