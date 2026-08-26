# ZARI002 — Incoming Payments (API)

| Item | Value |
|------|-------|
| RICEFW ID | **ZARI002** |
| Description | Incoming Payments (API) |
| Type | Interface (Inbound, API) |
| Platform | SAP S/4HANA Cloud **Public Edition** |
| Development model | **ABAP Cloud** (Developer Extensibility) + RAP **managed** |
| Protocol | OData **V4** (Web API / A2X) |
| UI | ไม่มี (headless API) |
| Consumer | Salesforce (non-SAP HTTP client) |
| Operation ที่เปิด | **Create อย่างเดียว** (deep insert header + items) |
| Repo sync | abapGit (local ⇄ GitHub ⇄ S/4HANA Cloud) |
| Package | **`ZARI002`** — package เดียว ไม่มี sub-package |
| งานต่อเนื่อง | **ZARE002** — RAP UI ที่เอาข้อมูลจาก table ไป post FI จริง (คนละรหัส ทำทีหลัง) |

## Scope

3rd-party (Salesforce) ยิง `POST` แบบ **nested JSON** เข้ามา 1 request = 1 payment header + N items
ระบบ validate แล้ว **บันทึกลง 2 table** — จบตรงนี้ ไม่ post FI

```
Salesforce ──HTTPS/OData V4──▶ ZAPI_ZARI002_O4 ──▶ ZTAR_I002_PYMT
                                                   ZTAR_I002_ITEM
                                                        │
                                                   status = 'N'
                                                        │
                                                        ▼
                                            ZARE002 (RAP UI) ──▶ post FI
```

## Repository layout

```
fplus-zari002/
├── .abapgit.xml                  # abapGit config: STARTING_FOLDER=/src/, FOLDER_LOGIC=PREFIX
├── .gitignore
├── README.md
├── CLAUDE.md                     # กฎ/บริบทสำหรับ AI assistant ใน project นี้
├── docs/                         # เอกสาร design (ไม่ถูก sync เข้า SAP)
│   ├── 01_architecture.md        # สถาปัตยกรรม + design decision + เหตุผล
│   ├── 02_implementation_phases.md
│   ├── 03_object_list.md         # รายชื่อ repository object ทั้งหมด + status
│   └── 04_field_mapping.md       # API field ↔ table field + mandatory + validation
└── src/                          # ← abapGit sync เฉพาะโฟลเดอร์นี้ (package ZARI002)
    └── package.devc.xml
```

## Sync workflow

```
[Claude / local files]  ──git push──▶  [GitHub: fplus-zari002]  ──abapGit pull──▶  [S/4HANA Cloud]
       ▲                                                                                  │
       └──────────────────────── git pull ◀── abapGit push (stage & commit) ◀─────────────┘
```

**หลักการ:**

1. **ABAP object ทั้งหมด** ผู้ใช้สร้างใน ADT แล้ว abapGit push ขึ้นมาเอง —
   Claude ส่ง code ให้ทาง chat ไม่เขียนไฟล์ ABAP ลง repo (ดู `CLAUDE.md` §Git)
2. **เอกสารทั้งหมด** Claude เป็นคนดูแลและ push
3. Claude ตามอ่าน `git log` เพื่ออัปเดต status ใน `docs/03_object_list.md` ให้ตรงกับของจริงบน tenant

## Design decisions (ยืนยันแล้ว 2026-08-27)

| หัวข้อ | เลือก |
|--------|-------|
| RAP flavour | **Managed** BO บน custom table 2 ตัว (ไม่มี draft — เป็น API ไม่มี UI) |
| รูปแบบ OData | **Deep insert** — `POST /Payment` พร้อม `_Item[]` nested ในชุดเดียว |
| Operation | **Create อย่างเดียว** — ไม่เปิด read/update/delete |
| Error handling | **Reject ทั้ง request** → HTTP 400 + message list · ไม่บันทึกอะไรลง table เลย |
| Validation | format + mandatory + **master data จริง** (company code, GL account, currency, payment method, customer) |
| Idempotency | `salesforce_id` **unique** — RAP validation + unique secondary index กัน race |
| Item business key | `salesforce_item_id` |
| Status ที่ ZARI002 เขียน | `N` (New) เท่านั้น |
| Transaction | 1 request = 1 LUW — item ใบเดียวพัง rollback ทั้ง payment |

## Data model

2 table ที่ผู้ใช้ออกแบบไว้แล้ว (ปรับ 3 จุดเมื่อ 2026-08-27 — ดู `docs/01_architecture.md` §3)

| Table | บทบาท | Key |
|-------|-------|-----|
| `ZTAR_I002_PYMT` | Payment header | `client` + `payment_uuid` |
| `ZTAR_I002_ITEM` | Payment item | `client` + `item_uuid` (parent = `payment_uuid`) |

Domain / data element ที่ใช้ร่วมข้าม RICEFW: `ZD_STATUS` (`N`/`S`/`W`/`E`) + `ZE_STATUS`

## Status

Phase 0 — repository skeleton ✅ · รอผู้ใช้ push table + domain/data element ตัวจริงขึ้นมา แล้วเข้า Phase 1
