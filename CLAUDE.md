# ZARI002 — Incoming Payments (API)

## Project constraints (ยึดถือตลอด project)

1. **Platform**: SAP S/4HANA Cloud **Public Edition** — Developer Extensibility (tier 3-cloud-only)
2. **ABAP Language Version**: **ABAP for Cloud Development** เท่านั้น ไม่มี fallback เป็น Standard ABAP
3. ใช้ได้เฉพาะ object ที่อยู่ใน **Released APIs (C1 contract)** เท่านั้น — ตรวจสอบทุกครั้งก่อนใช้
   ผ่าน ADT "Released Objects" หรือ view `I_APIStateForCLOUDDevelopment`
4. **ห้าม** ใช้ classic ABAP: `CALL FUNCTION` BAPI แบบตรง, `SELECT` จาก table SAP โดยตรง,
   `WRITE`, dynpro, SAPGUI report — ใช้ released CDS view + released ABAP API + EML แทน
5. Sync ผ่าน **abapGit** เท่านั้น
6. ทุก object ลง package **`ZARI002`** ตัวเดียว (ไม่มี sub-package)

## Naming convention

ใช้กฎกลางใน `~/.claude/CLAUDE.md` ทุกข้อ **แต่เปลี่ยน prefix จาก `Y*` เป็น `Z*` ทั้งหมด**
โดย `<APP>` ของ project นี้ = **`ZARI002`** (RICEFW ID เต็ม รวมตัว `Z` นำหน้า)

| ชนิด | Pattern | ตัวอย่างจริงใน project |
|------|---------|------------------------|
| Package | `Z<APP>` | `ZARI002` |
| HTTP handler | `ZCL_<APP>_HTTP` | `ZCL_ZARI002_HTTP` |
| Global class | `ZCL_<APP>_<PURPOSE>` | `ZCL_ZARI002_VALIDATOR` |
| Global interface | `ZIF_<APP>_<PURPOSE>` | `ZIF_ZARI002_MD_CHK` |
| Exception class | `ZCX_<APP>_<...>` | `ZCX_ZARI002_ERROR` |
| Message class | `Z<APP>` | `ZARI002` |

### ข้อยกเว้นที่ตกลงไว้ (2026-08-27)

- **Database table** ใช้ชื่อที่ผู้ใช้ออกแบบไว้แล้ว ไม่เปลี่ยน: `ZTAR_I002_PYMT`, `ZTAR_I002_ITEM`
- **Domain / Data element ที่ตั้งใจให้ reuse ข้าม RICEFW** ไม่ใส่ RICEFW ID ในชื่อ:
  `ZD_STATUS`, `ZE_STATUS` — RICEFW อื่นเอาไปใช้ต่อได้โดยไม่ติดชื่อ RICEFW ต้นทาง

### Variable / parameter prefix

ตามกฎกลางเดิมทุกข้อ — `gv_/lv_/gs_/ls_/gt_/lt_/go_/lo_/<fs_>/<lfs_>` และ
`iv_/is_/it_/io_`, `ev_/es_/et_/eo_`, `cv_/cs_/ct_`, `rv_/rs_/rt_/ro_`

### ชื่อภายใน BDEF

- CDS element alias = **CamelCase** · field ใน DDIC table = snake_case — ห้ามปน
- Determination: `set*` / `calculate*` · Validation: `validate*` · Association: `_<Entity>`

## Coding rules

- ทุก class ต้องมี ABAP Unit test (`*.clas.testclasses.abap`) — logic class ต้อง test ได้โดยไม่ต้องต่อ SAP จริง
  (แยกการอ่าน master data ออกเป็น `ZIF_ZARI002_MD_CHK` + test double)
