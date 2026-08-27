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
| งานต่อเนื่อง | **ZARE002** (RAP UI → post FI) · **ZARI003** (ส่งผลกลับ Salesforce) — คนละรหัส ทำทีหลัง |

## Scope

3rd-party (Salesforce) ยิง `POST` แบบ **nested JSON** เข้ามา 1 request = 1 payment header + N items
ระบบ validate แล้ว **บันทึกลง 2 table** — จบตรงนี้ ไม่ post FI

```
             ┌──HTTPS/OData V4──▶ ZAPI_ZARI002_O4 ──▶ ZTAR_I002_PYMT   status = 'N'
             │                    (งานนี้)              ZTAR_I002_ITEM        │
Salesforce ──┤                                                ▲               ▼
             │                                                │      ZARE002 (RAP UI)
             └◀── ZARI003 ──────────────────────────────────── ┘         post FI
                  ส่งผล post กลับ                        stamp S / W / E
```

## Repository layout

```
fplus-zari002/
├── .gitignore
├── README.md
├── CLAUDE.md                     # กฎ/บริบทสำหรับ AI assistant ใน project นี้
├── docs/                         # เอกสาร design (ไม่ถูก sync เข้า SAP)
│   ├── 01_architecture.md        # สถาปัตยกรรม + design decision + เหตุผล
│   ├── 02_implementation_phases.md
│   ├── 03_object_list.md         # รายชื่อ repository object ทั้งหมด + status
│   ├── 04_field_mapping.md       # API field ↔ table field + mandatory + validation
│   ├── 05_api_spec.md            # contract สำหรับทีม Salesforce
│   └── 06_open_questions.md      # ทะเบียนข้อสงสัย — รีวิวทุกครั้งที่จบ phase
├── .abapgit.xml                  # ← tenant serialize เอง ห้ามแก้มือ
└── src/                          # ← abapGit sync เฉพาะโฟลเดอร์นี้ (package ZARI002)
    ├── package.devc.xml
    ├── zd_status.doma.xml
    ├── ze_status.dtel.xml
    ├── ztar_i002_pymt.tabl.xml
    └── ztar_i002_item.tabl.xml
```

`.abapgit.xml` และ `src/` ทั้งหมด **tenant เป็นคน serialize** ไม่ได้เขียนมือ —
`STARTING_FOLDER = /src/` · `FOLDER_LOGIC = FULL` · object ของ package `ZARI002`
ลง `src/` ตรง ๆ เพราะไม่มี sub-package

## Sync workflow

```
[Claude / local files]  ──git push──▶  [GitHub: fplus-zari002]  ──abapGit pull──▶  [S/4HANA Cloud]
       ▲                                                                                  │
       └──────────────────────── git pull ◀── abapGit push (stage & commit) ◀─────────────┘
```

**หลักการ:**

1. **Object ที่สร้างใหม่ครั้งแรก** ให้สร้างใน ADT ก่อน แล้ว abapGit push กลับมา
   เพื่อให้ได้ metadata XML ที่ SAP serialize เองเป็น baseline — รวมถึง `.abapgit.xml`
   และ `package.devc.xml` ที่ห้ามเขียนมือ (Public Cloud ต้องผูก software component
   และ package type ให้ถูก)
2. **ABAP object ทั้งหมด** ผู้ใช้สร้างใน ADT แล้ว abapGit push ขึ้นมาเอง —
   Claude ส่ง code ให้ทาง chat ไม่เขียนไฟล์ ABAP ลง repo (ดู `CLAUDE.md` §Git)
3. **เอกสารทั้งหมด** Claude เป็นคนดูแลและ push
4. Claude ตามอ่าน `git log` เพื่ออัปเดต status ใน `docs/03_object_list.md` ให้ตรงกับของจริงบน tenant

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

**Phase 0 ✅ ปิดแล้ว** — repo, abapGit link, และ baseline (2 table + domain + data element) ตรวจแล้วถูกต้องครบ
กำลังอยู่ **Phase 1** — spec freeze + verify release state ของ released CDS view ที่จะใช้ validate master data
