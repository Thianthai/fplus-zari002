# ZARI002 — ทะเบียนข้อสงสัย

รวมทุกอย่างที่ยัง**ไม่เคลียร์** ไว้ที่เดียว — **รีวิวทุกครั้งที่จบ phase** (ตกลง 2026-08-27)

> **บริบท**: master data บน tenant ยัง config ไม่เสร็จ · ABAP implement รอไว้ก่อนเพื่อไม่ให้เสียเวลา
> เจอจุดไหนไม่ชัดให้ **note ไว้ที่นี่แล้วเดินต่อ** อย่าหยุดรอ

สถานะ: `⬜` เปิดอยู่ · `🟨` มีคำตอบชั่วคราวแล้ว เดินต่อได้ · `✅` ปิด

| # | เรื่อง | เจ้าของคำตอบ | ยกมาจาก | บล็อกอะไร | สถานะ |
|---|--------|-------------|---------|-----------|--------|
| OQ-01 | โครงสร้างจริงของ `cheque_bankbranch` — ตัวอย่าง `0040129` ไม่มีใน `I_Bank_2` แต่ `004` มี · น่าจะเป็น bank 3 หลัก + branch 4 หลัก | Salesforce / FI | Phase 1 | `validateChequeBankBranch` เป็นที่ว่างไว้ · field คง `char(15)` ไว้ก่อน | 🟨 |
| OQ-02 | รายการคำ `payment_method` ทั้งชุดที่ Salesforce จะส่ง (ตอนนี้รู้แค่ `Cheque` / `Transfer`) | Salesforce | Phase 1 | mapping constant ไม่ครบ → คำที่ไม่รู้จักจะถูก reject | 🟨 |
| OQ-03 | `IsPaymentMethodForIncomingPayments` ติ๊กแค่ `M` `N` `E` ไม่รวม `A` / `T` ที่ใช้จริง | FI | Phase 1 | ZARI002 ไม่เช็ค flag นี้ แต่ **ZARE002 จะ post ไม่ผ่านถ้า config ถูกต้องจริง** | ⬜ |
| OQ-04 | master data บน tenant ยังไม่ครบ — `I_Customer` มี 3 ราย, GL account / company code บางตัวใน sample อาจยังไม่มี | FI / ผู้ดูแล tenant | Phase 1 | **บล็อก Phase 7** — ยิง sample แล้วจะติด validation แทบทุกใบ | ⬜ |
| OQ-05 | `payment_amount` ต้องเท่ากับผลรวม `amount_paid` ของทุก item หรือไม่ | Salesforce / FI | Phase 1 | `validatePaymentTotal` เป็นที่ว่างไว้แล้ว เพิ่ม logic ทีหลังได้ทันที | 🟨 |
| OQ-06 | URL endpoint ตัวจริง | — | Phase 1 | `05_api_spec.md` §2 ยังเป็นค่าประมาณ · ได้จริงตอน Phase 5.4 | ⬜ |
| OQ-07 | จำนวน item สูงสุดต่อ request | — | Phase 1 | กำหนดหลัง volume test Phase 7.7 | ⬜ |

| OQ-08 | released CDS view ตัวไหนบอกได้ว่า accounting document ถูกรับชำระ/reverse แล้ว (`I_OperationalAcctgDocItem` / กลุ่ม journal entry) | ผู้ใช้ + FI | Phase 3 | `validateArOpenItem` เป็นที่ว่างไว้ · ถ้าไม่มี view ที่ released จะเขียน logic ไม่ได้เลย | ⬜ |
| OQ-09 | key ของ duplicate check ที่ให้มามี 4 field แต่ `salesforce_id` unique อยู่แล้ว การ AND ทั้ง 4 จึงไม่มีวัน fire · และ `billing_note_no` เป็น optional จึงเป็น key ที่เชื่อถือไม่ได้ → **ตอนนี้ทำเป็นเช็ค `salesforce_item_id` ข้าม payment** | Salesforce | Phase 3 | `validateItemDuplicate` ทำงานตามที่ตีความไว้ ถ้าตีความผิดต้องแก้ | 🟨 |
| OQ-10 | `validateAmountFormat` ควร fire ตอนไหน — OData จับค่าที่ไม่ใช่ตัวเลขไปก่อนแล้ว | Salesforce | Phase 3 | message `009` ประกาศไว้แล้ว แต่ยังไม่มี logic | 🟨 |

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