- ทุก method มี ABAP Doc comment สั้น ๆ อธิบาย purpose
- Error ทั้งหมดรวมศูนย์ที่ message class `ZARI002` + exception `ZCX_ZARI002_ERROR`
- **ไม่มี RAP ใน project นี้แล้ว (2026-08-31)** — ใช้ `INSERT` + `COMMIT WORK` ตรง ๆ
  กฎ RAP ทั้งหมดข้างล่างเก็บไว้เป็นบันทึก เผื่อ RICEFW อื่นที่ใช้ RAP
- **Comment ใน BDEF (`.asbdef`) ใช้ `//` ไม่ใช่ `"`** — `"` เป็นของ ABAP ใช้ใน `.asbdef` ไม่ได้
- **RAP derived type (`TYPE STRUCTURE FOR READ RESULT ...`) ใช้ตรง ๆ ใน method signature ไม่ได้**
  parser จะกิน token ถัดไป (`RETURNING`, `EXPORTING`) เข้ามาเป็นส่วนหนึ่งของ type
  → ประกาศเป็น `TYPES:` alias ก่อนเสมอ แล้วค่อยอ้าง alias ใน signature
- **RAP unit test ต้อง `ROLLBACK ENTITIES` ใน `setup`** — `COMMIT ENTITIES` ที่ fail
  **ไม่ทิ้งข้อมูลใน transactional buffer** ของค้างจะถูก save ไปพร้อม test ถัดไป
  ทำให้ได้ error ของ test ก่อนหน้าโดยหาสาเหตุไม่เจอ
- **`FAILED` / `REPORTED` ต้องระบุ `LATE` ใน handler ของ save phase**
  `FOR VALIDATE ON SAVE` และ `FOR DETERMINE ON SAVE` ได้ `failed`/`reported` แบบ **LATE**
  (ไม่มี `%cid` เพราะทุก instance มี key แล้ว) ส่วน `EARLY` เป็นของ interaction phase
  ถ้าประกาศ type ไม่ตรงจะได้ `The type "TABLE OF <flat>" ... is unsuitable for ... "TABLE OF <deep>"`
- **`total etag` ประกาศได้เฉพาะ BO ที่มี draft** — BO แบบ API ไม่มี draft ให้ใช้ `lock master`
  เปล่า ๆ + `etag master <LocalLastChangedAt>` เท่านั้น
- **BDEF managed ที่ CDS ใช้ CamelCase ต้องมี `mapping for <table> { ... }` ทุก entity**
  ไม่งั้นติด warning `does not have a mapping to table` ทุก field ซึ่ง **transport ไม่ผ่าน**
  (เจอ 2026-09-16 ที่ log monitor · ZSDE002 ยังไม่มี ต้องกลับไปเติม)
- **`strict ( 2 )` บังคับ `authorization master/dependent` ทุก entity** — read-only BO ก็ต้องมี
  behavior pool ที่ `get_global_authorizations` ว่าง ตัดไม่ได้
- **key UUID ต้อง `field ( numbering : managed, readonly )`** แม้ BO ไม่มี `create`
- **Outbound ไป Salesforce ใช้ `ZCL_UTILITY=>create_sfdc_client( )` จาก package `ZBCUTILITY`**
  ห้ามตั้ง Communication Arrangement แบบ OAuth ให้ platform จัดการ token เอง
  เหตุผล: Salesforce client credentials ไม่ส่ง `expires_in` platform จึงถือ token ค้างไม่ขอใหม่
  แม้เจอ 401 · อาการคือวันแรกผ่าน วันถัดมาได้ 401 `INVALID_SESSION_ID` โดยไม่ได้แก้อะไร
  (เจอจริงที่ ZARE002 2026-09-21 · ZARI002 ย้ายตาม 2026-09-23)
- **ห้าม ping `/services/data/` เพื่อเช็ค auth** — endpoint นั้นไม่ต้องใช้ token ตอบ 200 เสมอ
  ใช้ `ZCL_UTILITY=>check_sfdc_connection( )` ซึ่งยิง `/services/data/v66.0/limits` แทน
