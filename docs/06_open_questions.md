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

## วิธีใช้

- เจอข้อสงสัยใหม่ระหว่างทำ → **เพิ่มแถวที่นี่ทันที** อย่าเก็บไว้ในหัวหรือใน commit message
- ตอนจบ phase → ไล่ทั้งตาราง ถามเจ้าของคำตอบ แล้วอัปเดตสถานะ
- ข้อที่เป็น `🟨` = มีทางเดินต่อแล้ว แต่ต้องกลับมาทำให้จบ ไม่ใช่ปิดไปเลย