- **Path ใน Communication Arrangement เป็น prefix** `set_uri_path( )` ต่อท้ายไม่ได้แทนที่
  ตั้ง prefix เป็น `/` เสมอ แล้วให้ class ใส่ path เต็มเอง ไม่งั้นได้ 404
- secret อยู่ใน Communication System เท่านั้น ABAP มองไม่เห็น ไม่ต้องมี table เก็บ
  และห้าม print หรือ log ตัว access token
- **แก้ scenario ที่ publish แล้ว (แม้แค่ description) → กลายเป็น unpublished** ต้อง Publish
  Locally ใหม่ ไม่งั้น arrangement ที่ใช้อยู่อาจล่ม (เกือบโดนที่ `ZCS_INCOMING_PYMT` 2026-09-17)

## Git — การแบ่งงาน

| สิ่งที่ทำ | ใคร commit/push |
|---|---|
| **ABAP object ทุกชนิด** (class, interface, CDS, bdef, DDIC, service def/binding) | **ผู้ใช้** |
| **เอกสาร** (`docs/`, `README.md`, `CLAUDE.md`) | **Claude** |

- Claude **ห้ามสร้างไฟล์ ABAP ลง repo** (`src/**/*.abap`, `*.ddls.asddls`, `*.asbdef` ฯลฯ)
  → ส่งเป็น **code block ใน chat** ให้ผู้ใช้ copy ไปสร้างใน ADT แล้ว push ผ่าน abapGit เอง
  เหตุผล: source of truth ของ ABAP object คือ tenant และ abapGit reformat code เอง
  ถ้าเขียนลง repo ทั้งสองฝั่งจะชนกัน
- `.abapgit.xml` และ `package.devc.xml` เป็นของที่ **SAP serialize เอง** — ห้าม Claude เขียนหรือแก้มือ
- Claude คอยเช็ค `git log` / `git status` ว่าผู้ใช้ push object อะไรขึ้นมาแล้วบ้าง
  แล้วอัปเดต status ใน `docs/03_object_list.md` ให้ตรง
- Push เอกสารขึ้น GitHub ได้เลยเมื่อผู้ใช้สั่ง ไม่ต้อง confirm ซ้ำ
- Remote: https://github.com/Thianthai/fplus-zari002.git

## ADT ขึ้น HTTP 500 — ลองใหม่ก่อนไล่หาสาเหตุ

เจอมาแล้ว 2 ครั้งบน tenant นี้ ทั้งคู่หายเองโดยไม่ได้แก้อะไร:

| เมื่อไหร่ | อาการ | ทางออก |
|---|---|---|
| Link abapGit repo (2026-08-27) | `POST /sap/bc/adt/abapgit/repos failed: 500` | กด ignore แล้ว link ติด · ครั้งถัดมา link ใหม่ผ่านฉลุย |
| Publish HTTP service (2026-08-31) | `POST /sap/bc/adt/ucon/httpservices/.../publish failed: 500` (`SHTTP/092`) | ลองใหม่เฉย ๆ แล้วผ่าน |

**ลองซ้ำ 1–2 ครั้งก่อนเสมอ** — ถ้ายังไม่ผ่านค่อยไปดู short dump ที่ ADT → Feed Reader →
ABAP Runtime Errors ซึ่งบอกสาเหตุจริง (ข้อความที่ ADT เด้งมาเป็นแค่เปลือก)

## วิธีทำงานเมื่อข้อมูลยังไม่ครบ (ตกลง 2026-08-27)

master data บน tenant ยัง config ไม่เสร็จ และ sample data บางส่วนยังไม่มีจริงในระบบ
→ **ABAP implement รอไว้ก่อน ไม่ต้องหยุดรอ**

- เจอจุดที่ไม่ชัด → **note ลง `docs/06_open_questions.md` แล้วเดินต่อทันที**
- validation ที่ยังตัดสินใจไม่ได้ → เปิดเป็น **ที่ว่าง (empty hook)** ไว้ใน BDEF พร้อม comment
  ว่ารออะไร จะได้เติม logic ทีหลังโดยไม่ต้องแก้ BDEF
- **จบทุก phase ต้องไล่รีวิวทะเบียนข้อสงสัยทั้งตาราง** ก่อนขึ้น phase ถัดไป

## Related RICEFW

ทั้ง 3 รหัสคุยกันผ่าน `ZTAR_I002_PYMT` / `ZTAR_I002_ITEM` เท่านั้น ไม่มี call ตรงระหว่างกัน

| RICEFW | หน้าที่ | เขียน `status` | outbound ไป SFDC |
|---|---|---|---|
| **ZARI002** (งานนี้) | **SBPA** ยิงเข้ามา — validate แล้วลง table | `N` | ✅ **แจ้งผลการรับข้อมูล** (S/E ต่อใบ) ผ่าน `ZCL_ZARI002_SFDC_RESULT` |
| **ZARE002** | RAP UI — อ่าน row `N` ไป post FI จริง | `S` / `W` / `E` + `error_message` | — |
| **ZARI003** | อ่านผล post จาก table แจ้งกลับ Salesforce | — (อ่านอย่างเดียว) | ✅ **แจ้งผลการ post** |

**2 outbound เป็นคนละเรื่อง** — ZARI002 บอกว่า "รับใบนี้ไหม" · ZARI003 บอกว่า "post ใบนี้ผ่านไหม"
(แก้ให้ถูก 2026-09-17 — ระหว่าง 2–17 ก.ย. เคยเข้าใจว่า outbound ทั้งหมดเป็นของ ARI003
class จึงเคยชื่อ `ZCL_ZARI003_SFDC_NOTIFY`)

### เส้นทางข้อมูลจริง

```
SFDC ──(Excel)──▶ SBPA ──(HTTP POST)──▶ ZARI002 ──▶ table ──▶ ZARE002 post ──▶ ZARI003 ──▶ SFDC
                   ▲                        │                                    (ผล post)
                   └────(response)──────────┤
                                            └──── ZARI002 notify ──▶ SFDC (ผลรับ S/E)
```

**ผู้เรียก ZARI002 คือ SBPA ไม่ใช่ SFDC** — SFDC ส่ง Excel ให้ SBPA แล้ว SBPA อ่านไฟล์
ยิงเข้ามา · response ของเราจบที่ SBPA **SFDC ไม่เคยเห็น** จึงต้องมี ARI003 แจ้งผลกลับแยก

ZARI002 จึงเป็น **create อย่างเดียว ไม่ต้องเปิด read** — ยกเว้น **log monitor** (Phase 5A)
ที่เป็น RAP read-only บนชุดตาราง log แยกต่างหาก ไม่แตะตารางธุรกิจ

### ทำไม ZARI002 ต้องยิงผลรับกลับเอง

payment ที่ถูก reject **ไม่มี row ในตารางธุรกิจ** — ZARI003 ที่อ่านจาก table จึงบอก SFDC ไม่ได้ว่า
ใบไหนตก · ZARI002 ต้องแจ้งเองตอนที่ข้อมูลยังอยู่ในมือ ผ่าน `ZCL_ZARI002_SFDC_RESULT` ท้าย loop
ของแต่ละ payment (ตั้งแต่ Phase 5A มี log table แล้วแต่ยังยิง inline เหมือนเดิม)

**Outbound ใช้ `ZCL_UTILITY` จาก package กลาง `ZBCUTILITY`** — ขอ token ใหม่ทุก call ผ่าน
`ZCA_SFDC_TOKEN` แบบ Basic (Communication System `SFDC_DEV` ที่แชร์ข้าม RICEFW) · secret อยู่ใน Fiori ไม่มีใน code/git
· `check_connection( )` ใช้พิสูจน์ว่าต่อถึงและ token ใช้ได้